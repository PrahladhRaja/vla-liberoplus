#!/bin/bash
# Robustness test 1, stage B (docs/plans/PLAN_test1_instruction_leak.md): fine-tuned TurboVLA.
# Extends the stage A clean-instruction dir (~/lp_t1_turbovla_clean) from the first 1,000 affected rows to all 8,493
# non-Language rows of the baseline plan. The stage A plan is an exact prefix of the new one, so the 1,000 finished
# tasks are kept (the kit skips done tasks). Two 1-GPU jobs on one plan (16 workers).
# OpenVLA-OFT+'s stage B is gapfill_oftplus_B.sh (a separate dir).
# Login node:  bash ~/robustness_tests/t1_stageB.sh        (job IDs appended to ~/robustness_tests/t1_jobs.env)
set -euo pipefail
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
TV=/scratch/$USER/finetune_lp/checkpoints/turbovla_step_17500.pth
JOBS=$HOME/robustness_tests/t1_jobs.env

extend_plan() {  # dir
  local dir=$1 new
  new=$(mktemp)
  awk -F'\t' '/^#/ {print; next} $4 != "Language_Instructions"' "$BASE_PLAN" > "$new"
  # the old plan must be a prefix of the new one (same rows, same order)
  local old_rows; old_rows=$(grep -vc '^#' "$dir/plan.tsv")
  cmp -s <(grep -v '^#' "$dir/plan.tsv") <(grep -v '^#' "$new" | head -n "$old_rows") || {
    echo "$dir/plan.tsv is not a prefix of the full affected plan"; rm -f "$new"; exit 1; }
  ls "$dir"/current*.json > /dev/null 2>&1 && { echo "$dir has a task in progress"; rm -f "$new"; exit 1; }
  mv "$new" "$dir/plan.tsv"
  grep -q '^CLEAN_INSTRUCTION=1' "$dir/config.sh" || { echo "$dir is not a clean-instruction run"; exit 1; }
  echo "$dir: plan $(grep -vc '^#' "$dir/plan.tsv") tasks, $(cat "$dir"/results*.jsonl | grep -vc hung) already done"
}

extend_plan "$HOME/lp_t1_turbovla_clean"
for OFF in 0 8; do
  id=$(cd "$HOME/lp_t1_turbovla_clean" && TURBOVLA_CKPT=$TV TOTAL_WORKERS=16 WORKER_OFFSET=$OFF \
       sbatch --parsable --time=04:30:00 --job-name=t1B-turbovla ${MAIL_USER:+--mail-user=$MAIL_USER} --mail-type=FAIL,END \
       eval_job.sbatch)
  echo "stageB_turbovla_$OFF=$id" | tee -a "$JOBS"
done
