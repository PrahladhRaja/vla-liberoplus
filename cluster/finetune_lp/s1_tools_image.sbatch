#!/bin/bash
# Stage 1: build tools.sif (Ubuntu 24.04 + p7zip-full, zip, unzip) for unpacking the split-zip dataset. ~1-2 min.
#SBATCH --job-name=ft-s1-tools
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --mail-type=FAIL

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname)"
module load apptainer
mkdir -p "$WORK"
export APPTAINER_CACHEDIR=/scratch/$USER/liberoplus/apptainer_cache APPTAINER_TMPDIR=$WORK/apptainer_tmp
mkdir -p "$APPTAINER_TMPDIR"
apptainer build --force --fakeroot "$TOOLS_SIF.new" "$FT/tools.def" || fail "build failed"
mv "$TOOLS_SIF.new" "$TOOLS_SIF"
rm -rf "$APPTAINER_TMPDIR"
apptainer exec "$TOOLS_SIF" 7z i > /dev/null || fail "7z does not run in tools.sif"
plog "OK: $(ls -lh "$TOOLS_SIF" | awk '{print $5}') tools.sif"
