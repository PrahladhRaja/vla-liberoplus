#!/bin/bash
# Run a command inside the OpenVLA-OFT container with GPU rendering and the code checkouts on PYTHONPATH.
# Use only on compute nodes (inside sbatch / srun jobs).
#   oft-exec.sh python experiments/robot/libero/run_libero_eval.py ...      (LIBERO-Plus benchmark, default)
#   OFT_BENCH=libero oft-exec.sh python ...                                 (original LIBERO benchmark)
# Overrides: OFT_SIF (image), LP_DIR (LIBERO-Plus assets squashfs dir), LP_CODE (checkouts),
#            LP_EGL_VENDOR (EGL vendor file; use .../50_mesa.json for CPU-only jobs).
set -euo pipefail
OFT_SIF=${OFT_SIF:-/scratch/$USER/oft/openvla_oft.sif}
LP_DIR=${LP_DIR:-/scratch/$USER/liberoplus}
LP_CODE=${LP_CODE:-$HOME/turing-vla}
BENCH=${OFT_BENCH:-libero_plus}

if ! command -v apptainer > /dev/null; then module load apptainer > /dev/null 2>&1; fi
[ -f "$OFT_SIF" ] || { echo "oft-exec.sh: missing $OFT_SIF (run build_oft_image.sbatch)" >&2; exit 1; }
[ -d "$LP_CODE/openvla-oft" ] || { echo "oft-exec.sh: missing $LP_CODE/openvla-oft (run setup_oft_code.sh)" >&2; exit 1; }

# NVIDIA EGL only: otherwise glvnd offers Mesa's software device first (0% GPU, CPU-bound renders).
export APPTAINERENV___EGL_VENDOR_LIBRARY_FILENAMES="${LP_EGL_VENDOR:-/usr/share/glvnd/egl_vendor.d/10_nvidia.json}"
BINDS=(-B /scratch)
case "$BENCH" in
  libero_plus)
    # LIBERO-Plus assets squashfs mounted at the package-relative location (some LIBERO code ignores the config).
    ASSETS_MNT="$LP_CODE/LIBERO-plus/libero/libero/assets"
    [ -f "$LP_DIR/assets.sqfs" ] || { echo "oft-exec.sh: missing $LP_DIR/assets.sqfs" >&2; exit 1; }
    BINDS+=(-B "$LP_DIR/assets.sqfs:$ASSETS_MNT:image-src=/")
    export APPTAINERENV_PYTHONPATH="$LP_CODE/LIBERO-plus:$LP_CODE/openvla-oft"
    export APPTAINERENV_LIBERO_CONFIG_PATH="$HOME/.libero-plus" ;;
  libero)
    # Original LIBERO (assets are in its git checkout); config written by finetune_lp/libero_std.sbatch.
    export APPTAINERENV_PYTHONPATH="$LP_CODE/LIBERO:$LP_CODE/openvla-oft"
    export APPTAINERENV_LIBERO_CONFIG_PATH="$HOME/.libero" ;;
  *) echo "oft-exec.sh: OFT_BENCH must be libero_plus or libero" >&2; exit 1 ;;
esac
exec apptainer exec --nv "${BINDS[@]}" "$OFT_SIF" "$@"
