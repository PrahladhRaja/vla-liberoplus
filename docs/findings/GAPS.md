# Open questions, caveats and unfinished work

## Caveats to state in the presentation
1. **Clean instructions are our reconstruction**, not an official LIBERO-Plus protocol. Report official numbers as
   the results and clean numbers as a labelled diagnostic.
2. **OFT+ clean-instruction numbers come from runs submitted on 2026-11-21** (all 8,493 affected tasks):
   `PENDING-OFTPLUS`.
3. **Different env seeds:** 7 for TurboVLA, 0 for OFT. Aggregate rates are unaffected; per-task OFT-vs-TurboVLA
   pairing is approximate. A 500-task OFT+ rerun with seed 7 (submitted 2026-11-21) puts a number on it:
   `PENDING-OFTPLUS`.
4. **One trial per task.** Individual task outcomes are noisy: the same model on two simulator builds agreed on
   only 86.7 % of tasks. Use category or suite rates with paired tests.
5. **Two OFT+ latency figures** (143.3 ms and 141.7 ms from two benchmarks). Pick one and use it throughout; the
   per-action speedup becomes 7.0× or 6.9×.

## Unexplained or unchecked
- **Released TurboVLA on standard LIBERO: 93.8 % ours vs 97.6 % in the TurboVLA paper.** Compared 2026-11-21:

  | Run | Spatial | Object | Goal | Long | Avg |
  |---|---|---|---|---|---|
  | Paper v3 (Table 1, 27 Sep 2026) | 97.0 | 100.0 | 98.2 | 95.2 | 97.6 |
  | Paper v1 (29 Jul 2026) | 99.2 | 99.8 | 97.4 | 94.2 | 97.7 |
  | Ours, Turing (MuJoCo 3.2.0) | 95.0 | 98.2 | 95.2 | **86.6** | 93.8 |
  | Ours, desktop (MuJoCo 3.1.6), `~/TurboVLA/outputs/evaluation/full_bf16/` | 93.2 | 99.6 | 96.2 | **86.2** | 93.8 |

  - **Settings match.** Both of our runs used exactly the README's documented command and the paper's protocol:
    - the unified `turbovla_libero.pth`, which is correct: the model card says one checkpoint is used for all
      suites (the README's `libero_object.pth` path is a stale example);
    - 50 trials per task, 12-step chunks, seed 7, bf16, `libero_all4` stats;
    - step limits 220/280/300/520, 10 settling steps.
  - **Our environment is not the cause.** Two independent machines with different MuJoCo versions agree with each
    other (93.8 both, Long 86.2 / 86.6).
  - **Where the gap is:** almost all of it is **Long (−8.6 to −9.0)**, plus about 2–3 pts on Spatial and Goal. On
    500 episodes per suite, sampling noise is about ±3 pts, so the Long gap is real.
  - **Most likely cause: the released weights.**
    - The released file holds only `model_state_dict`. But the official evaluator at the release commit (`6727c87`)
      refuses checkpoints without `ema_model_state_dict`; we had to patch it (`patches/TurboVLA/0001-eval-ema-fallback.patch`).
    - The paper uses EMA weights (v3 App. A.3). So the released weights may be the non-EMA weights, or a different
      training run from the paper's.
    - Also, the paper reports one run with an unstated "fixed evaluation seed", and v3 retrained the model (40k steps,
      batch 128; v1 used 80k, batch 256).
  - **For the presentation:** report ours, "93.8 % (released checkpoint, measured on two machines; paper reports
    97.6 %)". The fine-tuning comparison is unaffected, because released and fine-tuned were measured the same way.
  - **Optional follow-up:** ask the authors on GitHub whether the released LIBERO checkpoint is the paper's EMA
    checkpoint.
- **Fine-tuned TurboVLA still fails most on libero_goal** (40.1 % official), especially Robot 17.6 and Layout 37.2.
  Clean instructions help goal by +36.8, so most of the official goal gap is the leak. No analysis has been done of
  what remains.
- **422 regressions** after fine-tuning (4.2 % of tasks). Their size is about the rerun-noise level and they haven't
  been inspected individually.
- **Step 10k vs 17.5k:** almost all of the gain arrives by step 10k, so a shorter run would do. Training for longer
  (several epochs) was never tried.

## Planned but not run
| Item | Plan | Cost |
|---|---|---|
| Test 2: NAFNet deblurring front end for TurboVLA on Sensor Noise | `docs/plans/PLAN_test2_deblur_frontend.md` | ≈ 4–5 GPU-h |
| SmolVLA latency + merge into the shared table | `docs/plans/PLAN_smolvla_speed_quality.md` | ≈ 0.5 GPU-h + team data |

## Data housekeeping
- **Raw per-task files** for every in-scope run are in `results/` (results, plans, summaries, configs; no logs).
- **Scratch can be purged.** The fine-tuned checkpoint and the videos are archived. OFT+/OFT weights can be
  re-downloaded from Hugging Face.
