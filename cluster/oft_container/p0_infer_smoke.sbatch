#!/bin/bash
# OFT+ setup (docs/oft_reference.md): unmodified OFT+ inference smoke test on one A30 with OpenVLA-OFT's own LIBERO eval script on
# LIBERO-Plus (2 tasks of libero_spatial, 2 trials each). Records peak GPU memory (nvidia-smi every 5 s) and the
# per-query latency the eval logs ("Model queries: ..."). Fails if any episode raised an error (run_libero_eval.py
# catches exceptions and would otherwise count them as failures).
#   sbatch p0_infer_smoke.sbatch            (run from ~/oft_container)
#SBATCH --job-name=oft-p0-smoke
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --time=00:45:00
#SBATCH --output=logs/p0_infer_smoke_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
HERE=$PWD
CKPT=/scratch/$USER/ckpts/oftplus
WORK=/scratch/$USER/oft/p0_smoke/$SLURM_JOB_ID      # rollout videos + eval log land here
mkdir -p "$WORK"
echo "[$(date)] on $(hostname): $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader)"

nvidia-smi --query-gpu=timestamp,memory.used,utilization.gpu --format=csv,noheader -l 5 > "$WORK/gpu.csv" &
SMI=$!
cd "$WORK"
"$HERE/oft-exec.sh" python -u "$HOME/turing-vla/openvla-oft/experiments/robot/libero/run_libero_eval.py" \
  --pretrained_checkpoint "$CKPT" \
  --task_suite_name libero_spatial --task_ids 0,1 --num_trials_per_task 2 \
  --use_l1_regression True --use_diffusion False --use_film False \
  --num_images_in_input 2 --use_proprio True --center_crop True \
  --local_log_dir "$WORK" --seed 7
RC=$?
kill $SMI 2>/dev/null

LOG=$(ls -t "$WORK"/EVAL-*.txt 2>/dev/null | head -1)
echo "=== eval log: $LOG"
grep -E "Task:|Success:|Model queries|Episode error|success rate|Overall" "$LOG" || true
echo "=== peak GPU memory: $(cut -d, -f2 "$WORK/gpu.csv" | tr -dc '0-9\n' | sort -n | tail -1) MiB"
[ "$RC" -eq 0 ] || { echo "FAILED: run_libero_eval.py exited $RC"; exit 1; }
grep -q "Episode error" "$LOG" && { echo "FAILED: an episode raised an error (see $LOG)"; exit 1; }
grep -q "Model queries" "$LOG" || { echo "FAILED: no model queries logged"; exit 1; }
echo "[$(date)] done"
