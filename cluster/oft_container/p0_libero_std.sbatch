#!/bin/bash
# OFT+ setup (docs/oft_reference.md): standard (original) LIBERO evaluation of an OpenVLA-OFT checkpoint with OpenVLA-OFT's own
# run_libero_eval.py: 4 suites x 10 tasks x 50 trials (OFT's protocol: initial states 0-49, env.seed(0), seed 7).
# One model process on one A30; suites run one after another. A suite whose log already reports an overall success
# rate is skipped, so resubmitting continues where a cut-off job stopped.
#   OFT_CKPT=/scratch/$USER/ckpts/oftplus RUN=oftplus sbatch p0_libero_std.sbatch     (run from ~/oft_container)
# Results: /scratch/$USER/oft/libero_std/$RUN/<suite>/ (eval log + rollout videos); logs copied to
# ~/oft_results/libero_std/$RUN/.
#SBATCH --job-name=oft-libero-std
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --gres=gpu:1
#SBATCH --time=10:00:00
#SBATCH --output=logs/p0_libero_std_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
HERE=$PWD
: "${OFT_CKPT:?set OFT_CKPT}"; : "${RUN:?set RUN (a name for this checkpoint)}"
export OFT_BENCH=libero        # original LIBERO: ~/turing-vla/LIBERO + ~/.libero/config.yaml (see oft-exec.sh)
OUT=/scratch/$USER/oft/libero_std/$RUN
KEEP=$HOME/oft_results/libero_std/$RUN
mkdir -p "$OUT" "$KEEP"
[ -f "$HOME/.libero/config.yaml" ] && [ -d "$HOME/turing-vla/LIBERO/.git" ] || { echo "original LIBERO not set up"; exit 1; }
echo "[$(date)] $RUN on $(hostname): $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"

RC=0
for SUITE in libero_spatial libero_object libero_goal libero_10; do
  D=$OUT/$SUITE; mkdir -p "$D"
  if grep -qs "Overall success rate" "$D"/EVAL-*.txt; then echo "[$(date)] $SUITE already done"; continue; fi
  rm -f "$D"/EVAL-*.txt
  echo "[$(date)] $SUITE start"
  (cd "$D" && "$HERE/oft-exec.sh" python -u "$HOME/turing-vla/openvla-oft/experiments/robot/libero/run_libero_eval.py" \
      --pretrained_checkpoint "$OFT_CKPT" --task_suite_name "$SUITE" --num_trials_per_task 50 \
      --use_l1_regression True --use_diffusion False --use_film False \
      --num_images_in_input 2 --use_proprio True --center_crop True \
      --local_log_dir "$D" --seed 7) > "$D/stdout.log" 2>&1
  LOG=$(ls -t "$D"/EVAL-*.txt 2>/dev/null | head -1)
  if ! grep -qs "Overall success rate" "$LOG"; then echo "[$(date)] $SUITE FAILED (see $D/stdout.log)"; RC=1; continue; fi
  ERR=$(grep -c "Episode error" "$LOG")
  echo "[$(date)] $SUITE done: $(grep 'Overall success rate' "$LOG"); episode errors: $ERR"
  [ "$ERR" -eq 0 ] || RC=1
  cp "$LOG" "$KEEP/$SUITE.txt"
done

echo "=== summary"
for SUITE in libero_spatial libero_object libero_goal libero_10; do
  echo "$SUITE: $(grep -hs 'Total successes\|Total episodes\|Overall success rate' "$KEEP/$SUITE.txt" | tr '\n' ' ')"
done
exit $RC
