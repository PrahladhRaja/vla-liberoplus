#!/bin/bash
# Submit the whole fine-tuning pipeline once. Each stage waits for the previous one (afterok); if a stage fails, the
# stages waiting on it are cancelled automatically (--kill-on-invalid-dep) and you get a FAIL email.
#   cd ~/finetune_lp && ./submit_pipeline.sh            first submission
#   ./submit_pipeline.sh --resume                         after a failure/stop: keep stages that COMPLETED, resubmit
#                                                         the rest (fix the cause first; nothing may be pending/running)
#
#   s0 baseline rerun (6 tasks, 1 GPU) ------------------------------------------------------------------+
#   s1 tools image --+                                                                                    |
#   s2 download -----+-> s3 extract -+-> s4 smoke (2 GPUs) -> s5 train (2 GPUs) -+-> s6 eval A (1 GPU) -+-> s7 report
#                                    +-> s3b stats (info only)                   +-> s6 eval B (1 GPU) -+
set -euo pipefail
source "$HOME/finetune_lp/common.sh"
cd "$FT"
RESUME=0; [ "${1:-}" = "--resume" ] && RESUME=1
declare -A OLD
if [ -f jobs.env ]; then
  if [ "$RESUME" -eq 0 ]; then
    echo "Already submitted (jobs.env exists). Check with ./status.sh; stop with ./stop.sh;"
    echo "after a failure or stop, fix the cause and run ./submit_pipeline.sh --resume"
    exit 1
  fi
  ids=$(grep -o '=[0-9]*' jobs.env | tr -d '=' | paste -sd,)
  if squeue -h --me -j "$ids" 2>/dev/null | grep -q .; then
    echo "Pipeline jobs are still pending/running; run ./stop.sh first."; exit 1
  fi
  while IFS='=' read -r k v; do [[ "$k" =~ ^[A-Z_]+$ ]] && OLD[$k]=$v; done < jobs.env
  mv jobs.env "jobs.env.$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p logs
chmod +x status.sh stop.sh
K=--kill-on-invalid-dep=yes

# stage NAME SCRIPT [sbatch options...] -- PREREQUISITE_NAMES...
# Reuses a previous job that COMPLETED (--resume); otherwise submits with afterok on the prerequisites that are not
# already completed.
declare -A ID DONE
stage() {
  local name=$1 script=$2; shift 2
  local opts=() deps=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do opts+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  local old=${OLD[$name]:-}
  if [ -n "$old" ] && [ "$(sacct -X -n -j "$old" -o State 2>/dev/null | head -1 | tr -d ' ')" = "COMPLETED" ]; then
    ID[$name]=$old; DONE[$name]=1; echo "  $name: $old already COMPLETED (kept)"; return
  fi
  for d in "$@"; do [ -z "${DONE[$d]:-}" ] && deps+=("${ID[$d]}"); done
  local dep=(); [ ${#deps[@]} -gt 0 ] && dep=($K --dependency=afterok:$(IFS=:; echo "${deps[*]}"))
  ID[$name]=$(sbatch --parsable "${dep[@]}" "${opts[@]}" "$script")
  echo "  $name: submitted ${ID[$name]}${deps:+ (after ${deps[*]})}"
}

stage BASELINE_JOB s0_baseline_rerun.sbatch
stage TOOLS_JOB s1_tools_image.sbatch
stage DOWNLOAD_JOB s2_download.sbatch
stage EXTRACT_JOB s3_extract.sbatch -- TOOLS_JOB DOWNLOAD_JOB
stage STATS_JOB s3b_stats.sbatch -- EXTRACT_JOB
stage SMOKE_JOB s4_smoke.sbatch -- EXTRACT_JOB
stage TRAIN_JOB s5_train.sbatch -- SMOKE_JOB
stage EVAL_A_JOB s6_eval.sbatch --export=ALL,TOTAL_WORKERS=16,WORKER_OFFSET=0 -- TRAIN_JOB
stage EVAL_B_JOB s6_eval.sbatch --export=ALL,TOTAL_WORKERS=16,WORKER_OFFSET=8 -- TRAIN_JOB
stage REPORT_JOB s7_report.sbatch -- BASELINE_JOB EVAL_A_JOB EVAL_B_JOB

{ echo "# job IDs of this pipeline ($([ $RESUME -eq 1 ] && echo resumed || echo submitted) $(date '+%F %T'))"
  for k in BASELINE_JOB TOOLS_JOB DOWNLOAD_JOB EXTRACT_JOB STATS_JOB SMOKE_JOB TRAIN_JOB EVAL_A_JOB EVAL_B_JOB REPORT_JOB; do
    echo "$k=${ID[$k]}"
  done
} > jobs.env
plog "pipeline $([ $RESUME -eq 1 ] && echo resumed || echo submitted): $(grep -v '^#' jobs.env | paste -sd' ')"
