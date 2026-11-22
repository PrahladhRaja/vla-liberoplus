# Where everything lives

Paths without a prefix are in this repo.
- **Turing:** `~` = `/home/<user>`, scratch = `/scratch/<user>`.
  - Scratch can be purged after a stretch of non-use.
  - `/archive/<user>` can only be reached from the login node.

Each eval-kit run in `results/` keeps only these files:
- `plan.tsv`: task order;
- `results*.jsonl`: one line per task, with suite, task_id, success, seconds, and `instruction_fed` /
  `instruction_official` for test-1 runs;
- `summary.txt`;
- `config.sh`.

Eval logs, server logs and videos stay on Turing.

## 1. Per-task results
| Run | What | In this repo | Turing run dir | Job IDs |
|---|---|---|---|---|
| TurboVLA released, LIBERO-Plus | 10,030 tasks, 45.5 % | `results/turbovla/lp_eval_full/` | `~/lp_eval_full/` | 2392416/7 (+ s0 rerun of 6 tasks) |
| TurboVLA released, desktop | 10,030 tasks, 44.6 % (different simulator build) | `cluster/eval_kit_desktop/reference/` | — | desktop |
| TurboVLA fine-tuned, LIBERO-Plus | 10,030 tasks, 68.9 % | `results/turbovla/lp_eval_ft/` | `~/lp_eval_ft/` | 2398127/8 |
| TurboVLA step 10k checkpoint | 3,011 tasks | `results/turbovla/lp_eval_ck10000/` | `~/lp_eval_ck10000/` | — |
| TurboVLA standard LIBERO (released, fine-tuned) | 2 × 2,000 episodes | `results/turbovla/libero_std/` | `~/libero_std/` | — |
| TurboVLA released, standard LIBERO, desktop | 2,000 episodes | `results/desktop/libero_std_released/` | — | desktop |
| TurboVLA 29-task Turing checks | 1 vs 8 workers | `results/turbovla/test28/` | — | 2390685, 2390779 |
| TurboVLA fine-tuning run | report, smoke test, data stats, job IDs | `results/turbovla/finetune_run/` | `~/finetune_lp/` | s0–s7, `jobs.env` |
| OFT+ LIBERO-Plus | 10,030 tasks, 80.5 % | `results/oft/lp_eval_oftplus/` | `~/lp_eval_oftplus/` | 2430419/20 (+ 2437087) |
| OFT+ standard LIBERO | 2,000 episodes (eval output) | `results/oft/libero_std/oftplus/` | `~/oft_results/libero_std/oftplus/` | 2430421 |
| OpenVLA-OFT LIBERO-Plus | 10,030 tasks, 68.7 %, 4 per-suite runs | `results/oft/lp_eval_oftL_<suite>/` (merge: `cluster/oft_container/oftL_merge.sh`) | `~/lp_eval_oftL_<suite>/` | 2502787–90 |
| OpenVLA-OFT standard LIBERO + latency | 2,000 episodes; bench JSON | `results/oft/libero_std/oft_libero/`, `results/oft/oft_libero_latency_bench.json` | `/scratch/<user>/oft/oftL/eval/`, `~/oft_results/oftL/` | 2502786 |
| Test 1: TurboVLA fine-tuned, clean (+ rerun) | 8,493 affected (+ 200) | `results/robustness/lp_t1_turbovla_{clean,rerun}/` | `~/lp_t1_turbovla_{clean,rerun}/` | 2499712, 2499715, 2502525/6 |
| Test 1: TurboVLA released, clean (+ rerun) | 1,000 (+ 200) | `results/robustness/lp_t1_turbovlaR_{clean,rerun}/` | same names | 2502776/7 |
| Test 1: OpenVLA-OFT, clean (+ rerun) | 1,000 (+ 200), merged | `results/robustness/lp_t1_oftL_{clean,rerun}/` | same names (+ per-suite dirs) | 2502791–98 |
| Test 1: OFT+, clean A + B (+ rerun) | 1,000 + 7,493 (+ 200) | `results/robustness/lp_t1_oftplus_{clean,cleanB,rerun}/` (`gapfill_analysis.sh` merges A + B) | `~/lp_t1_oftplus_clean`, `~/lp_t1_oftplus_cleanB`, `~/lp_t1_oftplus_rerun` | 2563982, 2564221/2, 2563983 |
| OFT+ env seed 7 check | 500 tasks | `results/robustness/lp_seed7_oftplus/` | `~/lp_seed7_oftplus` | 2563984 |
| Test 1 comparisons | paired tables | `results/robustness/t1_analysis.txt` | `~/robustness_tests/t1_analysis.txt` | — |
| OFT+ gap-fill comparisons | paired tables, full-benchmark clean estimates | `results/robustness/gapfill_analysis.txt` | `~/robustness_tests/gapfill_analysis.txt` | — |
| Job-ID lists | | `results/robustness/*.env`, `results/oft/oftL_jobs.env` | `~/robustness_tests/`, `~/oft_container/` | — |

## 2. Reports and notes
| File | Contents |
|---|---|
| `docs/findings/RESULTS.md` | every in-scope number with its source |
| `docs/findings/METHODS.md` | benchmarks, models, protocol, fine-tuning recipe, test 1 design, glossary |
| `docs/findings/GAPS.md` | caveats, open questions, unrun plans |
| `docs/findings/TIMELINE.md` | dated chronology |
| `docs/oft_reference.md` | OFT+/OFT setup, baselines and latency |
| `docs/plans/PLAN_*.md` | test 1 (instruction leak), test 2 (deblur front end, not run), original-OFT reference, SmolVLA comparison |
| `results/turbovla/reports/*.md` | TurboVLA reports: Turing vs desktop, released vs fine-tuned (summary + detailed), step 10k vs 17.5k, standard LIBERO |
| `docs/turing/` | Turing rules for agents (`AGENTS.md`), first-session checklist |
| `docs/data/*.csv` | headline numbers in long format and latency, for plotting |

## 3. Code: repo folder → where it runs on Turing
Scripts use fixed Turing locations, so copy each folder there before use.

| Repo folder | Turing location | What |
|---|---|---|
| `cluster/liberoplus_container/` | `~/liberoplus_container/` | Apptainer image + assets for LIBERO-Plus and TurboVLA, `lp-exec.sh`, `setup_code.sh` |
| `cluster/oft_container/` | `~/oft_container/` | OpenVLA-OFT image, downloads, `setup_oft_code.sh` (+ `patches/openvla-oft/*.patch` → `~/oft_container/patches/`), `setup_oft_eval.sh`, standard-LIBERO and original-OFT jobs, TurboVLA latency benchmark |
| `cluster/eval_kit/` | `~/turing_eval_kit/` | LIBERO-Plus eval kit: `eval_tasks.py`, adapters (TurboVLA, OpenVLA-OFT), `clean_instruction.py`, `summarize.py` |
| `cluster/eval_kit_desktop/` | (desktop) | the original desktop version of the kit |
| `cluster/finetune_lp/` | `~/finetune_lp/` | TurboVLA fine-tuning pipeline (s0–s7), `compare_evals.py`, `libero_std.sbatch` |
| `cluster/starter_kit/` | — | starter kit given to teammates (Turing docs omitted: https://docs.turing.wpi.edu/llms.txt) |
| `experiments/robustness/` | `~/robustness_tests/` | test 1 runs and analysis, OFT+ gap-fill runs, video reruns, `pick_video_tasks.py` |
| `experiments/analysis/` | (desktop or login node) | scripts that produced the TurboVLA reports |
| `patches/TurboVLA/` | applied by `cluster/liberoplus_container/setup_code.sh` | EMA-fallback fix for the released checkpoint |

## 4. Checkpoints and large data (Turing; not in the repo)
| Item | Path |
|---|---|
| Fine-tuned TurboVLA (evaluated) | `/scratch/<user>/finetune_lp/checkpoints/turbovla_step_17500.pth` (`final.pth` link); also steps 5k/10k/15k |
| Archived copies: checkpoints 5k/10k/15k/17.5k, video tars | `/archive/<user>/turbovla_liberoplus_2026-10/` (README.txt inside) |
| Released TurboVLA + DINOv3 + BERT | `/scratch/<user>/liberoplus/pretrained/` |
| OFT+ weights | `/scratch/<user>/ckpts/oftplus` |
| Original OFT weights | `/scratch/<user>/ckpts/oft_libero` |
| LIBERO-Plus training data | `/scratch/<user>/libero_plus_data/libero_mix/1.0.0` (78 GB) |
| Containers and assets | `/scratch/<user>/liberoplus/{liberoplus.sif,assets.sqfs}`, `/scratch/<user>/oft/openvla_oft.sif` |
| Videos | archive tars above; also a local copy on the project desktop |
