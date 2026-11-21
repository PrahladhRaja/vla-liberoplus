#!/bin/bash
# Download TurboVLA's model weights to scratch and link them into the TurboVLA checkout as pretrained/.
#   - TurboVLA release (LIBERO checkpoint + configs only; the RoboTwin checkpoint is skipped)
#   - BERT base uncased (public)
#   - DINOv3 ViT-B/16 (GATED: accept the license on huggingface.co, then run `hf auth login` once on Turing;
#     the token in ~/.cache/huggingface/ is visible inside the container)
#   sbatch download_weights.sbatch          (run from this directory)
#SBATCH --job-name=lp-weights
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=download_weights_%j.log

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load apptainer
OUT=/scratch/$USER/liberoplus/pretrained
SIF=/scratch/$USER/liberoplus/liberoplus.sif
hf() { apptainer exec -B /scratch "$SIF" hf "$@"; }

echo "[$(date)] downloading to $OUT on $(hostname)"
hf download H-EmbodVis/TurboVLA --include "checkpoints/libero/*" "*.json" "*.yaml" "*.md" --local-dir "$OUT/TurboVLA"
hf download google-bert/bert-base-uncased config.json tokenizer.json tokenizer_config.json vocab.txt model.safetensors \
  --local-dir "$OUT/bert-base-uncased"
hf download facebook/dinov3-vitb16-pretrain-lvd1689m --local-dir "$OUT/dinov3-vitb16-pretrain-lvd1689m"

# The evaluator and trainer expect <TurboVLA>/pretrained/...; point it at scratch.
ln -sfn "$OUT" "$HOME/turing-vla/TurboVLA/pretrained"
du -sh "$OUT"/*
ls -l "$OUT/TurboVLA/checkpoints/libero/"
echo "[$(date)] done"
