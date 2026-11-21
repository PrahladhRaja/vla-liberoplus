#!/bin/bash
# Stage 4: smoke test of the real training setup on 2 GPUs: 300 steps from the released model, checkpoints at
# 100/200/300. Passes only if the released weights load completely (0 missing / 0 unexpected keys), the loss is finite,
# and the step-300 checkpoint has EMA weights and loads in the eval adapter. Measures steps/s and then shortens the
# training job's time limit to the measured need (x1.3 + 30 min).
#SBATCH --job-name=ft-s4-smoke
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=160G
#SBATCH --gres=gpu:2
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --mail-type=FAIL

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname)"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

rm -rf "$SMOKE_DIR"; mkdir -p "$SMOKE_DIR"
ln -s "$RELEASE_CKPT" "$SMOKE_DIR/turbovla_step_0.pth"
LOG=$FT/logs/smoke_train.log
cd "$TV"
"$LP_EXEC" $(train_cmd "$SMOKE_DIR" 300 100 42) > "$LOG" 2>&1 &
TRAIN_PID=$!
peak=0
while kill -0 $TRAIN_PID 2>/dev/null; do
  m=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | sort -n | tail -1); [ "$m" -gt "$peak" ] && peak=$m
  sleep 15
done
wait $TRAIN_PID || fail "smoke training exited with an error (logs/smoke_train.log)"

grep -q "resume missing keys: 0" "$LOG" || fail "released weights did not load completely: $(grep 'resume missing keys' "$LOG")"
grep -q "resume unexpected keys: 0" "$LOG" || fail "unexpected keys: $(grep 'resume unexpected keys' "$LOG")"
for s in 100 200 300; do [ -s "$SMOKE_DIR/turbovla_step_$s.pth" ] || fail "no step-$s checkpoint"; done
loss=$(tr '\r' '\n' < "$LOG" | grep -o 'avg=[0-9.e+-]*' | tail -1 | cut -d= -f2)
python3 -c "import math,sys; v=float(sys.argv[1]); sys.exit(0 if math.isfinite(v) else 1)" "${loss:-nan}" \
  || fail "loss is not finite: ${loss:-none}"
"$LP_EXEC" python -u "$FT/check_ckpt.py" "$SMOKE_DIR/turbovla_step_300.pth" "$KIT" >> "$LOG" 2>&1 \
  || fail "step-300 checkpoint does not load in the eval adapter (logs/smoke_train.log)"

# Speed from the checkpoint times (100 steps between saves), and the training job's time limit from it.
t2=$(stat -c %Y "$SMOKE_DIR/turbovla_step_200.pth"); t3=$(stat -c %Y "$SMOKE_DIR/turbovla_step_300.pth")
rate=$(python3 -c "print(f'{100 / max(1, $t3 - $t2):.3f}')")
need_min=$(python3 -c "print(int($TARGET_STEPS / $rate / 60 * 1.3 + 30))")
ckpt_gb=$(du -L -BG "$SMOKE_DIR/turbovla_step_300.pth" | cut -f1)
{ echo "smoke test $(date '+%F %T'): $rate steps/s on 2 A30s, loss (20-step avg) $loss, peak GPU memory ${peak} MiB,"
  echo "checkpoint size $ckpt_gb; 1 epoch ($TARGET_STEPS steps) ~ $(python3 -c "print(f'{$TARGET_STEPS / $rate / 3600:.1f}')") h"
} > "$FT/smoke_summary.txt"
plog "OK: $(head -1 "$FT/smoke_summary.txt" | cut -d: -f2-)"

source "$FT/jobs.env"
if [ -n "${TRAIN_JOB:-}" ]; then
  h=$((need_min / 60)); m=$((need_min % 60))
  if scontrol update JobId="$TRAIN_JOB" TimeLimit="$(printf '%d:%02d:00' $h $m)" 2>> "$LOG"; then
    plog "training job $TRAIN_JOB time limit set to $(printf '%d:%02d' $h $m) (measured need x1.3 + 30 min)"
  else
    plog "could not shorten training job $TRAIN_JOB time limit (keeps its submitted limit)"
  fi
fi
rm -rf "$SMOKE_DIR"
