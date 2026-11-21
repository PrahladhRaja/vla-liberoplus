"""GPU training-throughput benchmark for TurboVLA fine-tuning (synthetic batches, no dataset needed).

Builds the model from the released LIBERO checkpoint the way fine-tuning starts (DINOv3 trained with bf16 autocast,
BERT frozen, everything else trained in fp32), then times full optimizer steps (forward, masked L1 loss, backward,
grad clipping, TurboVLA's AdamW with EMA) at several per-GPU batch sizes. Reports samples/s and peak GPU memory.
Data loading (RLDS read + JPEG decode) is NOT included.
    python -u bench_train.py <TurboVLA repo root> [batch sizes, default 8,16,32]
"""

import sys
import time

import torch

root = sys.argv[1]
batch_sizes = [int(b) for b in (sys.argv[2] if len(sys.argv) > 2 else "8,16,32").split(",")]
sys.path[:0] = [root]

from turbovla.models.configuration import TurboVLAConfig
from turbovla.models.turbovla import build_turbovla
from turbovla.training import pi05  # noqa: F401  (patches trainer with the EMA optimizer, as in training)
from turbovla.training.pi05 import Pi05AdamW
from turbovla.training.trainer import masked_l1_loss

ckpt = torch.load(f"{root}/pretrained/TurboVLA/checkpoints/libero/turbovla_libero.pth", map_location="cpu")
cfg = TurboVLAConfig.from_mapping(ckpt["model_config"])
cfg.text.model_name_or_path = f"{root}/pretrained/bert-base-uncased"
cfg.vision.model_name_or_path = f"{root}/pretrained/dinov3-vitb16-pretrain-lvd1689m"
cfg.text.local_files_only = cfg.vision.local_files_only = True
cfg.vision.compute_precision = "bf16_autocast"
dev = torch.device("cuda")
torch.set_float32_matmul_precision("high")
model = build_turbovla(cfg)
model.load_state_dict(ckpt["model_state_dict"], strict=True)
model.to(dev).train()
params = [p for p in model.parameters() if p.requires_grad]
print(f"GPU {torch.cuda.get_device_name(0)} | trainable params {sum(p.numel() for p in params) / 1e6:.1f}M "
      f"of {sum(p.numel() for p in model.parameters()) / 1e6:.1f}M", flush=True)
opt = Pi05AdamW(params, lr=5e-5, betas=(0.9, 0.95), eps=1e-8, weight_decay=1e-10)
instr = ["pick up the black bowl between the plate and the ramekin and place it on the plate",
         "put both the alphabet soup and the tomato sauce in the basket"]


def step(bs):
    samples = {"dinov3": torch.randn(bs, 2, 3, 256, 256, device=dev)}
    states = torch.randn(bs, 8, device=dev)
    gt = torch.rand(bs, 12, 7, device=dev) * 2 - 1
    mask = torch.ones(bs, 12, device=dev)
    opt.zero_grad(set_to_none=True)
    loss = masked_l1_loss(model([instr[i % 2] for i in range(bs)], samples, states), gt, mask)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(params, 1.0)
    opt.step()


for bs in batch_sizes:
    try:
        torch.cuda.empty_cache(); torch.cuda.reset_peak_memory_stats()
        for _ in range(3):
            step(bs)
        torch.cuda.synchronize(); t = time.time(); n = 15
        for _ in range(n):
            step(bs)
        torch.cuda.synchronize(); dt = (time.time() - t) / n
        print(f"batch {bs:3d}: {dt * 1000:7.1f} ms/step | {bs / dt:6.1f} samples/s | "
              f"peak GPU memory {torch.cuda.max_memory_allocated() / 2**30:5.1f} GiB", flush=True)
    except torch.cuda.OutOfMemoryError:
        print(f"batch {bs:3d}: out of GPU memory", flush=True)
        opt.zero_grad(set_to_none=True); torch.cuda.empty_cache()
