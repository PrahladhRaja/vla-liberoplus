#!/bin/bash
# GPU training-throughput benchmark for TurboVLA fine-tuning on an A30 (synthetic batches; see bench_train.py).
#   sbatch bench_train.sbatch          (run from this directory, after download_weights.sbatch)
#SBATCH --job-name=lp-bench
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=bench_train_%j.log

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
./lp-exec.sh python -u bench_train.py "$HOME/turing-vla/TurboVLA" 8,16,32,48
