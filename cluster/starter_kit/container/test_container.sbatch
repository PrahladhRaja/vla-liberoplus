#!/bin/bash
# GPU smoke test of liberoplus.sif + assets.sqfs: imports and one real LIBERO-Plus scene per category.
#   sbatch test_container.sbatch          (run from this directory, after build_image + make_assets + setup_libero_plus)
#SBATCH --job-name=lp-test
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=test_container_%j.log

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
./lp-exec.sh python -u lp_scene_test.py "/scratch/$USER/liberoplus/test_frames"   # -u: progress visible in the log
