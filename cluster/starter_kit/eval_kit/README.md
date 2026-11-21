# LIBERO-Plus evaluation kit (Turing / SLURM)

Evaluates a VLA on the LIBERO-Plus benchmark (10,030 perturbed LIBERO tasks, one trial each) as SLURM jobs on
Turing, using the LIBERO-Plus container (`lp-exec.sh`). Derived from the desktop kit used for TurboVLA's full
LIBERO-Plus run; the episode protocol is unchanged, so results are comparable.

- **Results survive anything:** each task's result is appended to `results.jsonl` as it finishes; resubmitting
  continues where the last job stopped.
- **Useful partial results:** `plan.tsv` visits all 28 suite × category cells round-robin with random tasks, so
  `summarize.py` gives leaderboard-style estimates with 95% intervals at any point.
- **Robust:** hang watchdog (`STALL_MIN`), crash recovery (a task that fails twice is skipped and reported), clean
  stop before the job's time limit, `stop.sh` to end a running job after its current task.
- **One fixed protocol:** only `model_adapter.py` (or `adapters/<your model>.py`) is model-specific.

## Files

| File | Where it runs | Purpose |
|---|---|---|
| `config.sh` | everywhere | paths (`LP_EXEC`, LIBERO-Plus), adapter, seed, videos, watchdog |
| `eval_job.sbatch` | GPU job | starts 8 parallel workers (16 CPUs, 1 GPU) that run `run_plan.sh` until 10 min before the job's time limit (default `--time=47:00:00`) |
| `run_plan.sh` | inside the job | one worker: evaluator + watchdog; results to `results[.k].jsonl`, log to `eval[.k].log` |
| `kit-python` | inside the job | `lp-exec.sh python -u …` (the container's Python) |
| `eval_tasks.py` | container | the episode loop (same protocol as TurboVLA's LIBERO evaluator) |
| `model_adapter.py`, `adapters/turbovla.py` | container | your model's adapter (template) and a working example |
| `make_plan.py` | login node | writes `plan.tsv` (fixed random order; refuses to overwrite) |
| `summarize.py`, `status.sh`, `stop.sh` | login node | results table (`summary.txt`), progress, clean stop |
| `reference/` | – | TurboVLA's full LIBERO-Plus results + its evaluation order (`paired_plan.tsv`) for comparison |

## Use

```bash
cp -r eval_kit ~/my_eval && cd ~/my_eval
# edit config.sh: LP_EXEC (your lp-exec.sh), LP_PYTHONPATH (your code), ADAPTER
python3 make_plan.py                      # or: cp reference/paired_plan.tsv plan.tsv  (TurboVLA's exact order)
sbatch --time=00:45:00 eval_job.sbatch    # short first run; check eval.*.log, videos/, ./status.sh
# full run on both of your GPUs (academic max), one plan, 16 workers:
TOTAL_WORKERS=16 WORKER_OFFSET=0 sbatch eval_job.sbatch
TOTAL_WORKERS=16 WORKER_OFFSET=8 sbatch eval_job.sbatch
```
Resubmit (same commands) until `./status.sh` shows 10030/10030; finished tasks are skipped.

## Parallel workers (why and how many)

Episodes are mostly CPU-bound: MuJoCo physics, and for LIBERO-Plus "Sensor Noise" tasks a per-step image filter in
pure Python (the glass blur costs ~1.05 s per step on Turing's A30 nodes, ~0.5 s on a fast desktop). TurboVLA uses
~1 GB of the A30's 24 GB, so one process per GPU leaves the GPU idle. `eval_job.sbatch` therefore runs several
workers per job: worker k of N evaluates plan rows k, k+N, ..., each with its own results (`results.<k>.jsonl`),
progress file and log (`eval.<k>.log`); `summarize.py` / `status.sh` combine them.

Measured on Turing (TurboVLA, Oct 2026):
- A30 nodes have Intel Xeon Gold 6342 CPUs; a 16-CPU job gets **8 physical cores** (hyperthread pairs). One worker per
  physical core scales linearly (1, 4, 8 workers: same per-step time); 16 workers on 8 cores gain nothing.
- 8 workers x 2 CPUs on one A30: same outcomes on all 29 test tasks as 1 worker; per-task time x1.01 for Sensor
  Noise, x1.38 for the rest (GPU sharing); about **7.3x the throughput** of a single worker.
- Full LIBERO-Plus (10,030 tasks) for TurboVLA: ~71 worker-hours of episodes -> ~11 h on one 8-worker job; **5 h 20 min measured on two** (Oct 19, 16 workers).
- Thread caps (`OMP_NUM_THREADS` etc.) make no measurable difference on Turing; the job sets them anyway.
- Each worker needs ~3-4 GB RAM (`--mem=48G` for 8). Bigger models: fewer workers per GPU (`CPUS_PER_WORKER=4`)
  or check GPU memory with `nvidia-smi` in a short run.

## Episode protocol (fixed in `eval_tasks.py`)
One env per task (`OffScreenRenderEnv`, adapter's `image_size`, `env.seed(7)`), initial state 0, 10 settling
no-op steps, then up to the suite's step limit (spatial 220, object 280, goal 300, libero_10 520) executing each
returned action chunk open-loop; success = env reports done. Instructions are LIBERO-Plus's `task.language`
(which carries file-name suffixes outside the Language category; keep this identical across models you compare).
