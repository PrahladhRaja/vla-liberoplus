#!/bin/bash
# Build openvla_oft.sif from openvla_oft.def (unprivileged, --fakeroot). CPU-only job; no GPU needed.
# The %test section (versions, OFT-fork check) runs at the end of the build.
#   sbatch build_oft_image.sbatch          (run from this directory)
#SBATCH --job-name=oft-build
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=28G          # seff of job 2430249: 22.4 GB peak, 31% of 8 CPUs, 5 min
#SBATCH --time=01:30:00
#SBATCH --output=logs/build_oft_image_%j.log
#SBATCH --mail-type=FAIL,END

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load apptainer

OUT=/scratch/$USER/oft
mkdir -p "$OUT"
# Download cache shared with the LIBERO-Plus build; build sandbox in scratch (not $HOME, not /tmp which is nodev).
export APPTAINER_CACHEDIR=/scratch/$USER/liberoplus/apptainer_cache
export APPTAINER_TMPDIR=$OUT/apptainer_tmp
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

echo "[$(date)] building on $(hostname) with $(apptainer --version)"
apptainer build --force --fakeroot "$OUT/openvla_oft.sif.new" openvla_oft.def
mv "$OUT/openvla_oft.sif.new" "$OUT/openvla_oft.sif"
rm -rf "$APPTAINER_TMPDIR"
ls -lh "$OUT/openvla_oft.sif"
echo "[$(date)] done"
