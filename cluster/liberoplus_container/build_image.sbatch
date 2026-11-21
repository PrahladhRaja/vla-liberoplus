#!/bin/bash
# Build liberoplus.sif from liberoplus.def (unprivileged, --fakeroot). CPU-only job; no GPU needed.
#   sbatch build_image.sbatch          (run from this directory)
#SBATCH --job-name=lp-build
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=build_image_%j.log

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load apptainer

OUT=/scratch/$USER/liberoplus
mkdir -p "$OUT"
# Keep Apptainer's download cache and build sandbox in our scratch space (not $HOME, not /tmp which is nodev).
export APPTAINER_CACHEDIR=$OUT/apptainer_cache
export APPTAINER_TMPDIR=$OUT/apptainer_tmp
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

echo "[$(date)] building on $(hostname) with $(apptainer --version)"
apptainer build --fakeroot "$OUT/liberoplus.sif.new" liberoplus.def
mv "$OUT/liberoplus.sif.new" "$OUT/liberoplus.sif"
ls -lh "$OUT/liberoplus.sif"

# The build sandbox is temporary; the cache is kept to speed up rebuilds (delete it when no longer needed).
rm -rf "$APPTAINER_TMPDIR"
echo "[$(date)] done"
