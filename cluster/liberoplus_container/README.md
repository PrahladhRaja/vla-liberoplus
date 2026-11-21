# LIBERO-Plus container for Turing

Runtime image + assets for running TurboVLA on LIBERO-Plus on WPI's Turing cluster (a course account, academic
partition, A30 GPUs). Rendering setup verified on 2026-10-18: Apptainer with `--nv`, libglvnd EGL + NVIDIA vendor
file (as in `nvidia/opengl`), MuJoCo EGL (~2,300 renders/s on an A30). Base is Ubuntu 24.04 because Turing's
rootless builds inject the host's fakeroot library, which needs glibc >= 2.38 (a 22.04 base failed: job 2390476).

## What goes where on Turing

| Item | Location | Why |
|---|---|---|
| `liberoplus.sif` (OS, ImageMagick, EGL, 168 pinned Python packages) | `/scratch/$USER/liberoplus/` | rebuildable, ~6–8 GB |
| `assets.sqfs` (LIBERO-Plus assets: 448,799 files, 8.95 GB, as ONE file) | `/scratch/$USER/liberoplus/` | avoids putting ~449k small files on the shared filesystem |
| TurboVLA + LIBERO-Plus checkouts (pinned commits + local fix) | `~/turing-vla/` | small, editable, backed up |
| LIBERO-Plus config | `~/.libero-plus/config.yaml` | assets → `~/turing-vla/LIBERO-plus/libero/libero/assets`, where `lp-exec.sh` mounts `assets.sqfs` (LIBERO's arena loader ignores the config and always reads the package-relative `assets/`) |

## Files

| File | Runs where | What it does |
|---|---|---|
| `liberoplus.def` | (build recipe) | Ubuntu 24.04 + libglvnd/EGL + NVIDIA EGL vendor file, ImageMagick 6 (`libmagickwand-dev`), build tools for the 10 source-only pins, uv-managed Python 3.10 venv at `/opt/venv` from `requirements.lock.txt` |
| `requirements.lock.txt` | (input) | `pip freeze` of the desktop `turbovla-liberoplus` env (torch 2.3.1+cu121, robosuite 1.4.1, TF 2.21, …), minus the editable repos, with **mujoco 3.2.0** instead of 3.1.6 (3.1.6 leaks a file handle per mesh file on every model load; see `liberoplus.def`) |
| `setup_code.sh` | login node | clones TurboVLA @ `6727c87` and LIBERO-Plus @ `4976dc3`, applies the EMA-fallback patch (repo `patches/TurboVLA/`, copied to `patches/` here), writes `~/.libero-plus/config.yaml` |
| `build_image.sbatch` | CPU job, 8 CPUs, 32 GB, ≤2 h | `apptainer build --fakeroot` → `liberoplus.sif` |
| `make_assets.sbatch` | CPU job, 8 CPUs, 16 GB, ≤2 h | downloads `assets.zip`, streams zip → tar → `mksquashfs` → `assets.sqfs` (no extraction), checks the mount, deletes the zip |
| `lp-exec.sh` | inside jobs | `apptainer exec --nv` with assets mounted and code on `PYTHONPATH` |
| `test_container.sbatch` + `lp_scene_test.py` | GPU job, 1 A30, 30 min | imports + one real LIBERO-Plus scene per perturbation category; saves frames to `/scratch/$USER/liberoplus/test_frames` |

## Order

```bash
scp -r cluster/liberoplus_container <username>@turing.wpi.edu:~/      # from a clone of this repo
# on Turing, in ~/liberoplus_container:
bash setup_code.sh                                                        # login node, light
B=$(sbatch --parsable build_image.sbatch)
A=$(sbatch --parsable --dependency=afterok:$B make_assets.sbatch)
sbatch --dependency=afterok:$A test_container.sbatch
```

## Verified locally (desktop, 2026-10-18)
- `zip2tar.py` on the real `assets.zip`: 448,799 files / 8.95 GB streamed in ~1 min, identical to the extracted copy.
- `lp_scene_test.py` with the desktop env: all 7 categories build, step and render.
- `uv` 0.7.2 resolves all pins for Python 3.10 with the PyTorch cu121 index (170 packages); the 10 source-only pins
  (antlr4-python3-runtime, bddl, easydict, egl_probe, evdev, future, gym, pathtools, promise, robomimic) build on
  Ubuntu 24.04.
- On Turing: `--fakeroot` builds work only via the host fakeroot fallback (no /etc/subuid entry; root-mapped namespace
  not available on compute nodes) -> image must be glibc >= 2.38.

## Verified on Turing (2026-10-18)
- Build (job 2390583): rootless `--fakeroot` build, 3.5 min, image 4.2 GB; self-test imports torch 2.3.1+cu121,
  mujoco 3.2.0, robosuite 1.4.1, tensorflow 2.21.0, transformers 4.57.6, wand.
- Assets (job 2390510): download 14 s, zip -> tar -> squashfs 2.5 min, `assets.sqfs` 3.6 GB (gzip; the cluster's
  mksquashfs has no zstd), 448,799 files visible through the mount.
- GPU smoke test (job 2390584, A30, 55 s): all 7 perturbation categories build, step and render on the GPU.
  ~45 steps/s (sensor noise ~9, CPU blur), env build 2-5 s, mean pixels identical to the desktop,
  32 open file handles at the end with mujoco 3.2.0 (vs 1,024+ and a stall with 3.1.6).
- Lessons baked into the scripts: EGL restricted to the NVIDIA vendor file (else Mesa's software device is
  picked first), numba cache in /tmp (image is read-only), assets mounted at LIBERO's package-relative `assets/`,
  `-B /scratch` on every exec, `python -u` for live logs.

## Later
- Pretrained weights (TurboVLA release, DINOv3 ViT-B (gated: needs `hf auth login`), BERT) into
  `/scratch/$USER/liberoplus/pretrained`, symlinked as `~/turing-vla/TurboVLA/pretrained`.
- Eval kit on Turing: SLURM job scripts instead of the Windows scheduler (`PY` = a wrapper around `lp-exec.sh python`).
