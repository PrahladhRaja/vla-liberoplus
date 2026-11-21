#!/bin/bash
# Stage 5: fine-tune the released TurboVLA LIBERO model on the LIBERO-Plus training data for 1 epoch (17,500 steps,
# global batch 128 = 2 GPUs x 32 x 2 accumulation), checkpoint every 500 steps. Near the time limit it requeues itself
# (at most twice) and resumes from the latest checkpoint (weights, optimizer, scheduler, step; new data seed).
# Keeps the latest 2 checkpoints plus every 5,000th. Succeeds only when the step-17500 checkpoint exists.
# The smoke test (stage 4) shortens --time to the measured need.
#SBATCH --job-name=ft-s5-train
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=160G
#SBATCH --gres=gpu:2
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --open-mode=append
#SBATCH --requeue
#SBATCH --signal=B:USR1@600
#SBATCH --mail-type=FAIL,REQUEUE,END

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
trap requeue_or_fail USR1
mkdir -p "$CKPT_DIR"
[ -e "$CKPT_DIR/turbovla_step_0.pth" ] || ln -s "$RELEASE_CKPT" "$CKPT_DIR/turbovla_step_0.pth"
start=$(latest_step "$CKPT_DIR")
plog "started on $(hostname) (restart ${SLURM_RESTART_COUNT:-0}) from step $start"
if [ "$start" -ge "$TARGET_STEPS" ]; then plog "OK: already at step $start"; exit 0; fi
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

prune() {   # keep step 0 (link), the newest 2, and multiples of 5000
  ls "$CKPT_DIR"/turbovla_step_*.pth | sed 's/.*_step_\([0-9]*\)\.pth/\1/' | sort -n | head -n -2 |
    while read -r s; do
      [ "$s" -eq 0 ] || [ $((s % 5000)) -eq 0 ] || rm -f "$CKPT_DIR/turbovla_step_$s.pth"
    done
}

cd "$TV"
"$LP_EXEC" $(train_cmd "$CKPT_DIR" "$TARGET_STEPS" 500 $((42 + start))) >> "$FT/logs/train.log" 2>&1 &
TRAIN_PID=$!
while kill -0 $TRAIN_PID 2>/dev/null; do prune; sleep 300 & wait $!; done
wait $TRAIN_PID; rc=$?
prune
[ -s "$CKPT_DIR/turbovla_step_$TARGET_STEPS.pth" ] || fail "training exited (code $rc) before step $TARGET_STEPS (logs/train.log)"
ln -sfn "$CKPT_DIR/turbovla_step_$TARGET_STEPS.pth" "$WORK/final.pth"
plog "OK: training finished: $WORK/final.pth"
