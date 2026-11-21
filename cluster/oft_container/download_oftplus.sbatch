#!/bin/bash
# Download the released OpenVLA-OFT+ (LIBERO-Plus mix-SFT) checkpoint to scratch (docs/oft_reference.md).
# Must be a local path: openvla-oft's get_action_head/get_proprio_projector only download from moojink hub ids.
#   sbatch --dependency=afterok:<build job> download_oftplus.sbatch      (uses hf from openvla_oft.sif)
#SBATCH --job-name=oft-download
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=logs/download_oftplus_%j.log
#SBATCH --mail-type=FAIL

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load apptainer
SIF=/scratch/$USER/oft/openvla_oft.sif
OUT=/scratch/$USER/ckpts/oftplus
REPO=Sylvest/openvla-7b-oft-finetuned-libero-plus-mixdata
mkdir -p "$OUT"
echo "[$(date)] downloading $REPO to $OUT on $(hostname)"
# Plain HTTP streaming to disk, 2 files at a time: the Xet backend buffers in RAM and hit the 8 GB limit
# (job 2430250, OUT_OF_MEMORY while fetching the 5 GB shards in parallel). hf download resumes partial files.
export HF_HUB_DISABLE_XET=1
apptainer exec -B /scratch "$SIF" hf download "$REPO" --local-dir "$OUT" --max-workers 2

# Checks: the four merged shards (15.08 GB), both head files, the LoRA adapter and the dataset statistics.
for f in model-0000{1,2,3,4}-of-00004.safetensors action_head--150000_checkpoint.pt \
         proprio_projector--150000_checkpoint.pt dataset_statistics.json config.json lora_adapter/adapter_config.json; do
  [ -s "$OUT/$f" ] || { echo "missing $f"; exit 1; }
done
du -sh "$OUT"
apptainer exec -B /scratch "$SIF" python - "$OUT" <<'EOF'
import json, sys
d = sys.argv[1]
idx = json.load(open(f"{d}/model.safetensors.index.json"))
keys = list(idx["weight_map"])
assert len(keys) == 982 and not any("lora" in k for k in keys), (len(keys), "unexpected index")
stats = json.load(open(f"{d}/dataset_statistics.json"))
print("merged shards OK:", len(keys), "tensors, total", idx["metadata"]["total_size"], "bytes")
print("norm_stats keys:", list(stats), "| transitions:", stats["libero_spatial"].get("num_transitions"))
EOF
echo "[$(date)] done"
