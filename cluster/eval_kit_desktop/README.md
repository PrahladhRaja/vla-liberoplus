# LIBERO-Plus evaluation kit

Runs a VLA policy on the [LIBERO-Plus](https://github.com/sylvestf/LIBERO-plus) robustness benchmark
(10,030 perturbed LIBERO tasks, one trial each) unattended, a few hours at a time. It was built for
evaluating TurboVLA and has a working TurboVLA adapter as an example.

What it gives you:

- **Useful results before the run finishes.** Tasks run round-robin over all 28 suite × perturbation
  cells, randomly within each cell, so after any number of nights every cell has a similar number of
  episodes. `summarize.py` turns that into a leaderboard-style table with 95% confidence intervals.
  Running to the end covers every task.
- **No lost work.** Each task's result is saved when it finishes; reruns skip finished tasks.
- **Robustness against LIBERO-Plus problems** (see "Known issues"): a watchdog for hung simulations,
  crash recovery, and a workaround for LIBERO-Plus's file-handle leak.
- **Nightly scheduling** on Windows/WSL (Task Scheduler), with a hard stop time.
- **One fixed episode protocol for every model.** Only `model_adapter.py` is model-specific.

## Files

| File | Purpose |
|---|---|
| `config.sh` | All paths and settings. **Edit first.** |
| `model_adapter.py` | Template for your model's adapter. **Fill in.** |
| `adapters/turbovla.py` | Complete example adapter (TurboVLA) |
| `eval_tasks.py` | Evaluator: episode protocol, results, deadline, restarts |
| `run_plan.sh` | Runs the evaluator with the hang watchdog and a stop time |
| `start_plan.sh` | Starts `run_plan.sh` detached (manual runs) |
| `stop.sh` | Stops a running evaluation after its current task |
| `nightly.sh` | Nightly driver used by the scheduled task |
| `schedule.sh` | Installs, pauses, resumes or removes the Windows scheduled task |
| `make_plan.py` | Writes `plan.tsv`, the evaluation order |
| `summarize.py` | Results table → `summary.txt` |
| `status.sh` | Is it running, progress, current results |
| `reference/` | TurboVLA's evaluation order and results, for comparison |

Generated while running: `plan.tsv`, `results.jsonl` (one line per task), `videos/`, `eval.log`,
`nightly.log`, `summary.txt`.

## Setup

These steps were worked out on WSL2 (Ubuntu) with an RTX 3080; adjust as needed.

1. **Conda env.** Use your model's env (or a clone of it) with Python 3.10. Install LIBERO-Plus's
   runtime dependencies without letting LIBERO's own `requirements.txt` downgrade your packages (it
   pins `transformers==4.21`, `numpy==1.22`, etc.):

   ```bash
   pip install robosuite==1.4.1 mujoco==3.1.6 bddl==1.0.1 gym==0.25.2 easydict cloudpickle h5py \
       "imageio[ffmpeg]" opencv-python matplotlib scipy pyyaml usd-core wand scikit-image
   ```

   `mujoco` must stay at 3.1.x: robosuite 1.4 fails on newer MuJoCo (`AssertionError` in
   `get_joint_qpos_addr`).

2. **ImageMagick** (LIBERO-Plus applies sensor noise through it; it is imported for every task):

   ```bash
   sudo apt install libmagickwand-dev libfontconfig1-dev
   ```

3. **LIBERO-Plus package.** A plain `pip install -e .` registers nothing importable (the top-level
   `libero/` folder has no `__init__.py`), so use compat mode. It installs as `libero`, so it cannot
   share an env with the original LIBERO.

   ```bash
   git clone https://github.com/sylvestf/LIBERO-plus.git && cd LIBERO-plus
   pip install --no-deps -e . --config-settings editable_mode=compat
   ```

4. **Assets** (6.4 GB zip, 9.5 GB extracted). The zip stores files under a long absolute-style
   prefix, so extract with the prefix stripped:

   ```bash
   hf download Sylvest/LIBERO-plus assets.zip --repo-type dataset --local-dir _download
   python - <<'EOF'
   import zipfile, os, shutil
   P = "inspire/hdd/project/embodied-multimodality/public/syfei/libero_new/release/dataset/LIBERO-plus-0/assets/"
   dst = os.path.realpath("libero/libero/assets")
   z = zipfile.ZipFile("_download/assets.zip")
   for info in z.infolist():
       rel = info.filename[len(P):] if info.filename.startswith(P) else ""
       if not rel: continue
       out = os.path.join(dst, rel)
       if info.is_dir(): os.makedirs(out, exist_ok=True); continue
       os.makedirs(os.path.dirname(out), exist_ok=True)
       with z.open(info) as s, open(out, "wb") as d: shutil.copyfileobj(s, d)
   EOF
   ```

   You should end up with `libero/libero/assets/{new_objects,scenes,textures,...}` (~449k files).

5. **LIBERO config.** LIBERO reads its paths from `$LIBERO_CONFIG_PATH/config.yaml` (default
   `~/.libero`). Give LIBERO-Plus its own config dir and bind it to the env, so it never mixes with an
   original LIBERO install:

   ```bash
   R=$HOME/LIBERO-plus/libero/libero; mkdir -p ~/.libero-plus
   printf "assets: $R/assets\nbddl_files: $R/bddl_files\nbenchmark_root: $R\ndatasets: $R/../datasets\ninit_states: $R/init_files\n" > ~/.libero-plus/config.yaml
   conda env config vars set LIBERO_CONFIG_PATH=$HOME/.libero-plus   # then re-activate the env
   ```

   If you also use original LIBERO in another env, set `LIBERO_CONFIG_PATH=$HOME/.libero` there too:
   otherwise switching straight from one env to the other can leave the wrong value set.

6. **Check:**

   ```bash
   python -c "from libero.libero import benchmark; print(benchmark.get_benchmark_dict()['libero_spatial']().n_tasks)"   # 2402
   ```

## Running

1. **Edit `config.sh`**: `PY`, `LIBERO_PLUS_ROOT`, `LIBERO_CONFIG_PATH`, `ADAPTER`, `TASK_NAME`, and
   the rendering variables for your machine.

2. **Write your adapter** in `model_adapter.py` (three members: `image_size`, `reset()`,
   `predict(obs, instruction)` returning the next actions). The docstring describes the exact episode
   protocol and the action convention; `adapters/turbovla.py` is a working example. Match your model's
   own LIBERO evaluation settings (image rotation, resolution, action un-normalization, gripper sign,
   chunk length).

3. **Choose the evaluation order:**
   - `python make_plan.py`: a fresh random order over all 10,030 tasks. Simplest; compare with
     other models per category.
   - `cp reference/paired_plan.tsv plan.tsv`: TurboVLA's exact order, for task-by-task comparison
     with `reference/turbovla_evaluated_tasks.csv`. It starts with LIBERO-Spatial tasks 0–1729 (five
     Spatial categories run in full, ~12 h), which TurboVLA ran first; those cells are counted exactly,
     and the table shows "-" for them until they are complete.

   Don't change `plan.tsv` once results exist.

4. **Smoke test** a few tasks (stops 15 minutes from now):

   ```bash
   ./run_plan.sh "$(date -d '+15 min' +%H:%M)"
   ./status.sh
   ```

   Check `eval.log` and a few videos in `videos/` (e.g. that the arm moves sensibly and successes are
   real). Results from the smoke test are kept.

5. **Schedule it** (WSL): `./schedule.sh install`. Every night between `WINDOW_START` and `WINDOW_END`
   it continues where it stopped. You must stay logged in to Windows (locking is fine); a sign-out or
   restart (e.g. Windows Update) stops it. `./schedule.sh status | test | remove`.
   On native Linux, use cron or a systemd timer to run `nightly.sh` at `WINDOW_START` instead.

   For extra runs outside the window: `./start_plan.sh 18:00` (runs detached until 18:00).

6. **Pause or stop:**
   - `./schedule.sh pause` / `./schedule.sh resume`: turn the nightly runs off and on (e.g. while you
     need the GPU at night). Pausing doesn't end a run already in progress.
   - `./stop.sh`: end a run in progress cleanly; it finishes the current task (up to ~2–3 min) first.
   - Nothing is lost either way; the next run continues where the evaluation stopped.

7. **Monitor:** `./status.sh` any time (it also shows whether the schedule is paused). Logs: `nightly.log` (per night), `eval.log` (evaluator),
   `manual.log` (`start_plan.sh`).

## Results

`summarize.py` (also run by `status.sh` and after each night) prints:

- success rate per suite × category, plus category and suite totals and the overall LIBERO-Plus score,
  each weighted by task count as on the LIBERO-Plus leaderboard. Unfinished cells are estimated from
  their random sample, with a 95% interval ("±"); values without "±" are exact.
- episodes evaluated per cell, and success by difficulty level (indicative only).

`results.jsonl` has one line per task: `{"suite", "task_id", "success", "seconds", "time"}`, or
`"hung": true` for a hang/crash. `task_id` is the 0-based index into the suite's LIBERO-Plus task
list (`libero_suite_task_map.py`), i.e. `id - 1` in `task_classification.json`.

Throughput for TurboVLA (RTX 3080, WSL): ~25–35 s per task including environment creation, i.e.
~850–900 tasks per 8-hour night. Ten nights or so cover everything; ~100 episodes per cell (enough for
about ±9 points per cell and ±2–3 overall) takes about three nights.

## Known issues

- **File-handle leak (LIBERO-Plus).** Each Objects Layout task leaks 3,000–4,000 open asset files
  (others ~100). Processes started by Windows Task Scheduler have a 10,240 limit, so within a few
  Layout tasks assets fail to load ("resource not found via provider or OS filesystem", although the
  file exists), writes fail ("Too many open files") and simulations hang. `run_plan.sh` raises the
  limit and `eval_tasks.py` restarts itself before it builds up. Stock evaluation scripts that run many
  tasks in one process will hit this.
- **Hangs.** If no task finishes for `STALL_MIN` minutes the evaluator is killed and restarted; the task
  is retried once, then skipped and reported in the summary. With the leak handled, TurboVLA saw none in
  two nights.
- **Instructions carry file-name suffixes.** LIBERO-Plus builds `task.language` from the task file
  name, so outside the Language category the instruction looks like "... place it on the plate
  view 0 0 100 2 352 initstate 0" (or "table 1", "noise 3", "add 10", "light 1"). The env's
  `language_instruction` is clean, but standard LIBERO evaluation code (OpenVLA-OFT,
  TurboVLA) passes `task.language`, and so does this kit. Keep this the same across models you compare;
  it can matter for text encoders with short context limits (TurboVLA's 21-token BERT input truncates
  ~4,600 of the 10,030 instructions).
- **Missing difficulty levels.** 121 LIBERO-Goal Light Conditions tasks have no level in
  `task_classification.json`; they show as "L?".
- **Rendering on WSL.** EGL renders on the CPU (llvmpipe) unless `GALLIUM_DRIVER=d3d12`; with it, Mesa
  picks a GPU through Direct3D 12 (`MESA_D3D12_DEFAULT_ADAPTER_NAME` selects which). Pixels differ
  slightly from other renderers, which can flip a few borderline episodes.

## Comparing with TurboVLA

`reference/turbovla_summary.txt` and `reference/turbovla_evaluated_tasks.csv` hold TurboVLA's results
as of 2026-10-07 (4,295 tasks: Spatial 0–1729 in full, then 2,565 in `paired_plan.tsv` order).
TurboVLA settings: released `turbovla_libero.pth` checkpoint, bf16, 12-step chunks, seed 7, initial
state 0 of each task.
