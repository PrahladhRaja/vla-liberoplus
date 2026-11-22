# Plan: add SmolVLA to the speed/quality comparison

**Status:** plan, 2026-11-10. Nothing run. Depends on the teammates' full 10,030-task SmolVLA runs.
**Goal:** one speed/quality plot and one paired results table covering every model we have:
- OpenVLA-OFT (7.5B): LIBERO-trained OFT and OFT+;
- TurboVLA (216M): released and fine-tuned;
- SmolVLA (450M): `lerobot/smolvla_libero` base, and the teammates' fine-tuned version(s). Use the 450M
  `lerobot/smolvla_libero`, not the older ~605M `HuggingFaceVLA/smolvla_libero`.
Point: compare the small VLAs with a large one on the same benchmark, GPU and latency definitions.

## 1. What already exists (no new runs needed)
| Model | LIBERO-Plus (all 10,030, Turing, same plan) | Env seed | Standard LIBERO | A30 latency (same definitions) |
|---|---|---|---|---|
| OpenVLA-OFT / OFT+ | 68.7 / 80.5 | 0 | 96.1 / 96.6 | 139.6 / 143.3 ms per 8-action chunk |
| TurboVLA released / fine-tuned | 45.5 / 68.9 | 7 | 93.8 / 96.5 | 30.7 ms per 12-action chunk (fine-tuned; same arch as released) |
| TurboVLA fine-tuned, clean instructions | ≈ 82.1 (test 1 stage B) | 7 | — | same |
| OFT+, clean instructions | 80.5 (test 1 gap-fill; +0.1 on the affected tasks) | 0 | — | same |

All of these used our eval kit (`eval_tasks.py`): first initial state, 10 settling steps, max steps
220/280/300/520 (spatial/object/goal/10), one trial per task, official instructions, the LIBERO-Plus container
with MuJoCo 3.2.0.

## 2. What we need from the SmolVLA work (no GPU)
1. **Per-task results for both arms on all 10,030 tasks:** suite, task_id, success, and error/skip flags. Ideally
   in our `results.jsonl` format or a CSV we can convert.
2. **Their exact evaluation protocol on Turing, to fill the compatibility table below.**
3. **Their Turing Python environment** (container or venv path) that loads SmolVLA, for the latency benchmark.
4. **Standard LIBERO numbers** for both arms, if measured (and with what trials per task).

## 3. Compatibility check (decides how the comparison may be reported)
| Setting | Ours | SmolVLA on Turing (to confirm) | Note |
|---|---|---|---|
| Task set / IDs | LIBERO-Plus suite + task_id, 10,030 | **?** | must match exactly |
| Initial state | `initial_states[0]` | **?** | |
| Settling steps | 10 | **?** | |
| Env seed | 7 (TurboVLA), 0 (OFT) | **?** | |
| Max steps per suite | 220 / 280 / 300 / 520 | **?** | a longer horizon inflates success |
| Actions executed per query | 8 (OFT), 12 (TurboVLA) | **?** | model-specific; fine, but record it |
| Instruction | official `task.language` (leaked IDs) | **?** | must be official for the main table |
| Simulator stack | LIBERO-Plus container, MuJoCo 3.2.0, robosuite 1.4.1 | **?** | MuJoCo 3.1.x vs 3.2.0 changes episodes chaotically (86.7 % per-task agreement seen before) |
| Image size / rotation | 256 px, rotated 180° per model's training | **?** | model-specific |

**Outcome grades:**
- **A, paired:** everything above matches except model-specific settings. SmolVLA joins the paired McNemar tables
  directly, exactly with TurboVLA (same seed) and with OFT under the seed caveat.
- **B, aggregate only:** the step limits, instructions or simulator stack differ. Report SmolVLA's rates as a
  separate-protocol reference point on the plot, with no per-task tests against our models.
- **Upgrading B to A:** run SmolVLA through our kit. That means a `adapters/smolvla.py` in their environment
  (LeRobot `SmolVLAPolicy`), plus a full run of about 12–15 GPU-h per arm. Only
  worth it if the teammates agree and the comparison matters for the report.

## 4. Latency benchmark (≈ 0.5 GPU-h including setup; one short job)
- **New script `smolvla_latency.py`**, mirroring `cluster/oft_container/turbovla_latency.py`:
  - batch 1, OFT's fixed LIBERO observation resized to 256 px with its 8-D state and instruction;
  - 50 warm-up + 300 timed queries;
  - the same settings the success rates were measured with (precision, flow steps).
- **Reports:**
  - end to end per query (one 50-action chunk) and model-only time;
  - **per executed action** (query time ÷ actions executed per query);
  - parameters and peak GPU memory.
- **Run it in their environment** on an A30 (`academic`), with the job script shown for approval first. Both
  arms share the same architecture, so one measurement covers both.

## 5. Analysis and outputs
- **Plot:**
  - x axis: A30 latency per executed action (log scale);
  - y axis: LIBERO-Plus success;
  - one point per model;
  - a second marker for clean-instruction results where we have them (TurboVLA and OFT+ from test 1 stage B).
- **Table:** per-category and per-suite LIBERO-Plus, standard LIBERO, latency per query and per action,
  parameters and memory.
- **Paired tests (grade A only):** SmolVLA vs TurboVLA (same seed), SmolVLA base vs fine-tuned, SmolVLA vs OFT+
  (seed caveat).
- **Check per-suite results**, not just the overall rate: a collapse in one suite can hide behind a good average.
- **Where results go:** `docs/findings/RESULTS.md` and a short joint table the whole team can
  reuse.

## 6. OpenVLA-OFT in this comparison
- **Include them: yes, at no cost.** They already have full-benchmark results on the same plan and A30 latency
  with the same definitions. They anchor the top of the quality axis.
- **Re-evaluate them with env seed 7 to remove the seed caveat: not by default.**
  - **Cost:** ≈ 11–13 GPU-h per model.
  - **What the seed changes:** it only adds noise to per-task pairing; it doesn't bias aggregate rates. Our
    same-seed reruns flip 1.5–4 % of tasks.
  - **When the caveat matters:** only for close comparisons. The OFT-vs-small-model gaps are 12+ pts (80 vs 69 vs
    ~30), except TurboVLA-clean vs OFT+-clean (about 1 pt).
- **Cheap alternative (≈ 0.7 GPU-h):** rerun 500 tasks of OFT+ with `ENV_SEED=7` and compare with its seed-0 run. That
  measures the seed's actual effect (flip rate and net shift), so the caveat can be stated with a number instead of
  hand-waving. Recommended if any comparison in the report relies on OFT-vs-seed-7 pairing. **Done 2026-11-21** (`experiments/robustness/gapfill_oftplus.sh`, `lp_seed7_oftplus`): 81.4 → 82.6 (+1.2, 13 / 19
  flips, p ≈ 0.38). The seed adds per-task noise but no significant shift.

## 7. Cost and order
1. **Data and protocol request** to the teammates. Now; no GPU.
2. **Compatibility grade** (A/B) from their answers.
3. **SmolVLA latency job:** ≈ 0.5 GPU-h, once their environment path is known.
4. **Optional:** the OFT+ seed-7 check (≈ 0.7 GPU-h). Done 2026-11-21: no significant effect.
5. **Optional:** SmolVLA through our kit (≈ 12–15 GPU-h per arm), only if grade B and the comparison matters.

Steps 1–3 can finish within a day of the team's runs completing. The core cost is ≈ 0.5 GPU-h plus the data.

## 8. Risks
- **The full runs may still be incomplete.**
- **The protocol may differ in ways that block pairing** (step limits, instructions, simulator) → grade B.
- **SmolVLA's executed-actions-per-query setting** changes its effective control rate;
  per-action latency must use the setting its success rates were measured with.
