#!/bin/bash
# Stage 7: write report.md: paired comparison of the fine-tuned model with the completed baseline on the same tasks,
# plus the training summary. Emails when it ends (= the whole pipeline is done).
#SBATCH --job-name=ft-s7-report
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname)"
python3 "$FT/plan_done.py" "$BASE_EVAL" > /dev/null || fail "baseline run is incomplete"
python3 "$FT/plan_done.py" "$FT_EVAL" > /dev/null || fail "fine-tuned run is incomplete"
python3 "$FT_EVAL/summarize.py" > /dev/null 2>&1 || true
{
  python3 "$FT/compare_evals.py" "$BASE_EVAL" "$FT_EVAL"
  echo; echo "## Training"; echo
  echo "- Checkpoint: \`$(readlink -f "$WORK/final.pth")\` (evaluated with its EMA weights)"
  echo "- $(cat "$FT/smoke_summary.txt" 2>/dev/null | tr '\n' ' ')"
  echo "- Last training progress line: \`$(tr '\r' '\n' < "$FT/logs/train.log" | grep 'training:' | tail -1)\`"
  echo; echo "## Training data statistics vs released stats"; echo
  echo '```'; cat "$FT/stats/compare.txt" 2>/dev/null || echo "(stage 3b did not finish)"; echo '```'
} > "$FT/report.md" || fail "report failed"
plog "OK: pipeline finished; report at $FT/report.md"
