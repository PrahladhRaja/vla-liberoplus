# Plan: non-fine-tuned OpenVLA-OFT reference (the LIBERO-trained model OFT+ started from)

**Status:** prepared 2026-11-10 (scripts on Turing in `~/oft_container`), not submitted.

**Why:** we evaluated OFT+ (LIBERO-Plus fine-tuned by the LIBERO-Plus authors) and both TurboVLA versions, but not
OFT before LIBERO-Plus fine-tuning. The only number we have for it is the paper's leaderboard value, 69.6 %. Adding
it gives:
1. **Parallel fine-tuning comparisons**, measured with the same kit: TurboVLA released → fine-tuned (+23.5) vs
   OFT original → OFT+.
2. **A clean-instruction test (test 1)** showing whether ignoring the leaked IDs is a property of the OFT
   architecture or something LIBERO-Plus fine-tuning taught OFT+. Released TurboVLA (jobs 2502776/7) answers the
   same question for TurboVLA.
3. **A Turing replication** of the paper's 69.6, as we did for OFT+ (80.5 vs 79.6).

**Model:** `moojink/openvla-7b-oft-finetuned-libero-spatial-object-goal-10` at revision `638918f3…` → downloaded to
`/scratch/$USER/ckpts/oft_libero`. It has merged weights, `action_head--300000`, `proprio_projector--300000` and
per-suite norm stats, with the same inputs as OFT+ (2 images + proprio, chunk 8, L1 head).

**The one protocol subtlety:**
- Unlike OFT+ (same mixed-data stats under all 4 suite keys), this model has **different action normalization per
  suite**. Our OFT server uses one key per process.
- So every LIBERO-Plus run is **split by suite**: one eval-kit dir and job per suite, with server
  `--unnorm_key <suite>` (resolves to `<suite>_no_noops`).
- Standard LIBERO uses OFT's own `run_libero_eval.py`, which picks the key per suite automatically.
- Plans are the baseline plan filtered by suite in plan order, so the union of the 4 dirs is exactly the task set of
  the other models' runs. `oftL_merge.sh` merges them for `compare_evals.py`.

**Jobs** (`bash ~/oft_container/oftL_submit.sh`; all wait on the download with `afterok`; IDs → `oftL_jobs.env`):

| Job | What | Est. |
|---|---|---|
| download | pinned revision, file + norm-stats checks | ≤ 1 h CPU |
| `oftL_eval_std.sbatch` | latency bench (should match OFT+, same arch) + standard LIBERO 4×10×50 | ≈ 5 GPU-h |
| 4 × `lp_eval_oftL_<suite>` | full LIBERO-Plus, official instructions, ENV_SEED 0 | ≈ 13–16 GPU-h total |
| 4 × `lp_t1_oftL_<suite>_clean` | test 1: same first 1,000 affected rows as the other models, clean instructions | ≈ 1.5 GPU-h |
| 4 × `lp_t1_oftL_<suite>_rerun` | test 1 rerun control: same first 200 rows, official instructions | ≈ 0.3 GPU-h |

- **Total:** ≈ 20–23 GPU-h, 13 GPU jobs (one email each) plus the download.
- **Queue:** behind test 1 stage B and released-TurboVLA test 1 → ≈ 10–12 h wall after they finish, at the
  2-GPU cap.
- `T1=0` skips the 8 test-1 jobs.

**Analysis:**
- `oftL_merge.sh` → `~/lp_eval_oftL`, `~/lp_t1_oftL_clean`, `~/lp_t1_oftL_rerun`.
- Then `compare_evals.py` against OFT+ (`~/lp_eval_oftplus`: the fine-tuning gain) and against
  released TurboVLA (`~/lp_eval_full`, seed caveat).
- For test 1: clean vs official, with the rerun floor, as for the other models.
- Results go in `docs/findings/RESULTS.md` and the test 1 log.

## Log
- **2026-11-10, submitted** (user decision); IDs also in `~/oft_container/oftL_jobs.env`.
  - **Download:** 2502785.
  - **Standard LIBERO + bench:** 2502786.
  - **Full LIBERO-Plus:**

    | Suite | Job | Tasks |
    |---|---|---|
    | spatial | 2502787 | 2,402 |
    | object | 2502788 | 2,518 |
    | goal | 2502789 | 2,591 |
    | libero_10 | 2502790 | 2,519 |
    | **total** | | **10,030** ✓ |

  - **Test 1:**

    | Suite | Clean job (tasks) | Rerun job (tasks) |
    |---|---|---|
    | spatial | 2502791 (249) | 2502792 (51) |
    | object | 2502793 (251) | 2502794 (51) |
    | goal | 2502795 (249) | 2502796 (49) |
    | libero_10 | 2502797 (251) | 2502798 (49) |
    | **total** | **1,000** ✓ | **200** ✓ |

## Results (2026-11-11)
- **Download** 2 min; norm-stats keys `libero_{spatial,object,goal,10}_no_noops`.
- **Full LIBERO-Plus (merged, 10,030):** **68.7 %** (paper leaderboard 69.6 → replicated).

  | Category | Original OFT | OFT+ | Change |
  |---|---|---|---|
  | Camera | 55.9 | 95.3 | −39.4 |
  | Robot | 23.9 | 28.8 | −5.0 |
  | Language | 84.8 | 85.7 | −0.9 |
  | Light | 92.9 | 94.8 | −1.9 |
  | Background | 87.1 | 96.4 | −9.3 |
  | Noise | 74.8 | 94.9 | −20.1 |
  | Layout | 73.9 | 75.2 | −1.3 |
  | **All** | **68.7** | **80.5** | **−11.8** |

  - **By suite vs OFT+:** spatial 75.3 (−9.6), object 75.7 (−8.0), goal 57.9 (−14.4), libero_10 66.5 (−15.0).
  - **So LIBERO-Plus fine-tuning gave OFT +11.8,** almost all from Camera, Noise and Background. TurboVLA's
    fine-tuning gave +23.5.
  - **vs released TurboVLA (45.5):** +23.2 overall, but TurboVLA is better on Robot (33.3 vs 23.9).
- **Standard LIBERO 4×10×50:** spatial 96.6, object 97.6, goal 95.6, libero_10 94.6 → **96.1** (OFT+ 96.6).
- **Latency:** 139.6 ms end to end, LLM 98.9 (≈ OFT+, as expected).
- **Test 1:** see `PLAN_test1_instruction_leak.md` (+3.0, mostly Camera).
