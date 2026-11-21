# Turing first session: what we need to move the LIBERO-Plus work

Goal of this session: **gather facts, change nothing important.** By the end we should know which account and
partitions to use, where data goes, how to build the Python environment, and, most importantly, whether
LIBERO/MuJoCo can render on Turing's GPU nodes. No downloads of large data, no long jobs.

Rules (from `docs/turing/AGENTS.md`): login node for light commands only; everything else through SLURM with
`--time` set and minimal resources; nothing outside our own files; clean up at the end. You type the password;
it is never stored. I'll show each command before it runs.

Expected time: ~45 minutes, including one 30-minute interactive job.

---

## Part A. Login node: read-only checks (~10 min)

```bash
ssh <username>@turing.wpi.edu
```

**A1. Accounts and limits**
```bash
sacctmgr show associations user=$USER format=Account,Partition,QOS -p   # which account(s) + partitions we may use
sacctmgr show qos format=Name,MaxTRESPU,MaxWall -p                       # per-user caps (CPUs/GPUs/RAM/time)
sinfo -s                                                                 # partitions and their state
```
Record: account name to put in `--account`, whether we have **short** and **long** (not just academic, which is
A30-only, 2 GPUs, 48 h).

**A2. GPU availability right now**
```bash
idle_gpus        # Turing command: GPU types, totals, free counts
scluster | head -40   # node features (GPU type, CPU model) and memory
```
Record: which GPU types are usually free (an L40S or A30 is plenty: TurboVLA inference uses ~1 GB VRAM; training
needs more but well under 24 GB).

**A3. Storage**
```bash
echo $HOME; ls -ld /scratch/$USER /group/* 2>/dev/null | head
df -h $HOME /scratch/$USER 2>/dev/null
```
Record: does `/scratch/$USER` exist, free space shown, group directory name (if any). (The docs don't list
quotas; if `df` isn't informative, ask ARC in Part D.)

**A4. Software modules**
```bash
module avail cuda 2>&1 | tail -15
module avail miniconda 2>&1 | tail -5; module avail uv 2>&1 | tail -5; module avail apptainer 2>&1 | tail -5
module avail ffmpeg imagemagick mesa osmesa gcc 2>&1 | tail -20
```
Record: CUDA versions (our stack is torch 2.3.1+cu121, so any driver supporting CUDA 12.1 is fine; the CUDA
*module* is only needed if something compiles CUDA code), and whether miniconda3 / uv / apptainer exist.

**A5. Outbound network (for later downloads)**
```bash
curl -sI https://huggingface.co | head -1
curl -sI https://download.pytorch.org/whl/cu121 | head -1
curl -sI https://github.com | head -1
```
Record: all three reachable from the login node? (Later we must check from a compute node too: Part B.)

**A6. System libraries on the login node** (compute nodes may differ; B repeats this)
```bash
ldconfig -p | grep -iE "libEGL|libOSMesa|libGL\.so|MagickWand" 
```

---

## Part B. One short interactive GPU job: the rendering test (~30 min)

This is the key unknown: LIBERO needs offscreen OpenGL. On the desktop it used EGL through WSL's Direct3D driver;
on Turing it needs NVIDIA's EGL driver (best) or OSMesa (CPU, slow).

**B1. Check how `sinteractive` takes options**
```bash
sinteractive --help
```

**B2. Start a small session** (adjust flag names to what B1 shows; use the account from A1):
```bash
sinteractive --account=<account> --partition=short --time=00:30:00 \
             --cpus-per-task=4 --mem=16G --gres=gpu:1
```

**B3. On the compute node: hardware, driver, libraries**
```bash
hostname; nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
nvidia-smi | head -5                       # top line shows max CUDA version the driver supports
ldconfig -p | grep -iE "libEGL|libEGL_nvidia|libOSMesa|libGL\.so|MagickWand"
ls /usr/share/glvnd/egl_vendor.d/ 2>/dev/null   # should list 10_nvidia.json if NVIDIA EGL is installed
curl -sI https://huggingface.co | head -1  # can compute nodes reach the internet?
```

**B4. Minimal MuJoCo render test** (throwaway env in scratch, ~1 GB, deleted afterwards)
```bash
module load uv
uv venv /scratch/$USER/render_test --python 3.10
VIRTUAL_ENV=/scratch/$USER/render_test uv pip install "mujoco==3.1.6" PyOpenGL numpy
cat > /scratch/$USER/render_test/t.py <<'EOF'
import os, time, mujoco
m = mujoco.MjModel.from_xml_string('<mujoco><worldbody><light pos="0 0 3"/><geom type="sphere" size=".1"/></worldbody></mujoco>')
d = mujoco.MjData(m); r = mujoco.Renderer(m, 256, 256)
t = time.time()
for _ in range(200): r.update_scene(d); img = r.render()
from OpenGL import GL
print(os.environ["MUJOCO_GL"], GL.glGetString(GL.GL_RENDERER), f"{200/(time.time()-t):.0f} renders/s", img.mean())
EOF
for gl in egl osmesa; do MUJOCO_GL=$gl PYOPENGL_PLATFORM=$gl /scratch/$USER/render_test/bin/python /scratch/$USER/render_test/t.py 2>&1 | tail -2; done
```
Record: for **egl**: works? renderer string should name the NVIDIA GPU; renders/s. For **osmesa**: works? (fallback).
If both fail, note the error text; the fix is likely an Apptainer image with the libraries inside (Part D question).

**B5. Containers on compute nodes**
```bash
module load apptainer && apptainer --version
```

**B6. Clean up and leave**
```bash
rm -rf /scratch/$USER/render_test     # only the folder we just created
exit                                  # ends the sinteractive job
squeue --me                           # should show nothing running
```

---

## Part C. Results sheet (fill in during the session)

| Item | Result |
|---|---|
| Account for `--account` | `<course-account>` (course account) |
| Partitions available (short / long / academic) | **academic only.** `<course-account>`'s parent account is `courses`; the academic partition allows `courses`/`<course-account>`, while short, long and quick deny them. (The association lists QOS long/quick/short, but partition deny lists win; a first `srun --partition=quick` was rejected with "Invalid account or account/partition combination".) |
| Per-user caps (GPUs, time) | academic: **A30 only, 2 GPUs, 64 CPUs, 250 GB RAM, 48 h** per job |
| Typically free GPU types | A30: 32 of 32 idle at 20:30 Sun (academic nodes gpu-4-[21-23,25-29], 4× A30 each, 96 CPUs, ~240 GB). Faster GPUs (L40S/A100/H100/H200/RTX Pro 6000) need a non-course (research) account |
| `/scratch/$USER` exists / free space | Yes, empty. Ceph quota **20 TB / 10M files** (home: 1 TB / 2M files) |
| Group directory | `/group/<course-account>` (exists, empty, group-writable) |
| Modules: cuda versions / miniconda3 / uv / apptainer | cuda 11.1 → 12.9 (`cuda/12.x`, `cuda12.x/toolkit`) · miniconda3 up to 25.1.1 · uv 0.7.2 · apptainer up to 1.4.1 · **also: imagemagick/7.0.8-7, mesa/25.0.5, osmesa/11.2.0, ffmpeg/6.1.1** |
| Internet from login node / from compute node | Login: HF, PyTorch, GitHub, PyPI all reachable (HTTP 200) · compute: (B3) |
| Login node GL libs | Mesa `libEGL`/`libGL` only (no NVIDIA, as expected); no system `libMagickWand` |
| GPU node driver version / max CUDA | gpu-4-21: NVIDIA A30 24 GB, driver 595.71.05, CUDA 13.2 (cu121 wheels fine). Compute node reaches Hugging Face (200) |
| NVIDIA EGL present (`10_nvidia.json`, `libEGL_nvidia`) | Vendor files yes (`libEGL_nvidia.so.0`, `10_nvidia.json`), but **no `libEGL.so.1` (libglvnd dispatcher) on the host** |
| MuJoCo `egl` render: works? renderer, renders/s | Host: ✗ (no `libEGL.so.1`). **Container (`docker://nvidia/opengl:1.2-glvnd-runtime-ubuntu22.04` + `apptainer exec --nv`): ✓ WORKS, ~2,330 renders/s** at 256×256 on an A30 (session 2). No vendor pin or device ID needed. Session 1's "black frames" were caused by the 1-sphere test scene, not the GPU |
| MuJoCo `osmesa` render: works? | Node `osmesa` module: ✗ (PyOpenGL can't find `libOSMesa`; module doesn't add it to the loader path). **CPU fallback that works:** Mesa software EGL inside the same container (`__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json`), ~62 renders/s on 4 cores |
| ImageMagick (`libMagickWand`) on compute node | Not on host; `imagemagick/7.0.8-7` module exists (untested with Wand) |
| Apptainer version | Modules up to `apptainer/1.4.1`; pulling from Docker Hub works on compute nodes (~160 MB in seconds) |

### Session 1 notes (2026-10-18) and where to resume
- First `srun` used `--partition=quick` and was rejected ("Invalid account or account/partition combination"):
  `<course-account>` (parent `courses`) is only allowed on **academic**. Working request:
  `srun -N 1 -n 4 --mem=16G --time=00:30:00 --partition=academic --gres=gpu:1 --pty bash` (job 2390335, started at once).
- `sinteractive` is an interactive prompt wrapper (ignores `--help`); it just runs the `srun` above, so use `srun` directly.
- Docs guidance (containers page, Python pages): missing system software → container; uv preferred over conda.
  So GPU rendering will go the **Apptainer + `--nv`** route.
### Session 2 (2026-10-18): black frames resolved (job 2390413, ~13 of 45 min used)
- Test scene `t3.py` (blue plane + red sphere, fixed camera) gave identical images on CPU (Mesa) and GPU (NVIDIA):
  mean RGB [48.4, 109.7, 160.9]. GPU ~2,330 renders/s vs CPU ~62 (≈38×).
- Ruled out: missing driver libs (`--nv` binds `libnvidia-gpucomp`, `eglcore`, `glsi`, …; only `libnvidia-egl-gbm`
  is absent, which MuJoCo's EGL device path doesn't need); EGL device selection (only device 0 is visible in the job).
- Harmless noise: an `EGLError` at cleanup (`mujoco/egl` `free`) after every run, on both CPU and GPU paths.
- Querying `glGetString` through PyOpenGL after MuJoCo releases its context segfaults (test-script bug, not a renderer
  problem); LIBERO doesn't do this.
- `/scratch/<user>/render_test` deleted. Rendering recipe for LIBERO-Plus on Turing:
  `apptainer exec --nv -B /scratch <image>.sif …` with `MUJOCO_GL=egl PYOPENGL_PLATFORM=egl`, where the image provides
  libglvnd/EGL (the nvidia/opengl glvnd runtime image works). Next: build a LIBERO-Plus image (or use this base +
  a scratch venv) and test a real LIBERO-Plus scene.

---

## Part D. Questions for ARC (gr-arcunix@wpi.edu) if the answers aren't obvious

1. **Many small files:** LIBERO-Plus needs ~9.5 GB of assets in ~449,000 files (meshes/textures). Is extracting
   them to `/scratch` acceptable, or should they live inside an Apptainer image / squashfs?
2. **Large downloads:** fine to download the ~75 GB LIBERO-Plus training set from Hugging Face on the login node,
   or should it run as a (CPU-only) job?
3. **Scratch quota / retention** for ~100 GB of data kept for a few weeks.
4. **Offscreen OpenGL:** if EGL isn't available on GPU nodes, is there a supported way (module or container)?
5. **Long partition access** if A1 shows we only have academic/short.

---

## What we'll move afterwards (for planning, not this session)

| Item | Size | How |
|---|---|---|
| TurboVLA repo (code) | 227 MB | `git clone` on Turing + copy the one local fix (`turbovla/evaluation/policy.py`, EMA fallback) |
| Pretrained weights: TurboVLA 1.7 GB, DINOv3 0.33 GB, BERT 0.42 GB | 2.4 GB | download from Hugging Face on Turing (DINOv3 is gated: needs `hf auth login` there) or `rsync` |
| LIBERO-Plus repo | 162 MB | `git clone` |
| LIBERO-Plus assets | 9.5 GB (449k files) | download `assets.zip` on Turing; handling depends on D1 |
| Eval kit | 1.4 MB | `rsync ~/liberoplus_eval_kit` (Windows scheduler parts replaced by SLURM job scripts) |
| Baseline results | 3.9 GB (mostly videos) | keep `results.jsonl`, `plan.tsv`, `summary.txt`; videos stay local |
| LIBERO-Plus training data (for fine-tuning) | 75 GB download, 83 GB unpacked | download on Turing into `/scratch` |

Environment to recreate (pinned versions from the desktop): Python 3.10, torch 2.3.1+cu121, torchvision 0.18.1,
transformers 4.57.6, tensorflow 2.21.0, tensorflow-datasets 4.9.10, numpy 1.26.4, mujoco 3.1.6, robosuite 1.4.1,
plus LIBERO-Plus extras (wand, usd-core, scikit-image) and ImageMagick (system library: needs conda-forge
`imagemagick` or a container, since `apt` isn't allowed).
