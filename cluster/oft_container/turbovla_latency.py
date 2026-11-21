"""
turbovla_latency.py

Inference latency of TurboVLA fine-tuned on LIBERO-Plus on
an A30, measured like OpenVLA-OFT's experiments/robot/bench_latency.py so the two can share one speed/quality plot.

Batch 1, OFT's fixed LIBERO observation (experiments/robot/libero/sample_libero_spatial_observation.pkl: its 224 px
images resized to TurboVLA's 256 px eval input, its 8-D state, its instruction), N warm-up then M timed queries.
Settings as in the eval kit's adapters/turbovla.py (the LIBERO-Plus evaluation): bf16, images rotated 180 degrees,
chunks executed open loop for 12 steps.

Reports median / p95 / mean (ms) for
  - end_to_end:  the adapter's predict() (rotate, preprocess, model, un-normalize; returns numpy, so synchronized)
  - preprocess:  image normalization + state normalization + host-to-device copy (synchronized wall time)
  - model:       model forward only (CUDA events)
and per executed action (end_to_end / executed steps), the chunk shape, parameter count, peak GPU memory and versions.
With --oft_bench <bench.json>, also OFT's per-executed-action time (its end_to_end / 8, OFT's open-loop chunk on LIBERO).

Run inside the LIBERO-Plus container (lp-exec.sh puts TurboVLA on PYTHONPATH):
    lp-exec.sh python -u turbovla_latency.py --ckpt <turbovla_step_N.pth> --out bench.json
"""

import argparse
import json
import os
import pickle
import platform
import time

import numpy as np
import torch
from PIL import Image

OFT_OPEN_LOOP_STEPS = 8  # OpenVLA-OFT on LIBERO: 8-step chunks, all executed (run_libero_eval.py num_open_loop_steps)


def stats(xs_ms):
    a = np.asarray(xs_ms, dtype=np.float64)
    return {"median_ms": float(np.median(a)), "p95_ms": float(np.percentile(a, 95)), "mean_ms": float(a.mean()), "n": len(a)}


def main():
    root = os.environ.get("TURBOVLA_ROOT", os.path.expanduser("~/turing-vla/TurboVLA"))
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", required=True)
    ap.add_argument("--obs_pkl", default=os.path.expanduser(
        "~/turing-vla/openvla-oft/experiments/robot/libero/sample_libero_spatial_observation.pkl"))
    ap.add_argument("--image_size", type=int, default=256)
    ap.add_argument("--execute_steps", type=int, default=12)
    ap.add_argument("--warmup", type=int, default=50)
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--oft_bench", default="")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    from turbovla.evaluation.suite_policy import TurboVLAPolicy, rotate_libero_image

    policy = TurboVLAPolicy(  # as adapters/turbovla.py
        ckpt_path=args.ckpt,
        dinov3_path=os.path.join(root, "pretrained/dinov3-vitb16-pretrain-lvd1689m"),
        bert_path=os.path.join(root, "pretrained/bert-base-uncased"),
        stats_path=os.path.join(root, "experiments/libero/configs/libero_all4_stats.json"),
        stats_key="libero_all4_no_noops",
        precision="bf16",
    )
    dev = policy.device
    assert dev.type == "cuda", "needs a GPU"

    obs = pickle.load(open(args.obs_pkl, "rb"))
    size = (args.image_size, args.image_size)
    primary = np.asarray(Image.fromarray(obs["full_image"]).resize(size, Image.BILINEAR))
    wrist = np.asarray(Image.fromarray(obs["wrist_image"]).resize(size, Image.BILINEAR))
    state = np.asarray(obs["state"], dtype=np.float32)
    instruction = obs["task_description"]

    def predict():  # = TurboVLAAdapter.predict
        p, w = rotate_libero_image(primary), rotate_libero_image(wrist)
        return np.asarray(policy.predict_env_action_chunk(p, w, instruction, state, execute_steps=args.execute_steps))

    torch.cuda.reset_peak_memory_stats()
    for _ in range(args.warmup):
        chunk = predict()
    e2e = []
    for _ in range(args.iters):
        t0 = time.perf_counter()
        chunk = predict()
        e2e.append((time.perf_counter() - t0) * 1000.0)

    pre, model = [], []
    p, w = rotate_libero_image(primary), rotate_libero_image(wrist)
    for i in range(args.warmup + args.iters):
        torch.cuda.synchronize()
        t0 = time.perf_counter()
        samples, states = policy._build_batch([p], [w], [state])
        samples, states = policy._prepare_model_inputs(samples, states)
        torch.cuda.synchronize()
        t1 = time.perf_counter()
        start, end = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
        with torch.inference_mode():
            start.record()
            pred = policy.model([instruction], samples, states)
            end.record()
        torch.cuda.synchronize()
        if i >= args.warmup:
            pre.append((t1 - t0) * 1000.0)
            model.append(start.elapsed_time(end))

    e2e_s = stats(e2e)
    result = {
        "model": "TurboVLA (fine-tuned on LIBERO-Plus)",
        "checkpoint": args.ckpt,
        "precision": "bf16",
        "warmup": args.warmup, "iters": args.iters, "batch": 1,
        "input": {"obs_pkl": args.obs_pkl, "image_size": args.image_size, "instruction": instruction},
        "end_to_end": e2e_s,
        "preprocess": stats(pre),
        "model_forward": stats(model),
        "predicted_chunk_shape": list(pred.shape[1:]) if pred.dim() == 3 else list(pred.shape),
        "executed_chunk_shape": list(chunk.shape),
        "executed_steps_per_query": args.execute_steps,
        "per_executed_action_ms": e2e_s["median_ms"] / args.execute_steps,
        "parameters_m": sum(t.numel() for t in policy.model.parameters()) / 1e6,
        "peak_gpu_mem_gb": torch.cuda.max_memory_allocated() / 2**30,
        "gpu": torch.cuda.get_device_name(0), "torch": torch.__version__, "cuda": torch.version.cuda,
        "python": platform.python_version(),
    }
    if args.oft_bench:
        oft = json.load(open(args.oft_bench))
        oft_ms = oft["end_to_end"]["median_ms"]
        result["oft_reference"] = {
            "bench": args.oft_bench, "end_to_end_median_ms": oft_ms, "executed_steps_per_query": OFT_OPEN_LOOP_STEPS,
            "per_executed_action_ms": oft_ms / OFT_OPEN_LOOP_STEPS, "gpu": oft.get("gpu"),
            "speedup_per_executed_action": (oft_ms / OFT_OPEN_LOOP_STEPS) / result["per_executed_action_ms"],
        }
    json.dump(result, open(args.out, "w"), indent=1)
    print(f"[tl] end-to-end {e2e_s['median_ms']:.2f} ms (p95 {e2e_s['p95_ms']:.2f}), preprocess "
          f"{result['preprocess']['median_ms']:.2f}, model {result['model_forward']['median_ms']:.2f} ms; chunk "
          f"{result['predicted_chunk_shape']} executed {args.execute_steps} -> {result['per_executed_action_ms']:.2f} ms "
          f"per executed action; {result['parameters_m']:.0f} M params, peak {result['peak_gpu_mem_gb']:.2f} GB, "
          f"{result['gpu']}", flush=True)
    if args.oft_bench:
        r = result["oft_reference"]
        print(f"[tl] OFT reference: {r['end_to_end_median_ms']:.1f} ms per 8-step chunk = "
              f"{r['per_executed_action_ms']:.2f} ms per executed action; TurboVLA "
              f"{r['speedup_per_executed_action']:.1f}x faster per executed action", flush=True)


if __name__ == "__main__":
    main()
