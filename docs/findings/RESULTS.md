# Results (in scope: LIBERO, LIBERO-Plus, TurboVLA; OpenVLA-OFT / OFT+ as reference)

All runs are on WPI Turing A30 GPUs unless marked otherwise. Success rates are percentages.
- **LIBERO-Plus:** all 10,030 tasks, one trial each, in the same task order for every model. Official instructions unless marked
  "clean".
- **Standard LIBERO:** 4 suites × 10 tasks × 50 trials.
- **Env seeds:** 7 for TurboVLA, 0 for the OFT models, which makes OFT-vs-TurboVLA per-task pairing approximate
  (see GAPS.md).

Each section names its source, as a path in this repo. Values marked `PENDING-OFTPLUS` are filled in from the OFT+
gap-fill runs (`experiments/robustness/gapfill_analysis.sh`).

---

## 1. Headline table
| Model | Params | LIBERO-Plus (official) | LIBERO-Plus (clean instr.) | Standard LIBERO | Latency per query | Actions per query | **Per executed action** | Peak GPU mem |
|---|---|---|---|---|---|---|---|---|
| OpenVLA-OFT (LIBERO-trained) | 7.5B | 68.7 | +3.0 on 1,000 tasks (only measured there) | 96.1 | 139.6 ms | 8 | 17.5 ms | ~15 GB |
| OpenVLA-OFT+ (released, LIBERO-Plus-trained) | 7.5B | **80.5** | `PENDING-OFTPLUS` | 96.6 | 143.3 ms | 8 | 17.9 ms | ~15 GB |
| TurboVLA (released) | 216M | 45.5 | +15.1 on 1,000 tasks (only measured there) | 93.8 | ≈ 30.7 ms (same architecture) | 12 | ≈ 2.6 ms | 0.43 GB |
| **TurboVLA fine-tuned on LIBERO-Plus (ours)** | 216M | **68.9** | **≈ 82.1** | **96.5** | **30.7 ms** | 12 | **2.56 ms** | **0.43 GB** |

Notes:
- **Published values, for comparison:**
  - LIBERO-Plus paper: OFT 69.6 and OFT+ 79.6. Our Turing replications are 68.7 and 80.5.
  - TurboVLA paper: 97.6 standard LIBERO (our released-model measurement is 93.8; see GAPS.md) and 31.2 ms on an
    RTX 4090.
- **Clean-instruction full-benchmark values** are clean results on the 8,493 affected tasks plus the unchanged
  Language category.
  - OFT+'s clean-instruction run (all 8,493 affected tasks) was submitted on 2026-11-21: `PENDING-OFTPLUS`.
- **Latency:** batch 1, end to end, on an A30.
  - The OFT+ figure is the controlled benchmark (job 2430342): 143.3 ms, with the LLM taking 100.0 and vision 27.8.
    A later benchmark measured 141.7 ms (17.7 ms per action). Pick one and use it consistently.
  - TurboVLA's 30.7 ms is 3.5 ms preprocessing plus 26.1 ms model (job 2471859).
- **Speedups vs OFT+:** 4.7× per query, **7.0× per executed action** (6.9× with 141.7 ms). Model size is 35× smaller
  (7.5B / 216M).
- **Sources:**
  - `docs/oft_reference.md` (OFT+ baselines, latency for OFT+ and TurboVLA);
  - `docs/plans/PLAN_oft_libero_reference.md`;
  - `docs/plans/PLAN_test1_instruction_leak.md`;
  - `results/turbovla/reports/`.

---

## 2. LIBERO-Plus by perturbation category (official instructions, 10,030 tasks)
| Model | Camera | Robot | Language | Light | Background | Noise | Layout | **All** |
|---|---|---|---|---|---|---|---|---|
| OFT (LIBERO-trained) | 55.9 | 23.9 | 84.8 | 92.9 | 87.1 | 74.8 | 73.9 | **68.7** |
| OFT+ | 95.3 | 28.8 | 85.7 | 94.8 | 96.4 | 94.9 | 75.2 | **80.5** |
| OFT+ in the LIBERO-Plus paper (Table 2) | 92.8 | 30.3 | 85.8 | 94.9 | 93.9 | 89.3 | 77.6 | 79.6 |
| TurboVLA released | 23.3 | 33.3 | 67.9 | 67.8 | 47.7 | 31.5 | 54.8 | **45.5** |
| TurboVLA fine-tuned | 72.5 | **40.3** | 73.1 | 85.0 | 80.8 | 73.1 | 65.3 | **68.9** |
| Tasks per category | 1,599 | 1,550 | 1,537 | 1,142 | 1,076 | 1,601 | 1,525 | 10,030 |

- **Robot (unusual robot starting pose)** is the one category where TurboVLA beats OFT and OFT+, even with
  official instructions.
- **Sources:**
  - `results/turbovla/reports/lp_eval_ft_vs_baseline.md`;
  - `docs/oft_reference.md`;
  - `docs/plans/PLAN_oft_libero_reference.md`.

## 3. LIBERO-Plus by suite (official instructions)
| Model | Spatial | Object | Goal | Long (libero_10) | **All** |
|---|---|---|---|---|---|
| OFT (LIBERO-trained) | 75.3 | 75.7 | 57.9 | 66.5 | **68.7** |
| OFT+ | 84.8 | 83.7 | 72.3 | 81.5 | **80.5** |
| TurboVLA released | 52.3 | 58.6 | 25.2 | 46.7 | **45.5** |
| TurboVLA fine-tuned | 75.6 | 83.8 | 40.1 | 77.3 | **68.9** |

- **libero_goal is TurboVLA's weak suite.** Its instructions are short, so the leaked codes reach the text encoder
  and dominate it (see §6).
- **Full suite × category grids:**
  - TurboVLA: `results/turbovla/reports/lp_eval_ft_vs_baseline.md`;
  - OFT+: `docs/oft_reference.md`.

## 4. By difficulty level (LIBERO-Plus's own level 1–5 labels, official instructions)
| Category | TurboVLA released → fine-tuned (L1 / L2 / L3 / L4 / L5) | OFT+ (L1 / L2 / L3 / L4 / L5) |
|---|---|---|
| Camera | 44→79 / 25→70 / 21→70 / 22→70 / 16→74 | 97 / 99 / 97 / 96 / 90 |
| Robot | 61→73 / 55→58 / 32→45 / 20→24 / 8→11 | 74 / 50 / 24 / 7 / 2 |
| Language | 78→84 / 76→78 / 76→80 / 70→79 / 43→47 | 97 / 95 / 94 / 91 / 56 |
| Light | 66→82 / 80→91 / 75→88 / 65→89 / 65→84 | 95 / 96 / 99 / 97 / 89 |
| Background | 69→91 / 56→87 / 46→81 / 37→71 / 12→62 | 97 / 99 / 98 / 98 / 86 |
| Noise | 45→68 / 48→79 / 35→73 / 17→68 / 6→71 | 94 / 96 / 94 / 96 / 93 |
| Layout | 64→72 / 64→72 / 60→71 / 50→65 / 33→46 | 82 / 85 / 83 / 74 / 49 |
| **All** | 63→78 / 55→76 / 47→71 / 40→66 / 25→55 | — |

Source: `results/turbovla/reports/lp_eval_ft_detailed.md`, `docs/oft_reference.md`. 121 tasks have no level.

---

## 5. Effect of LIBERO-Plus fine-tuning
| Model | Before → after | Gain | Largest gains |
|---|---|---|---|
| OpenVLA-OFT → OFT+ (fine-tuned by the LIBERO-Plus authors) | 68.7 → 80.5 | +11.8 | Camera +39.4, Noise +20.1, Background +9.3 |
| TurboVLA released → fine-tuned (ours) | 45.5 → 68.9 | **+23.5** (95 % CI ±1.0) | Camera +49.2, Noise +41.5, Background +33.1, Light +17.3 |

TurboVLA detail (`results/turbovla/reports/lp_eval_ft_vs_baseline.md`, `lp_eval_ft_detailed.md`):
- **Every category improves significantly.** Per-category McNemar tests give p ≤ 1e-6, and overall z = 41.6.
- **Per-task changes:**
  - solved by both: 4,138;
  - neither: 2,695;
  - fine-tuned only: 2,775;
  - released only (regressions): 422, or 4.2 %. Largest regression groups: object/Robot 39 and spatial/Language 37.
- **Weakest remaining cells** (fine-tuned): libero_goal Robot 17.6, Language 32.4, Layout 37.2 and Noise 37.7.
- **Base tasks:** 38 of the 40 original LIBERO tasks improve. Two get worse: "put the white mug on the plate and put
  the chocolate pudding to the right of the plate" (−6.4) and "pick up the black bowl on the wooden cabinet…"
  (−9.5).
- **Shorter episodes:** mean episode time drops 26.0 → 19.4 s, and from 113.5 → 79.2 s on Sensor Noise tasks.
- **Standard LIBERO did not regress:** 93.8 → 96.5 (+2.8, paired z = 4.32, p ≈ 1.6e-5).
  - Largest gain: libero_10, 86.6 → 93.0 (+6.4, significant).
  - The other suites improve too, but not significantly (§7).

**Training length:** the step-10,000 checkpoint already gets **98 %** of the gain. On the same 3,011 tasks it
scores 69.0 vs 69.5 for the final step 17,500 (+0.4 ±1.3, not significant). Source: `results/turbovla/reports/ck10k_vs_final.md`.

---

## 6. Instruction leak (robustness test 1)
**The finding:** LIBERO-Plus builds each instruction from the task's file name.
- **How many tasks:** 8,493 of 10,030 (85 %, every category except Language).
- **What the model sees:** codes such as `view 0 0 100 2 352 initstate 0`, `noise 3`, `table 1` or `add 10` appended
  to the instruction.
- **The fix we tested:** "clean" replaces it with the parent task's original LIBERO instruction. That is our own
  reconstruction, not an official protocol.
- **Pairing:** each clean run is paired with the same model's official run (same seed). A 200-task same-seed rerun
  gives the noise floor.

| Model | Tasks | Official → clean | Flips (official only / clean only) | p (McNemar) | Rerun floor (200 tasks) |
|---|---|---|---|---|---|
| TurboVLA fine-tuned | 8,493 affected | 68.2 → **83.7 (+15.6)** | 233 / 1,554 | 5e-214 | 4 / 4 flips |
| TurboVLA released | first 1,000 affected | 44.2 → 59.3 (+15.1) | 49 / 200 | 2e-21 | 3 / 4 |
| OpenVLA-OFT+ | 8,493 affected | `PENDING-OFTPLUS` | | | 3 / 3 |
| OpenVLA-OFT (LIBERO-trained) | first 1,000 affected | 67.1 → 70.1 (+3.0); Camera +13.1 | 48 / 78 | 0.01 | 2 / 2 |

Fine-tuned TurboVLA (8,493 tasks):
- **By category:** Camera +19.7, Robot +13.5, Light +10.2, Background +14.3, Noise +23.2, Layout +10.1 (all p < 1e-19).
- **By suite:** spatial +12.9, object +6.2, **goal +36.8**, libero_10 +5.9.

**Why TurboVLA is hit and OFT isn't:**
- TurboVLA's BERT text encoder reads at most 21 tokens. Clean instructions are 6–21 tokens long, so the codes
  displace real words. They still reach the model in 7,820 of the 8,493 affected tasks.
- OFT reads the whole prompt but largely ignores language. The LIBERO-trained OFT reacts somewhat (+3.0, mostly
  Camera). The LIBERO-Plus-trained OFT+: `PENDING-OFTPLUS`.

**Fine-tuning gain is not an artefact of the leak:** on the same 1,000 tasks it is +26.7 with official instructions
and +27.5 with clean ones. The leak costs the released and fine-tuned models alike (+15.1 vs +15.9).

**Clean instructions on both sides, by category (10,030 tasks; Language unchanged):**

| Model | Camera | Robot | Language | Light | Background | Noise | Layout | **All** |
|---|---|---|---|---|---|---|---|---|
| OFT+ | `PENDING-OFTPLUS` | | | | | | | |
| TurboVLA fine-tuned | 92.2 | **53.8** | 73.1 | 95.3 | 95.1 | 96.3 | 75.4 | **82.1** |
| TurboVLA − OFT+ | `PENDING-OFTPLUS` | | | | | | | |

Paired tests per category: `PENDING-OFTPLUS` (`gapfill_summary.py`).

**Independent confirmation:** a teammate saw the same effect with SmolVLA. See also LIBERO-Plus GitHub issue #64,
which misses the Robot category.

Sources: `docs/plans/PLAN_test1_instruction_leak.md` §7, `docs/plans/PLAN_oft_libero_reference.md`,
`results/robustness/t1_analysis.txt`.

---

## 7. Standard LIBERO by suite (4 × 10 × 50 = 2,000 episodes per model)
| Model | Spatial | Object | Goal | Long (libero_10) | **Mean** | Evaluator |
|---|---|---|---|---|---|---|
| OFT (LIBERO-trained) | 96.6 | 97.6 | 95.6 | 94.6 | **96.1** | OFT `run_libero_eval.py` |
| OFT+ | 96.8 | 98.4 | 96.8 | 94.4 | **96.6** | OFT `run_libero_eval.py` |
| TurboVLA released | 95.0 | 98.2 | 95.2 | 86.6 | **93.8** | TurboVLA `experiments/libero/evaluate.py`, seed 7 |
| TurboVLA fine-tuned | 97.4 | 99.6 | 96.2 | 93.0 | **96.5** | same |

- **Published:** the TurboVLA paper reports 97.6, and OpenVLA-OFT reports 97.1.
- **Per-task changes ≥ 10 pts for TurboVLA:** `results/turbovla/reports/libero_std_released_vs_finetuned.md`. The largest is
  libero_10 task 8, 54 → 82.

---

## 8. Reproducibility and noise floors (use these when someone asks "is that difference real?")
- **Same released TurboVLA, desktop vs Turing** (different MuJoCo build):
  - overall: 44.6 vs 45.5;
  - the same outcome on only 86.7 % of tasks (622 / 707 flips each way), McNemar p ≈ 0.02;
  - per-category flips: 10–15 %.
  - Source: `results/turbovla/reports/lp_eval_full_vs_desktop.md`.
- **Same model, same seed, same machine, rerun:** 1.5–4 % of tasks flip (§6 rerun floors). Aggregate rates are stable.
- **Turing 1 worker vs 8 workers per GPU:** identical outcomes on all 29 test tasks (`results/turbovla/test28/`).
- **One trial per task, so a single task's outcome is noisy.** Report category or suite rates with paired tests,
  not individual tasks (except as video illustrations).

## 9. Ready-made video examples (all same task, same seed)
In each clip, the left half is the scene camera and the right half the wrist camera. Videos are not in this repo.
- **Full-run sets** (`lp_eval_full_videos`, `lp_eval_ft_videos`): `/archive/<user>/turbovla_liberoplus_2026-10/` on Turing, as tars.
- **Rerun clips** (`reruns/…`): job dirs `~/vid_turbovla_clean`, `~/vid_turbovlaR_clean` on Turing.
- **Local copy of all of them:** the project desktop, `~/wpi-turing/videos/`, which the paths below are relative to.

| Shows | Task | Before (fails) | After (succeeds) |
|---|---|---|---|
| Fine-tuning fixes camera shift (rotated 32°) | libero_goal 755 | `lp_eval_full_videos/libero_goal/task0755_failure.mp4` | `lp_eval_ft_videos/libero_goal/task0755_success.mp4` |
| Leak: same model, only the instruction differs (camera −43°, tilt 15°) | libero_goal 1000 | `lp_eval_ft_videos/libero_goal/task1000_failure.mp4` | `reruns/vid_turbovla_clean/videos/libero_goal/task1000_success.mp4` |
| Fine-tuning fixes fog (max severity); released fails even with a clean instruction | libero_spatial 1536 | `reruns/vid_turbovlaR_clean/videos/libero_spatial/task1536_failure.mp4` | `lp_eval_ft_videos/libero_spatial/task1536_success.mp4` |
| Fine-tuning fixes strong blue light | libero_10 2245 | `reruns/vid_turbovlaR_clean/videos/libero_10/task2245_failure.mp4` | `lp_eval_ft_videos/libero_10/task2245_success.mp4` |
| Fine-tuning fixes a black table (background) | libero_object 57 | `reruns/vid_turbovlaR_clean/videos/libero_object/task0057_failure.mp4` | `lp_eval_ft_videos/libero_object/task0057_success.mp4` |

- **More candidates:** 107 verified "released fails with both instructions, fine-tuned succeeds" tasks in the Light,
  Noise and Background categories; re-derive it with `experiments/robustness/pick_video_tasks.py` on Turing.
- **Full video sets for whole runs** (named `taskNNNN_success|failure.mp4`):
  - `lp_eval_full_videos`: released TurboVLA;
  - `lp_eval_ft_videos`: fine-tuned TurboVLA;
  - `lp_eval_oftplus_videos`: OFT+;
  - `oft/oftL/eval`: original OFT on standard LIBERO.
