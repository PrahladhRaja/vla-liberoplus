# OpenVLA-OFT / OFT+ reference runs: setup, baselines and latency

How the two large-model reference points were set up and measured on Turing. Results tables for all models are in
[findings/RESULTS.md](findings/RESULTS.md).
- **Hardware:** Turing A30 (24 GB) unless stated.
- **Times:** wall clock.
- **"OFT+"** is the released `Sylvest/openvla-7b-oft-finetuned-libero-plus-mixdata`.
- **"OpenVLA-OFT"** is the LIBERO-trained `moojink/openvla-7b-oft-finetuned-libero-spatial-object-goal-10` that OFT+
  started from.

## Code and environment
| Item | Version |
|---|---|
| openvla-oft | upstream `e4287e9` plus [`patches/openvla-oft`](../patches/openvla-oft): (1) register the `libero_mix` dataset, add task subset and query timing to the LIBERO eval; (2) add the latency benchmark, the LIBERO action server and the server equivalence check |
| Eval kit | `cluster/eval_kit` + `adapters/openvla_oft.py`, `eval_job_oft.sbatch`, `ENV_SEED` option; OFT run dirs made by `cluster/oft_container/setup_oft_eval.sh` |
| Container | `/scratch/$USER/oft/openvla_oft.sif`, built 2026-10-29 (job 2430249) from `cluster/oft_container/openvla_oft.def` + `requirements.lock.txt`. Contents: torch 2.2.0+cu121, transformers 4.40.1 (moojink OFT fork), peft 0.11.1, timm 0.9.10, TF 2.15.0, tensorflow-metadata 1.13.1, mujoco 3.2.0, robosuite 1.4.1, no flash-attn |
| OFT+ weights | `/scratch/$USER/ckpts/oftplus` (job 2430263): 982 merged tensors, 15,082,474,368 bytes; heads `--150000` |
| OpenVLA-OFT weights | `/scratch/$USER/ckpts/oft_libero` (job 2502785), revision `638918f3…`, per-suite norm stats |
| Data | `/scratch/$USER/libero_plus_data/libero_mix/1.0.0` (14,347 episodes, 2,238,036 steps) |

**OFT+ model facts:**
- **Inputs:** 2 images (third person + wrist) → 512 patch tokens + 1 proprio token.
- **Prompt:** `"In: What action should the robot take to {task}?\nOut: "`.
- **Decoding:** 56 zeroed action placeholders (8 × 7), decoded in parallel with bidirectional attention. Token layout:
  `[BOS] | 512 patches | proprio | prompt | 56 action | </s>`, about 605 tokens.
- **Attention:** the bidirectional attention lives only in the moojink transformers fork's `LlamaSdpaAttention`, so
  SDPA is mandatory and flash-attn must not be installed.
- **Training (LIBERO-Plus paper, App. D.4):** from the official OFT weights; 8×A100; lr 5e-4; 100k steps; effective
  batch 16; AdamW wd 0.1; cosine with warmup.

## Dataset statistics (job 2430278, 2026-10-30, CPU)
OpenVLA-OFT's loader on `libero_mix` reproduces OFT+'s released `dataset_statistics.json` **exactly**:
- 2,238,036 transitions and 14,347 trajectories;
- action and proprio mean/std/min/max/q01/q99 max |diff| 0.00.

This is the same data our TurboVLA fine-tune used.

## Inference smoke test (job 2430279, 2026-10-30, 1 A30)
`run_libero_eval.py` on LIBERO-Plus `libero_spatial` tasks 0–1, 2 trials each, OFT LIBERO settings.

| Metric | Value |
|---|---|
| Episodes succeeded | 4 / 4 (functional check only) |
| Peak GPU memory | 16,472 MiB |
| Model query (one 8-step chunk), median after the first | 138.2–143.3 ms (≈ 17–18 ms per control step) |
| First query (CUDA warm-up) | 3,165 ms |

## Latency benchmark (job 2430342, 2026-10-30)
- **Script:** `experiments/robot/bench_latency.py`.
- **Settings:** batch 1, OFT's sample LIBERO observation, 100 warm-up + 500 timed queries, bf16, SDPA attention.

| Component (one 8-step action chunk) | Median | p95 |
|---|---|---|
| End to end (`get_action`) | 143.3 ms | 144.4 ms |
| LLM (32 layers + final norm + lm_head) | 100.0 ms (70 %) | 100.9 ms |
| Vision backbone (SigLIP + DINOv2, 2 images) | 27.8 ms | 28.2 ms |
| Projector | 0.8 ms | 0.8 ms |
| Remainder (preprocessing, action head, un-normalization) | ≈ 15 ms | |

- **Sequence and memory:** LLM sequence length 605 tokens; peak GPU memory 15.0 GiB.
- **A second benchmark** with 200 queries measured 141.7 ms end to end (LLM 98.7, vision 27.6, 14.98 GB). Both
  figures appear in the project notes; use one consistently.
- **Original OpenVLA-OFT** (job 2502786): 139.6 ms end to end, LLM 98.9 ms
  (`results/oft/oft_libero_latency_bench.json`).

## Eval-kit action server (jobs 2430342, 2430343, 2026-10-30)
- **Equivalence check** (`check_server.py`): the HTTP server + kit adapter was compared with OFT's in-process path on a
  real LIBERO-Plus episode, 10 queries. **Max |diff| = 0.0.** The HTTP query median is 172.2 ms, about 29 ms of
  serialization overhead, which affects eval wall time only.
- **Mini kit run:** 48 plan rows covering all 28 cells, 8 workers + 1 server on one A30.
  - 48/48 tasks in 6.2 min, 0 hangs;
  - GPU peak 21.3 GB;
  - throughput ≈ 7.8 tasks/min per GPU, so a full LIBERO-Plus run is about 21 GPU-h.

## Evaluation protocol note
- **Seed:** OpenVLA-OFT's own `run_libero_eval.py` seeds each environment with `env.seed(0)`, while the eval kit
  (and every TurboVLA run) uses `env.seed(7)`. Decision (2026-10-30): OFT runs use OFT's protocol, `ENV_SEED=0`.
  Python, NumPy and torch are still seeded with `SEED=7`.
- **Everything else matches TurboVLA's runs:** initial state 0, 10 settling no-ops, step limits 220/280/300/520.
- **Pairing:** all OFT runs pair with each other task by task. Pairing with TurboVLA runs is approximate, because of
  the different env seed. The size of that effect is measured by the seed-7 OFT+ run, `lp_seed7_oftplus`.

## OFT+ baselines on Turing (2026-10-30)
**LIBERO-Plus**, `results/oft/lp_eval_oftplus`:
- **Jobs:** 2430419 + 2430420 (1 A30 + 16 CPU + 32 GB each), 6 h 23 min and 6 h 29 min.
- **Coverage:** 10,030 / 10,030 tasks, after rerunning 3 tasks lost to an HTTP keep-alive race (job 2437087; the
  adapter now retries on a fresh connection).

| | Camera | Robot | Language | Light | Background | Noise | Layout | Total |
|---|---|---|---|---|---|---|---|---|
| libero_spatial | 97.6 | 30.0 | 91.8 | 98.3 | 95.3 | 86.9 | 96.1 | 84.8 |
| libero_object | 98.7 | 24.1 | 100.0 | 99.3 | 98.8 | 98.3 | 77.4 | 83.7 |
| libero_goal | 97.3 | 21.8 | 59.8 | 91.8 | 98.6 | 98.7 | 55.5 | 72.3 |
| libero_10 | 88.1 | 39.9 | 94.0 | 89.4 | 93.1 | 94.7 | 73.4 | 81.5 |
| **all suites (Turing, 10,030 tasks)** | **95.3** | **28.8** | **85.7** | **94.8** | **96.4** | **94.9** | **75.2** | **80.5** |
| LIBERO-Plus paper, Table 2 | 92.8 | 30.3 | 85.8 | 94.9 | 93.9 | 89.3 | 77.6 | 79.6 |

By difficulty level (L1–L5):

| Category | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| Camera | 97 | 99 | 97 | 96 | 90 |
| Robot | 74 | 50 | 24 | 7 | 2 |
| Language | 97 | 95 | 94 | 91 | 56 |
| Light | 95 | 96 | 99 | 97 | 89 |
| Background | 97 | 99 | 98 | 98 | 86 |
| Noise | 94 | 96 | 94 | 96 | 93 |
| Layout | 82 | 85 | 83 | 74 | 49 |

**Standard LIBERO:**
- **Run:** OFT's `run_libero_eval.py`, 4 × 10 × 50, job 2430421, 4 h 58 min.
- **Results:** spatial 96.8 %, object 98.4 %, goal 96.8 %, libero_10 94.4 %; **average 96.6 %** (1,932 / 2,000).
- **Logs:** `results/oft/libero_std/oftplus/`.

**Original OpenVLA-OFT** (`docs/plans/PLAN_oft_libero_reference.md`): LIBERO-Plus 68.7 % (paper 69.6), standard
LIBERO 96.1 %.

## TurboVLA latency, measured the same way (job 2471859)
- **Checkpoint:** fine-tuned TurboVLA (`turbovla_step_17500.pth`).
- **Settings:** bf16, batch 1, OFT's sample observation resized to 256 px, 50 warm-up + 300 timed queries.
- **Script:** `cluster/oft_container/turbovla_latency.{py,sbatch}`.

| | TurboVLA (fine-tuned) | OFT+ |
|---|---|---|
| End to end per query | **30.7 ms** (p95 30.8): preprocess 3.5 + model 26.1 | 143.3 ms |
| Actions per query (executed open loop) | 12 | 8 |
| **Per executed action** | **2.56 ms** | 17.9 ms |
| Parameters / peak GPU memory | 216 M / 0.43 GB | 7.5 B / 15–16.5 GB |

TurboVLA is 4.7× faster per query and **7.0× faster per executed action** than OFT+ on the same A30. That matches
the TurboVLA paper's 31.2 ms on an RTX 4090.
