# Results

Per-task results of every in-scope run. Each eval-kit run folder keeps four files:

| File | Contents |
|---|---|
| `results*.jsonl` | one JSON line per finished task: `suite`, `task_id`, `success` (bool), `seconds`, and for test-1 runs `instruction_fed` / `instruction_official`. Lines with `"hung": true` are watchdog records, not results. Multi-worker runs write one file per worker; concatenate them. |
| `plan.tsv` | task order: `order`, `suite`, `task_id`, `category`, `round` (header lines start with `#`) |
| `summary.txt` | success table by suite × category (from `cluster/eval_kit/summarize.py`), where present |
| `config.sh` | the run's kit settings: adapter, `SEED`, `ENV_SEED`, `CLEAN_INSTRUCTION`, … |

- **Pairing runs:** two runs are compared task by task on `(suite, task_id)`:
  `python3 cluster/finetune_lp/compare_evals.py <baseline dir> <new dir>`.
- **Category and difficulty labels** come from LIBERO-Plus's `task_classification.json`.

| Folder | Runs |
|---|---|
| `turbovla/` | released (`lp_eval_full`) and fine-tuned (`lp_eval_ft`) on LIBERO-Plus; step-10k checkpoint (`lp_eval_ck10000`, 3,011 tasks); standard LIBERO (`libero_std/`, one JSON per suite half); 29-task Turing checks (`test28/`); fine-tuning run report and data statistics (`finetune_run/`); written reports (`reports/`) |
| `oft/` | OpenVLA-OFT+ (`lp_eval_oftplus`), original OpenVLA-OFT per suite (`lp_eval_oftL_<suite>`, merge with `cluster/oft_container/oftL_merge.sh`), standard-LIBERO eval output (`libero_std/`), latency benchmark JSON |
| `robustness/` | test 1 (instruction leak): clean-instruction and same-seed rerun runs per model, `t1_analysis.txt`, job IDs; OFT+ gap-fill runs: clean instructions stage A (`lp_t1_oftplus_clean`) and B (`lp_t1_oftplus_cleanB`), rerun (`lp_t1_oftplus_rerun`), env seed 7 (`lp_seed7_oftplus`), `gapfill_analysis.txt`, `gapfill_jobs.env` |
| `desktop/` | released TurboVLA on standard LIBERO, run on the desktop (cross-check of the Turing numbers) |

The desktop LIBERO-Plus run of released TurboVLA is in `cluster/eval_kit_desktop/reference/`.
