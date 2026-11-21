#!/bin/bash
# Stage 0: finish the baseline LIBERO-Plus run (~/lp_eval_full). Its 6 skipped libero_10 Sensor Noise tasks were not
# hangs: they ran longer than the old 15-min watchdog. Removes their "hung" records (backup first) and evaluates them
# again with STALL_MIN=30 (6 workers, one task each). Succeeds only if the plan is then complete (10030/10030).
#SBATCH --job-name=ft-s0-baseline6
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=40G
#SBATCH --gres=gpu:1
#SBATCH --time=01:30:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --open-mode=append
#SBATCH --mail-type=FAIL

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname)"
cd "$BASE_EVAL" || fail "no $BASE_EVAL"
grep -q '^STALL_MIN=30' config.sh || fail "config.sh does not have STALL_MIN=30"

if python3 "$FT/plan_done.py" . > /dev/null && ! grep -q '"hung": true' results*.jsonl; then
  plog "baseline already complete: $(python3 "$FT/plan_done.py" .)"; exit 0
fi
mkdir -p backup_before_rerun
for f in results*.jsonl; do
  [ -e "backup_before_rerun/$f" ] || cp -p "$f" "backup_before_rerun/$f"
  grep -v '"hung": true' "$f" > "$f.tmp"; mv "$f.tmp" "$f"
done
plog "removed hung records (originals in $BASE_EVAL/backup_before_rerun/); evaluating the remaining tasks"

export SLURM_SUBMIT_DIR=$BASE_EVAL CPUS_PER_WORKER=2
bash eval_job.sbatch > "eval_job_${SLURM_JOB_ID}.log" 2>&1
state=$(python3 "$FT/plan_done.py" .) || fail "baseline still incomplete: $state"
[[ "$state" == *"(0 skipped)"* ]] || fail "baseline tasks skipped again (still over 30 min?): $state"
plog "OK: baseline complete: $state"
