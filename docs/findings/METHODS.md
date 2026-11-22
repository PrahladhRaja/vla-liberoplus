# Methods, setup and glossary

## 1. Benchmarks
**LIBERO** (Liu et al., 2023) is a simulated tabletop benchmark: a Franka robot arm in robosuite on the MuJoCo
physics engine. We use its 4 standard suites of 10 tasks each:
- **Spatial:** the same bowl in different places;
- **Object:** pick different groceries into a basket;
- **Goal:** different goals in one kitchen scene;
- **Long, or libero_10:** two-step tasks.

Each standard evaluation runs 50 trials per task, 2,000 episodes per model.

**LIBERO-Plus** (2025) takes the same 40 tasks and generates **10,030 perturbed variants**:

| Category | Tasks | What changes |
|---|---|---|
| Camera | 1,599 | the scene camera's position: rotated, tilted, pulled closer or farther |
| Robot | 1,550 | the arm's initial joint pose |
| Language | 1,537 | the instruction is reworded on purpose |
| Light | 1,142 | light colour, direction or intensity |
| Background | 1,076 | table and wall textures |
| Noise | 1,601 | scene-camera image corruption: motion, Gaussian, zoom and glass blur, and fog; 10 severities each. The wrist camera is clean |
| Layout | 1,525 | extra objects added or objects moved |

Every task also carries a difficulty level from 1 to 5. **Success rate** is the share of tasks completed within the
suite's step limit.

Perturbation parameters can be decoded from task names (source: `~/LIBERO-plus/libero/libero/envs/env_wrapper.py`):
- `view_{horizontal°}_{vertical°}_{scale%}_…` for camera;
- `initstate_N` for the robot pose;
- `noise_N`, where 1–10 is motion blur, 11–20 Gaussian, 21–30 zoom, 31–40 fog and 41–50 glass, and severity is N minus the base;
- `light_N`;
- `table_N` / `tb_N` for backgrounds;
- `moved_levelX_sampleY` for layout;
- `language_N`.

## 2. Models
| | OpenVLA-OFT | OpenVLA-OFT+ | TurboVLA |
|---|---|---|---|
| Who | Stanford (Kim, Finn, Liang 2025) | LIBERO-Plus authors | Huazhong Univ. of Sci. & Tech. + Huawei, July 2026 (arXiv 2607.27205) |
| Checkpoint | `moojink/openvla-7b-oft-finetuned-libero-spatial-object-goal-10` (rev `638918f3…`) | `Sylvest/openvla-7b-oft-finetuned-libero-plus-mixdata` | `H-EmbodVis/TurboVLA` `turbovla_libero.pth` (code @ `6727c87`) |
| Size | 7.5B | 7.5B | 216M |
| Design | Two vision encoders (SigLIP + DINOv2) produce image tokens. Llama 2 7B (32 layers) reads them with the prompt and robot state, and a regression head outputs 8 actions at once | Same as OFT, further trained on LIBERO-Plus data | No LLM. A vision encoder (DINOv3 ViT-B) and a text encoder (BERT, 21-token limit) exchange information through light bidirectional attention, and a compact decoder outputs 12 actions |
| Inputs | scene + wrist image, 8-D state | same | scene + wrist image, state |
| Training data | standard LIBERO | LIBERO-Plus training mix | standard LIBERO (released); our fine-tune adds the LIBERO-Plus mix |

## 3. LIBERO-Plus evaluation protocol (our Turing eval kit, identical for all models)
Source: `cluster/eval_kit/README.md`, `cluster/eval_kit/eval_tasks.py`.
- **Episode setup:** one environment per task, rendered at 256 px. Every task starts from initial state 0, followed
  by 10 settling no-op steps.
- **Step limits:** spatial 220, object 280, goal 300, libero_10 520.
- **Execution:** each returned action chunk runs open loop (8 actions for OFT, 12 for TurboVLA). Success is when the
  environment reports the task done.
- **Trials:** one per task, all 10,030 tasks, in one fixed random order (`plan.tsv`, round-robin over the 28
  suite × category cells, so partial runs stay balanced).
- **Env seed:** 7 for TurboVLA and 0 for the OFT models. OFT runs through an HTTP action server, which was checked to
  give actions identical to OFT's in-process path.
- **Instructions:** official LIBERO-Plus `task.language`, with the leaked codes, unless a run is marked "clean"
  (`CLEAN_INSTRUCTION=1`).
- **Results:** one JSON line per task (`results*.jsonl`: suite, task_id, success, seconds, instructions fed and
  official). The tables are made with `summarize.py`, and paired comparisons with McNemar tests via
  `cluster/finetune_lp/compare_evals.py`.
- **Throughput:** 8 worker processes per A30 job. A full TurboVLA run takes about 5 h 20 min on 2 GPUs, and an OFT
  run about 6.5 h on 2 GPUs.

**Standard LIBERO** uses each model's own evaluator: OFT `run_libero_eval.py`, and TurboVLA
`experiments/libero/evaluate.py` with seed 7 and bf16. Both run 50 trials per task on the original LIBERO at
`8f1084e`.

## 4. Our TurboVLA fine-tune (`cluster/finetune_lp/README.md`)
- **Data:** `Sylvest/libero_plus_rlds`, the LIBERO-Plus training mix. It has 14,347 episodes and 2,238,036 steps (78 GB),
  the **same data OFT+ was trained on**.
- **Recipe:**
  - starts from the released `turbovla_libero.pth`;
  - 1 epoch = 17,500 steps at global batch 128 (2 GPUs × 32 × 2 accumulation);
  - lr 5e-5, 1,000 warmup steps, then constant; AdamW (0.9, 0.95); grad clip 1.0;
  - masked L1 loss on 12-step action chunks;
  - DINOv3 in bf16 autocast; BERT frozen;
  - EMA 0.999 (the evaluated weights);
  - released normalization stats. The new data's action ranges fit inside them, so nothing was clamped.
- **Cost:** 3 h 51 min on 2 A30s (1.26 steps/s), 13.7 GB peak GPU memory, final loss about 0.045.
- **Pipeline:** chained SLURM jobs, s0 to s7 (download → extract → stats → smoke test → train → eval → report).
- **Checkpoint:** `turbovla_step_17500.pth`.

## 5. Test 1: instruction-leak diagnostic (`docs/plans/PLAN_test1_instruction_leak.md`)
- **Clean instruction:** the parent task's original LIBERO instruction, found by longest-prefix match. All 8,493
  affected tasks map to exactly 1 of 40 strings. Language-category tasks stay unchanged.
- **Pairing:** each clean run is paired with that model's official run (same seed and start state), and a 200-task
  same-seed official rerun measures noise.
- **Hypotheses were fixed before running.** TurboVLA gains ≥ 3 pts (confirmed: +15.6); OFT is insensitive (holds for OFT+ at +0.1;
  fails for the original OFT at +3.0).
- **Stages:**
  - stage A: the first 1,000 affected tasks for every model;
  - stage B: all 8,493 affected tasks, for fine-tuned TurboVLA and OFT+.
- **Status:** official-protocol scores remain the reported results; clean numbers are a labelled diagnostic.

## 6. Infrastructure (WPI Turing)
- **Resources:** a course account, `academic` partition. NVIDIA A30 24 GB GPUs; at most 2 GPUs and 48 h per job.
- **Containers:**
  - LIBERO-Plus/TurboVLA: Apptainer `liberoplus.sif` (Ubuntu 24.04, EGL rendering, torch 2.3.1);
  - OFT: `openvla_oft.sif` (torch 2.2.0, OFT's transformers 4.40.1 fork).
- **Assets:** packed as one squashfs file rather than about 449k small files.
- **Lesson learned:** MuJoCo 3.1.6 leaks a file handle per mesh load and stalls long runs; we pinned 3.2.0. The
  simulator version also changes episodes, which explains why the desktop and Turing runs agree on only 86.7 % of
  tasks.
- **Teammate kit:** `cluster/starter_kit/`, shared with teammates.

## 7. Glossary (for slides and a non-specialist audience)
- **VLA (vision-language-action model):** looks at camera images, reads a typed instruction, and outputs robot arm
  movements.
- **Action chunk:** several future movements predicted at once and executed without looking again (8 for OFT, 12 for
  TurboVLA). "Per executed action" latency = query time ÷ chunk length.
- **Fine-tuning:** continuing to train a released model on new data, here LIBERO-Plus's perturbed scenes.
- **Perturbation:** a deliberate change to the scene (camera, light, background, image noise, layout, robot start
  pose, wording) that tests robustness.
- **Instruction leak / stray codes:** LIBERO-Plus's habit of appending file-name codes to the instruction.
- **Paired / McNemar test:** compares two models on the same tasks by counting the tasks only one of them solves.
- **Rerun noise floor:** how many outcomes flip when the same model reruns the same tasks. Differences smaller than
  this are not meaningful.
- **EMA weights:** a smoothed average of the weights during training, usually more stable; these are what we
  evaluate.
