#!/bin/bash
# Stage 2: download the LIBERO-Plus training data (HF dataset Sylvest/libero_plus_rlds: split zip, 75.5 GB) to scratch.
# hf download skips/resumes files already present, so a requeue continues where it stopped.
#SBATCH --job-name=ft-s2-download
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --open-mode=append
#SBATCH --requeue
#SBATCH --signal=B:USR1@300
#SBATCH --mail-type=FAIL,REQUEUE

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
trap requeue_or_fail USR1
plog "started on $(hostname) (restart ${SLURM_RESTART_COUNT:-0})"
module load apptainer
if [ -f "$DS_DIR/dataset_info.json" ]; then plog "OK: dataset already extracted; nothing to download"; exit 0; fi
mkdir -p "$DATA/_download"
apptainer exec -B /scratch "$SIF" hf download Sylvest/libero_plus_rlds --repo-type dataset \
  --include "libero_plus_mixdata.*" --local-dir "$DATA/_download" &
wait $! || fail "hf download exited with an error"

for f in libero_plus_mixdata.z01 libero_plus_mixdata.z02 libero_plus_mixdata.zip; do
  [ -s "$DATA/_download/$f" ] || fail "missing $f"
done
bytes=$(du -cb "$DATA"/_download/libero_plus_mixdata.* | tail -1 | cut -f1)
[ "$bytes" -ge 75000000000 ] || fail "download too small: $bytes bytes (expected ~75.5 GB)"
plog "OK: downloaded $((bytes / 1000000000)) GB"
