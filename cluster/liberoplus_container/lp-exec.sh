#!/bin/bash
# Run a command inside the LIBERO-Plus container with GPU rendering, the assets squashfs mounted, and the code
# (TurboVLA, LIBERO-Plus) on PYTHONPATH. Use only on compute nodes (inside sbatch / srun jobs).
#   lp-exec.sh python -c "import libero"            lp-exec.sh python experiments/libero/evaluate.py ...
# Paths can be overridden with LP_DIR (image + assets) and LP_CODE (checkouts).
set -euo pipefail
LP_DIR=${LP_DIR:-/scratch/$USER/liberoplus}
LP_CODE=${LP_CODE:-$HOME/turing-vla}

if ! command -v apptainer > /dev/null; then module load apptainer > /dev/null 2>&1; fi
for f in "$LP_DIR/liberoplus.sif" "$LP_DIR/assets.sqfs"; do
  [ -f "$f" ] || { echo "lp-exec.sh: missing $f" >&2; exit 1; }
done

# Assets are mounted at LIBERO's package-relative location: some LIBERO code (e.g. TableArena via
# xml_path_completion) ignores the config's `assets:` path and always reads <package>/assets.
ASSETS_MNT="$LP_CODE/LIBERO-plus/libero/libero/assets"
[ -d "$ASSETS_MNT" ] || { echo "lp-exec.sh: missing mount point $ASSETS_MNT (run setup_code.sh)" >&2; exit 1; }

# Render on the NVIDIA GPU only. Without this, glvnd also offers Mesa 25's software device and MuJoCo picks it first
# (job 2390517: 0% GPU, CPU-bound). For a CPU fallback set LP_EGL_VENDOR=/usr/share/glvnd/egl_vendor.d/50_mesa.json.
export APPTAINERENV___EGL_VENDOR_LIBRARY_FILENAMES="${LP_EGL_VENDOR:-/usr/share/glvnd/egl_vendor.d/10_nvidia.json}"
export APPTAINERENV_PYTHONPATH="$LP_CODE/LIBERO-plus:$LP_CODE/TurboVLA:$LP_CODE/TurboVLA/third_party/vla_adapter"
export APPTAINERENV_LIBERO_CONFIG_PATH="$HOME/.libero-plus"
exec apptainer exec --nv \
  -B /scratch \
  -B "$LP_DIR/assets.sqfs:$ASSETS_MNT:image-src=/" \
  "$LP_DIR/liberoplus.sif" "$@"
