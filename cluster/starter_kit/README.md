# Running VLAs on LIBERO / LIBERO-Plus on WPI Turing: starter kit

What we learned getting TurboVLA's LIBERO-Plus evaluation running on Turing (Oct 2026), packaged so you can do the
same with a different VLA. Everything here was tested on Turing A30 nodes; the only TurboVLA-specific piece is the
example package list.

## TL;DR

- Your course account may only be allowed on the **academic** partition (A30, 24 GB, ≤2 GPUs, 48 h). Check before
  writing job scripts (step 1 below). A first `srun --partition=quick` failed with "Invalid account or
  account/partition combination" for us.
- LIBERO needs offscreen OpenGL. The GPU nodes have NVIDIA's EGL driver but **no `libEGL.so.1`**, so rendering only
  works **inside an Apptainer container run with `--nv`** whose image provides libglvnd. This kit builds one.
- Turing builds containers **rootless** via the host's `fakeroot`, which needs **glibc ≥ 2.38 in the image**, so
  use an Ubuntu 24.04 base (22.04 bases fail with `GLIBC_2.38 not found`).
- **Use MuJoCo ≥ 3.2.0.** MuJoCo 3.1.x never closes mesh files; LIBERO-Plus "Objects Layout" scenes then hit the
  1,024 open-file limit of SLURM jobs and hang. 3.2.0 works with robosuite 1.4.1 and simulates identically
  (max qpos difference ~1e-8 after 300 random steps).
- Keep LIBERO-Plus's 449k asset files in **one squashfs file** mounted into the container (Turing's docs discourage
  extracting archives with huge file counts).
- Result: all 7 LIBERO-Plus perturbation categories render on an A30 at ~45 env steps/s (≈4× an RTX 3080 desktop).
- **Run several evaluation workers per GPU.** Episodes are CPU-bound and Turing's A30 nodes have slower cores than a
  desktop (Xeon Gold 6342: LIBERO-Plus's glass-blur noise filter takes ~1.05 s/step vs ~0.5 s on a Ryzen 7800X3D).
  A 16-CPU job = 8 physical cores; 8 workers per GPU gave ~7.3× throughput with identical outcomes.

## What's in the kit

| File | What it does |
|---|---|
| `AGENTS.md` | Turing's rules for AI coding agents (from Turing's docs); keep it next to your work; its connect line uses `gompei` as a placeholder for your WPI username |
| `turing_docs/` | Local copy of Turing's documentation (downloaded 2026-10-18). **Not included in the vla-liberoplus repo**; fetch it from https://docs.turing.wpi.edu/llms.txt |
| `container/liberoplus.def` | Image recipe: Ubuntu 24.04, libglvnd EGL + NVIDIA vendor file, Mesa (CPU fallback), ImageMagick 6 (LIBERO-Plus sensor noise), build tools, uv-managed Python 3.10 venv from `requirements.lock.txt` |
| `container/requirements.turbovla-example.txt` | Example pins (TurboVLA: torch 2.3.1+cu121, mujoco 3.2.0, robosuite 1.4.1, TF 2.21, …) |
| `container/build_image.sbatch` | CPU job: `apptainer build --fakeroot` → `/scratch/$USER/liberoplus/liberoplus.sif` (~3.5 min, 4.2 GB for TurboVLA) |
| `container/make_assets.sbatch` + `zip2tar.py` | CPU job: download LIBERO-Plus `assets.zip`, stream zip → tar → `mksquashfs` → `assets.sqfs` (~3 min, 3.6 GB, nothing extracted) |
| `container/setup_libero_plus.sh` | Login node: clone LIBERO-Plus (pinned commit), create the assets mount point, write `~/.libero-plus/config.yaml` |
| `container/lp-exec.sh` | Run anything in the container: `--nv`, assets mounted, `PYTHONPATH` = LIBERO-Plus + your code (`LP_PYTHONPATH`) |
| `container/test_container.sbatch` + `lp_scene_test.py` | 30-min GPU job: one real LIBERO-Plus scene per category; prints steps/s, pixel check, open files |
| `container/noise_bench.sbatch` + `noise_bench.py` | CPU job: times LIBERO-Plus's sensor-noise filters (thread settings, parallel scaling) on a Turing node |
| `container/download_hf_models.sbatch` | CPU job: download Hugging Face models into `/scratch/$USER/models/` (gated ones after `hf auth login`) |
| `eval_kit/` | SLURM evaluation kit: plan, evaluator with watchdog, `eval_job.sbatch`, status/summary; write your `model_adapter.py` (see `eval_kit/README.md`) |

## Steps

1. **Read Turing's docs and set up your agent rules.** Docs: https://docs.turing.wpi.edu/llms.txt (local copy in
   `turing_docs/`). If you use a coding agent, keep `AGENTS.md` next to your work; it tells the agent to connect with
   `ssh gompei@turing.wpi.edu`, with `gompei` replaced by your WPI username.
2. **Check what your account can use** (login node, read-only):
   ```bash
   sacctmgr show assoc user=$USER format=Account,Partition,QOS -p
   sacctmgr show account <your-account> withassoc format=Account,ParentName -p   # parent "courses" => academic only
   scontrol show partition academic | grep -E "Allow|Deny"
   ```
   Then set `--partition` (and `--account` if you have several) in the three `.sbatch` files.
3. **Make your requirements file.** In your working VLA env on your own machine (Python 3.10):
   `pip freeze | grep -v "^-e " > requirements.lock.txt`, then make sure it has `mujoco==3.2.0` (or newer) and
   `robosuite==1.4.1`. If you need packages from the PyTorch index, keep the `--extra-index-url` in
   `liberoplus.def`. Before using cluster time, check it resolves with `uv pip install --dry-run …` (see "Lessons").
4. **Copy the kit to Turing** (from your machine; Turing's docs use `scp` into your home directory):
   `scp -r turing_vla_starter <user>@turing.wpi.edu:~/`
5. **On the login node:** `cd ~/turing_vla_starter/container && bash setup_libero_plus.sh`, and clone your VLA's
   code into `~/turing-vla/` too.
6. **Build image + assets + test as a job chain** (stops if a step fails; cancel leftovers with `scancel`):
   ```bash
   B=$(sbatch --parsable build_image.sbatch)
   A=$(sbatch --parsable --dependency=afterok:$B make_assets.sbatch)
   sbatch --dependency=afterok:$A test_container.sbatch
   ```
   The test log should show 7 category lines at tens of steps/s and a small "open file handles" count.
7. **Model weights:** log in to Hugging Face once if any model is gated (login node; you paste the token, created at
   https://huggingface.co/settings/tokens, type Read):
   `module load apptainer; apptainer exec -B /scratch /scratch/$USER/liberoplus/liberoplus.sif hf auth login`,
   then `sbatch container/download_hf_models.sbatch <repo> …` (weights land in `/scratch/$USER/models/`).
8. **Evaluate:** copy `eval_kit/`, write your adapter (`model_adapter.py`; TurboVLA example in `adapters/`), set
   `LP_PYTHONPATH` and `ADAPTER` in `config.sh`, then `python3 make_plan.py` and `sbatch --time=00:45:00
   eval_job.sbatch` for a first look; full runs are 47-h jobs you resubmit until done.
   `eval_job.sbatch` runs **8 parallel workers per GPU** (16 CPUs). Measured for TurboVLA: same outcomes as a
   single worker, ~7.3× its throughput; a full 10,030-task LIBERO-Plus run takes **~11 h on one job; 5 h 20 min measured on two**
   (`TOTAL_WORKERS=16 WORKER_OFFSET=0|8`, see `eval_kit/README.md`).

## Lessons (each one cost a failed job; the kit already handles them)

| Symptom | Cause | Fix in kit |
|---|---|---|
| `Invalid account or account/partition combination` | Course accounts are denied on short/long/quick | Check step 2; use `--partition=academic` |
| `sinteractive --help` starts an interactive prompt | It's a Turing wrapper that asks questions, then runs `srun … --pty bash` | Use `srun -N 1 -n 4 --mem=16G --time=00:30:00 --partition=academic --gres=gpu:1 --pty bash` directly |
| MuJoCo EGL fails on the node (`eglQueryString` on `None`) | No libglvnd `libEGL.so.1` on GPU nodes | Run in the container with `--nv` |
| `GLIBC_2.38 not found … libfakeroot.so` during build | Rootless build injects the host's fakeroot | Ubuntu 24.04 base |
| apt fails in rootless build | apt can't switch to the `_apt` user | `APT::Sandbox::User "root"` (in the recipe) |
| `cannot cache function … no locator available` (robosuite import) | numba caches next to package files; image is read-only | `NUMBA_CACHE_DIR=/tmp/…` (in the recipe) |
| `Read-only file system: '/scratch'` inside container | `/scratch` isn't mounted by default | `-B /scratch` on every `apptainer exec` |
| `mksquashfs: compressor zstd not supported` (would have been) | The cluster's `squashfs` module is gzip-only | `-comp gzip` |
| Scene XML "No such file" under `LIBERO-plus/libero/libero/assets/` | LIBERO's arena loader ignores the config's `assets:` path | Mount `assets.sqfs` at the package-relative `assets/` |
| Scenes render at CPU speed, `nvidia-smi` shows 0% | Ubuntu 24.04's Mesa offers a software EGL device first | `__EGL_VENDOR_LIBRARY_FILENAMES=…/10_nvidia.json` (in `lp-exec.sh`) |
| "Objects Layout" scene hangs at 100% CPU, exactly 1,024 open files | MuJoCo 3.1.x leaks mesh file handles | MuJoCo ≥ 3.2.0 |
| Job log shows nothing for a long time | Python buffers stdout when writing to a file | `python -u` |
| Sensor Noise tasks 2× slower than on a desktop | Per-step glass/zoom/motion blur in single-threaded Python/ImageMagick; Turing's cores are ~2× slower per thread (thread caps don't help) | Parallel workers: 1 per physical core (`eval_job.sbatch` default 8 per 16 CPUs) |
| `ImportError: Cannot initialize a EGL device display` in a CPU-only job | MuJoCo initializes EGL on import; without a GPU the NVIDIA vendor has no device | `LP_EGL_VENDOR=/usr/share/glvnd/egl_vendor.d/50_mesa.json` for CPU-only jobs |
| Build fails on source-only pins | 10 TurboVLA pins have no wheels; `egl_probe` needs CMake | `build-essential cmake libegl-dev` in the recipe; check yours with `uv pip install --dry-run --only-binary :all: …` |
| Old-style `pip install -e` LIBERO doesn't import | LIBERO's top-level folder has no `__init__.py` | Put the repo root on `PYTHONPATH` (as `lp-exec.sh` does) |
| `FileExistsError: … '/home/<you>/.cache'` (e.g. `hf auth login` in the container) | On Turing `~/.cache` is an admin-made symlink to `/scratch/$USER/.cache`; without `-B /scratch` it dangles inside the container | Always `apptainer exec -B /scratch …` (also for login/one-off commands) |

## Where things live (per Turing's "Storing Data" docs)

| What | Where | Why |
|---|---|---|
| Scripts, code checkouts, small configs | home (`~/…`) | backed up, hourly/daily snapshots |
| Image, `assets.sqfs`, model weights, datasets, outputs you can regenerate | `/scratch/$USER/…` (20 TB / 10M files quota for us) | not backed up; "may be deleted or archived if unused for a while", so keep the scripts that rebuild them |
| Long-term cold storage | `/archive/$USER` | login nodes only; copy to scratch before using in jobs |
| Team sharing | `/group/<account>` | for us it existed but wasn't writable (root-owned); ask ARC if you need it |

## Checking on a running job without disturbing it

From the login node: `squeue --me`, `sstat -j <id> --format=JobID,AveCPU,MaxRSS -a`, and (Turing FAQ)
`srun --jobid=<id> --overlap --pty bash` to look inside: `top -u $USER`, `nvidia-smi`,
`ls /proc/<pid>/fd | wc -l`. Exit the shell when done; cancel jobs that no longer have a purpose.

A periodic monitor loop must not treat empty `squeue` output as "jobs done": Turing's Slurm controller sometimes
answers `slurm_load_jobs error: Socket timed out` (it did all night during our full run). Loop on the output
including errors, and confirm completion with `./status.sh` / `sacct -j <id>`:
```bash
while out=$(squeue -h --me -n lp-eval 2>&1); [ -n "$out" ]; do date; echo "$out"; ./status.sh | grep -E "^Status|^Plan:"; sleep 300; done
```
During that outage both jobs finished their work by 23:15 but Slurm only recorded them as ended (TIMEOUT, past the
time limit) the next morning, at the moment the controller was restarted (`scontrol show config | grep BOOT_TIME`
= 09:22:38, the jobs' recorded end 09:22:39). `sacct` showed the batch steps COMPLETED 0:0 and no results were lost,
but the allocation stayed held and billed (15.4 h instead of 5.3 h). So: set `--time` near the expected run time
(resubmitting resumes cleanly), and email ARC (gr-arcunix@wpi.edu) with job IDs if `squeue` times out for long.

## Contacts and docs
- Turing docs (LLM-readable): https://docs.turing.wpi.edu/llms.txt · full: https://docs.turing.wpi.edu/llms-full.txt 
- ARC / Turing support: gr-arcunix@wpi.edu
- LIBERO-Plus: https://github.com/sylvestf/LIBERO-plus (assets: HF dataset `Sylvest/LIBERO-plus`)
