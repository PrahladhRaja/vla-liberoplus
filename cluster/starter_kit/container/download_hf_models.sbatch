#!/bin/bash
# Download Hugging Face models/datasets to scratch from inside the container (CPU job, no GPU).
#   sbatch download_hf_models.sbatch <repo>[=<subdir>] ...
#   e.g.  sbatch download_hf_models.sbatch google-bert/bert-base-uncased facebook/dinov3-vitb16-pretrain-lvd1689m
# Gated models: accept the license on huggingface.co, then log in once on the login node (paste the token yourself):
#   module load apptainer; apptainer exec -B /scratch /scratch/$USER/liberoplus/liberoplus.sif hf auth login
# (-B /scratch matters: ~/.cache on Turing is a symlink into /scratch, which is invisible in the container without it.)
#SBATCH --job-name=hf-download
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=download_hf_models_%j.log

set -euo pipefail
module load apptainer
OUT=${HF_OUT:-/scratch/$USER/models}
SIF=${LP_DIR:-/scratch/$USER/liberoplus}/liberoplus.sif
[ $# -gt 0 ] || { echo "usage: sbatch download_hf_models.sbatch <repo>[=<subdir>] ..." >&2; exit 1; }
for spec in "$@"; do
  repo=${spec%%=*}; sub=${spec#*=}; [ "$sub" = "$spec" ] && sub=${repo##*/}
  echo "[$(date)] $repo -> $OUT/$sub"
  apptainer exec -B /scratch "$SIF" hf download "$repo" --local-dir "$OUT/$sub"
done
du -sh "$OUT"/*
