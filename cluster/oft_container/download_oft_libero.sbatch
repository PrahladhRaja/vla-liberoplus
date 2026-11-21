#!/bin/bash
# Download the original LIBERO-trained OpenVLA-OFT (4-suite model; the checkpoint OFT+ was fine-tuned from) to scratch,
# pinned to a fixed revision. Decision 2026-11-10: evaluate it on LIBERO-Plus / standard LIBERO / test 1 as the
# non-fine-tuned OFT reference (docs/plans/PLAN_oft_libero_reference.md).
#   sbatch download_oft_libero.sbatch            (run from ~/oft_container; uses hf from openvla_oft.sif)
#SBATCH --job-name=oftL-download
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=logs/download_oft_libero_%j.log
#SBATCH --mail-type=FAIL

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load apptainer
SIF=/scratch/$USER/oft/openvla_oft.sif
OUT=/scratch/$USER/ckpts/oft_libero
REPO=moojink/openvla-7b-oft-finetuned-libero-spatial-object-goal-10
REV=638918f3d1c2e43a39a8a20772bdb8b91835e4b7
mkdir -p "$OUT"
echo "[$(date)] downloading $REPO@$REV to $OUT on $(hostname)"
export HF_HUB_DISABLE_XET=1   # Xet buffers in RAM (OOM in job 2430250); plain HTTP, 2 files at a time
apptainer exec -B /scratch "$SIF" hf download "$REPO" --revision "$REV" --local-dir "$OUT" --max-workers 2

for f in model-0000{1,2,3,4}-of-00004.safetensors action_head--300000_checkpoint.pt \
         proprio_projector--300000_checkpoint.pt dataset_statistics.json config.json lora_adapter/adapter_config.json; do
  [ -s "$OUT/$f" ] || { echo "missing $f"; exit 1; }
done
du -sh "$OUT"
apptainer exec -B /scratch "$SIF" python - "$OUT" <<'EOF'
import json, sys
d = sys.argv[1]
idx = json.load(open(f"{d}/model.safetensors.index.json"))
keys = list(idx["weight_map"])
assert not any("lora" in k for k in keys), "unexpected LoRA keys in merged shards"
stats = json.load(open(f"{d}/dataset_statistics.json"))
print("merged shards OK:", len(keys), "tensors, total", idx["metadata"]["total_size"], "bytes")
print("norm_stats keys:", list(stats))
for s in ("libero_spatial", "libero_object", "libero_goal", "libero_10"):
    k = s if s in stats else f"{s}_no_noops"
    assert k in stats, f"no norm stats for {s}"
    print(f"  {s} -> {k}: action q01[:3] {[round(x, 4) for x in stats[k]['action']['q01'][:3]]}")
EOF
echo "[$(date)] done"
