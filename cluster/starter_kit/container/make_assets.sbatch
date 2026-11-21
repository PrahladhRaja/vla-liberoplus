#!/bin/bash
# Download LIBERO-Plus assets.zip (6.4 GB) and convert it to one squashfs image (assets.sqfs), streaming
# zip -> tar -> squashfs so the ~449k asset files are never extracted onto the shared filesystem.
# Needs liberoplus.sif (build_image.sbatch) for the Hugging Face CLI and Python.
#   sbatch make_assets.sbatch          (run from this directory)
#SBATCH --job-name=lp-assets
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=make_assets_%j.log

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load apptainer squashfs

OUT=/scratch/$USER/liberoplus
SIF=$OUT/liberoplus.sif
PREFIX="inspire/hdd/project/embodied-multimodality/public/syfei/libero_new/release/dataset/LIBERO-plus-0/assets/"

echo "[$(date)] downloading assets.zip on $(hostname)"
apptainer exec -B /scratch "$SIF" hf download Sylvest/LIBERO-plus assets.zip --repo-type dataset --local-dir "$OUT/download"

echo "[$(date)] zip -> tar -> squashfs"
apptainer exec -B /scratch "$SIF" python zip2tar.py "$OUT/download/assets.zip" "$PREFIX" \
  | mksquashfs - "$OUT/assets.sqfs.new" -tar -comp gzip -processors "$SLURM_CPUS_PER_TASK" -no-progress  # module: gzip only
mv "$OUT/assets.sqfs.new" "$OUT/assets.sqfs"
ls -lh "$OUT/assets.sqfs"

echo "[$(date)] check: list a few files through the container mount"
apptainer exec -B "$OUT/assets.sqfs:/opt/liberoplus_assets:image-src=/" "$SIF" \
  bash -c 'ls /opt/liberoplus_assets; echo "files: $(find /opt/liberoplus_assets -type f | wc -l)"'

# The zip is no longer needed once the squashfs checks out (re-downloadable).
rm -rf "$OUT/download"
echo "[$(date)] done"
