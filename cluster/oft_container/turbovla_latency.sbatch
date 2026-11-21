#!/bin/bash
# A30 inference latency of TurboVLA fine-tuned on LIBERO-Plus (step 17,500, the evaluated
# checkpoint) with turbovla_latency.py, compared per executed action with OFT+'s benchmark (docs/oft_reference.md).
#   sbatch turbovla_latency.sbatch             (run from ~/oft_container)
# Result: $ROOT/turbovla_latency.json (+ copy in ~/oft_results/turbovla_latency/).
#SBATCH --job-name=turbovla-latency
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=logs/turbovla_latency_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
HERE=$PWD
ROOT=${ROOT:-/scratch/$USER/oft/turbovla_latency}
CKPT=${TURBOVLA_CKPT:-/scratch/$USER/finetune_lp/checkpoints/turbovla_step_17500.pth}
OFT_BENCH=${OFT_BENCH:-/scratch/$USER/oft/p0_tools/2430342/bench_oftplus_bf16.json}
mkdir -p "$ROOT" "$HOME/oft_results/turbovla_latency"
echo "[$(date)] on $(hostname): $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"
echo "TurboVLA code: $(cut -c1-12 "$HOME/turing-vla/TurboVLA/.git/$(sed "s/^ref: //" "$HOME/turing-vla/TurboVLA/.git/HEAD")" 2>/dev/null); checkpoint $CKPT"
[ -f "$CKPT" ] || { echo "missing $CKPT (restore from /archive/$USER/turbovla_liberoplus_2026-10/checkpoints)"; exit 1; }
cd "$HOME/turing-vla/TurboVLA"   # the policy's relative defaults resolve from the repo root
"$HOME/liberoplus_container/lp-exec.sh" python -u "$HERE/turbovla_latency.py" --ckpt "$CKPT" \
  --oft_bench "$OFT_BENCH" --warmup 50 --iters 300 --out "$ROOT/turbovla_latency.json" 2>&1 |
  grep -E "^\[tl\]|Error|Traceback|^  File|missing|unexpected"
RC=${PIPESTATUS[0]}
[ "$RC" -eq 0 ] && cp "$ROOT/turbovla_latency.json" "$HOME/oft_results/turbovla_latency/"
echo "[$(date)] done: rc=$RC"
exit $RC
