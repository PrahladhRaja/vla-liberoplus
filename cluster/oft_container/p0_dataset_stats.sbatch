#!/bin/bash
# OFT+ setup (docs/oft_reference.md): compute libero_mix statistics with OpenVLA-OFT's loader (cached in the dataset dir for
# training) and compare them with OFT+'s released dataset_statistics.json. CPU-only job.
#   sbatch p0_dataset_stats.sbatch          (run from ~/oft_container)
#SBATCH --job-name=oft-p0-stats
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G
#SBATCH --time=01:00:00
#SBATCH --output=logs/p0_dataset_stats_%j.log
#SBATCH --mail-type=FAIL,END

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
HERE=$PWD
DATA=/scratch/$USER/libero_plus_data          # contains libero_mix/1.0.0
CKPT=/scratch/$USER/ckpts/oftplus
export LP_EGL_VENDOR=/usr/share/glvnd/egl_vendor.d/50_mesa.json   # CPU-only job (see oft-exec.sh)
echo "[$(date)] on $(hostname)"
cd "$HOME/turing-vla/openvla-oft"
"$HERE/oft-exec.sh" python -u "$HERE/check_dataset_stats.py" "$DATA" "$CKPT"
ls -l "$DATA"/libero_mix/1.0.0/dataset_statistics_*.json
echo "[$(date)] done"
