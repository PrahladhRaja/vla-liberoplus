# Test 1: how much do leaked perturbation IDs in the instruction cost each model?

**Status:** done for TurboVLA (fine-tuned and released) and the original OpenVLA-OFT (2026-11-11). OpenVLA-OFT+
gap-fill runs submitted 2026-11-21 (`PENDING-OFTPLUS`). Planned 2026-11-09; separate from test 2
(`PLAN_test2_deblur_frontend.md`).

**Models:**
- TurboVLA fine-tuned on LIBERO-Plus;
- released TurboVLA;
- OpenVLA-OFT+ (released, LIBERO-Plus-trained);
- original LIBERO-trained OpenVLA-OFT.

**Origin:** a teammate's observation with SmolVLA, and LIBERO-Plus GitHub issue #64.

## 1. The problem (verified 2026-11-09 against the LIBERO-Plus checkout at `4976dc3`)
- **Where it comes from:** LIBERO-Plus builds `task.language` from the variant's bddl **filename**
  (`benchmark/__init__.py`, `grab_language_from_filename`).
- **Who passes it on:** our eval kit gives `task.language` to every model (`eval_tasks.py`), as does the official
  protocol.
- **Result:** for every non-Language variant, the perturbation ID ends up in the instruction.

| Category (tasks) | What the model is told (example: spatial task 1) |
|---|---|
| Background (1,076) | `… and place it on the plate table 1` |
| Light (1,142) | `… place it on the plate light 1` |
| Layout (1,525) | `… place it on the plate add 10` |
| Camera (1,599) | `… place it on the plate view 0 0 100 2 352 initstate 0` |
| Robot init (1,550) | `… place it on the plate view 0 0 100 0 0 initstate 1` |
| Sensor Noise (1,601) | `… place it on the plate view 0 0 100 0 0 initstate 0 noise 3` |
| Language (1,537) | an intentionally rewritten instruction read from the bddl: **this is the perturbation; left unchanged** |

**8,493 of 10,030 tasks (85 %) are affected,** in 6 of 7 categories. That's wider than issue #64 reports, which omits
Robot.

**The clean instruction** is the parent task's filename-derived instruction:
- one of the 40 original LIBERO instructions, the same strings as the training data;
- every affected variant maps to exactly one parent by longest prefix match (checked for all 8,493);
- **not** the bddl's declared `(:language …)`, which uses internal object names ("Pick the akita black bowl …").

**How far the codes reach into each model:**
- **TurboVLA:** its BERT text encoder pads and truncates to **21 tokens** (`text_padding_length=21`). Clean
  instructions are 6–21 tokens, so the suffix is partly cut off.
  - Checked with its own tokenizer: **7,820 of 8,493** affected tasks still differ within the first 21 tokens.
  - That's all of libero_object and libero_goal (short instructions), 1,584/2,012 of spatial and 1,891/2,136 of
    libero_10.
- **OpenVLA-OFT / OFT+:** get the whole suffix in the prompt, with no truncation. The LIBERO-Plus paper finds OFT
  largely ignores language, so a small effect is expected; that expectation is what we test.

**Why it matters:** TurboVLA trails OFT+ most in leaked categories: Camera −22.8, Noise −21.8, Background −15.6 pts.
If part of that is prompt corruption rather than vision, the TurboVLA-vs-OFT+ comparison changes.

## 2. Hypotheses (fixed before running)
- **H1:** TurboVLA succeeds more often with clean instructions on affected tasks; expected ≥ 3 pts, McNemar p < 0.05.
- **H2:** OpenVLA-OFT is insensitive: |Δ| < 1 pt, not significant.
- **Reporting:** official-protocol scores remain the reported results. Clean-instruction numbers are a labelled
  diagnostic.

## 3. Implementation
1. **Eval kit:** `CLEAN_INSTRUCTION=0|1` in `config.sh`, default 0.
   - With 1, `eval_tasks.py` replaces the instruction of non-`_language_` variants with the parent's filename-derived
     instruction (`cluster/eval_kit/clean_instruction.py`).
   - Both strings are logged per task in `results.jsonl` (`instruction_fed`, `instruction_official`).
   - Nothing else changes: same seed, initial state, max steps and episode loop.
   - Applied on Turing with `experiments/robustness/t1_kit_patch.py`.
2. **Mapping check:** every affected task maps to a parent; exactly 40 distinct clean strings; Language rows
   unchanged; the clean strings equal the original LIBERO instructions.
   - On Turing's checkout: 8,493 changed, 1,537 unchanged, 40 distinct clean instructions.
3. **Plans:** the first N affected rows of the baseline plan, in plan order. The plan is round-robin over all 28
   suite × category cells, so a prefix stays balanced.
4. **Run directories:** made by the existing setup scripts; only `CLEAN_INSTRUCTION=1` and the plan differ.
   - TurboVLA: seed 7, as its official run.
   - OFT models: `setup_oft_eval.sh` + `eval_job_oft.sbatch`, `ENV_SEED=0`, as their official runs.

## 4. Controls
- **Pairing:** each clean run is paired task by task with **the same model's existing official run** (same seed,
  same initial state). The instruction is the only change.
- **Rerun noise:** the same task with the same seed is not guaranteed to reproduce on GPU.
  - So each model also reruns **200 affected tasks with official instructions** (`CLEAN_INSTRUCTION=0`).
  - Their disagreement with the original run is the rerun-noise floor.
  - A clean-instruction effect only counts if its discordance is clearly asymmetric beyond this floor.

## 5. Stages
| Stage | What | Tasks per model |
|---|---|---|
| A: screen | first 1,000 affected rows, clean instructions; + 200-task official rerun | 1,200 |
| B: full | all 8,493 affected rows | 8,493 |

| Model | Stage A | Stage B | Scripts |
|---|---|---|---|
| TurboVLA fine-tuned | ✓ | ✓ | `t1_stageA.sh`, `t1_stageB.sh` |
| TurboVLA released | ✓ | — | `t1_released.sh` |
| OpenVLA-OFT+ | ✓ (2026-11-21) | ✓ (2026-11-21) | `gapfill_oftplus.sh`, `gapfill_oftplus_B.sh`, `gapfill_analysis.sh` |
| OpenVLA-OFT (LIBERO-trained) | ✓ | — | `cluster/oft_container/oftL_submit.sh` |

## 6. Caveats
- **"Clean" is our reconstruction** (the parent's training-time instruction), not an official LIBERO-Plus protocol.
  Say so wherever it appears.
- **Robot-init variants:** cleaning also removes `view 0 0 100 0 0`, which encodes the default camera. That's fine:
  it carries no task information either.
- **TurboVLA truncation:** for 673 affected tasks the suffix never reaches TurboVLA.

## 7. Results
Comparisons: `results/robustness/t1_analysis.txt` (regenerate with `experiments/robustness/t1_analysis.sh`) and, for
OFT+, `gapfill_analysis.txt`.

**Stage A, first 1,000 affected rows** (2026-11-10/11; each run paired with its model's official run):

| Model | Official → clean | Flips (official only / clean only) | McNemar | Same-seed rerun control (200 tasks) |
|---|---|---|---|---|
| TurboVLA fine-tuned | 70.9 → **86.8 (+15.9)** | 26 / 185 | p ≈ 1e-27 | 72.5 → 72.5 (4 / 4 flips) |
| TurboVLA released | 44.2 → 59.3 (+15.1) | 49 / 200 | p ≈ 2e-21 | 3 / 4 flips |
| OpenVLA-OFT (LIBERO-trained) | 67.1 → 70.1 (+3.0) | 48 / 78 | p ≈ 0.01 | 2 / 2 flips |
| OpenVLA-OFT+ | `PENDING-OFTPLUS` | `PENDING-OFTPLUS` | `PENDING-OFTPLUS` | 83.0 → 83.0 (3 / 3 flips) |

- **Fine-tuned TurboVLA by category** (all significant): Camera +18.5, Robot +19.2, Light +11.4, Background +11.4,
  Noise +22.8, Layout +12.0.
- **Fine-tuned TurboVLA by suite:** spatial +15.7, object +5.2, goal +38.6, libero_10 +4.4.
- **Original OpenVLA-OFT:** the gain is concentrated in Camera, 51.2 → 64.3 (+13.1, p ≈ 9e-4).
- **Released vs fine-tuned TurboVLA:** the released model pays the same leak cost as the fine-tuned one on the same
  tasks (+15.1 vs +15.9), so fine-tuning did not teach TurboVLA to ignore the IDs. The fine-tuning gain is unchanged
  by the leak: +26.7 official vs +27.5 clean on these 1,000 tasks.

**Stage B, all 8,493 affected tasks:**

| Model | Affected tasks, official → clean | Flips | p | Full-benchmark estimate* |
|---|---|---|---|---|
| TurboVLA fine-tuned | 68.2 → **83.7 (+15.6)** | 233 / 1,554 | 5e-214 | 68.9 → **82.1** |
| OpenVLA-OFT+ | `PENDING-OFTPLUS` | | | 80.5 → `PENDING-OFTPLUS` |

\* Clean affected results + the unchanged Language category.

- **Fine-tuned TurboVLA by category:** Camera +19.7, Robot +13.5, Light +10.2, Background +14.3, Noise +23.2,
  Layout +10.1 (all p < 1e-19).
- **By suite:** spatial +12.9, object +6.2, goal +36.8, libero_10 +5.9.
- **Fine-tuned TurboVLA clean vs OFT+ clean:** `PENDING-OFTPLUS`.

**Verdicts:**
- **H1 (TurboVLA gains):** confirmed at full scale.
- **H2 (OFT insensitive):** fails for the original LIBERO-trained OFT (+3.0, mostly Camera). OFT+: `PENDING-OFTPLUS`.
