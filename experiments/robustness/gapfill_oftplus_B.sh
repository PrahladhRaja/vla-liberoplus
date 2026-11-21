#!/bin/bash
# Test 1 stage B for released OpenVLA-OFT+ (decision 2026-11-21): clean instructions on the REST of the affected rows.
#   ~/lp_t1_oftplus_cleanB : affected (non-Language) rows 1,001-8,493 of the baseline plan, CLEAN_INSTRUCTION=1,
#                            ENV_SEED=0. Together with ~/lp_t1_oftplus_clean (rows 1-1,000, job 2563982) it covers all
#                            8,493 affected tasks; merge the two dirs' results for the paired comparison with
#                            ~/lp_eval_oftplus. A separate dir because stage A is still queued/running in the other one.
# Two 1-GPU jobs on one plan (16 workers), as TurboVLA's stage B (t1_stageB.sh). Login node:
#   bash ~/robustness_tests/gapfill_oftplus_B.sh            dry run: creates the dir, prints the sbatch commands
#   SUBMIT=1 bash ~/robustness_tests/gapfill_oftplus_B.sh   also submits (IDs -> gapfill_jobs.env)
set -euo pipefail
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
OFTPLUS=/scratch/$USER/ckpts/oftplus
JOBS=$HOME/robustness_tests/gapfill_jobs.env
DIR=$HOME/lp_t1_oftplus_cleanB
A=$HOME/lp_t1_oftplus_clean
for f in "$BASE_PLAN" "$OFTPLUS" "$A/plan.tsv"; do [ -e "$f" ] || { echo "missing $f"; exit 1; }; done

if [ ! -e "$DIR" ]; then
  bash "$HOME/oft_container/setup_oft_eval.sh" "$DIR" 1 0 > /dev/null
  { grep '^#' "$BASE_PLAN"
    awk -F'\t' '/^#/ {next} $4 != "Language_Instructions" && ++k > 1000' "$BASE_PLAN"; } > "$DIR/plan.tsv"
  sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=1/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=0/" "$DIR/config.sh"
fi
# checks: stage A plan + this plan = all affected rows, in order, no overlap; same settings as stage A
cmp -s <(grep -hv '^#' "$A/plan.tsv" "$DIR/plan.tsv") \
       <(awk -F'\t' '/^#/ {next} $4 != "Language_Instructions"' "$BASE_PLAN") \
  || { echo "stage A + B plans do not equal the affected plan"; exit 1; }
cmp -s <(grep -E '^(ADAPTER|SEED|ENV_SEED|CLEAN_INSTRUCTION)=' "$A/config.sh") \
       <(grep -E '^(ADAPTER|SEED|ENV_SEED|CLEAN_INSTRUCTION)=' "$DIR/config.sh") \
  || { echo "settings differ from stage A"; exit 1; }
echo "$DIR: $(grep -vc '^#' "$DIR/plan.tsv") tasks (+ $(grep -vc '^#' "$A/plan.tsv") in stage A); $(grep -E '^(ADAPTER|SEED|ENV_SEED|CLEAN_INSTRUCTION|SAVE_VIDEO)=' "$DIR/config.sh" | cut -d' ' -f1 | tr '\n' ' ')"

for OFF in 0 8; do
  if [ "${SUBMIT:-0}" = 1 ]; then
    id=$(cd "$DIR" && OFT_CKPT=$OFTPLUS TOTAL_WORKERS=16 WORKER_OFFSET=$OFF \
         sbatch --parsable --time=08:00:00 --job-name=gap-oftplus-B eval_job_oft.sbatch)
    echo "lp_t1_oftplus_cleanB_$OFF=$id" | tee -a "$JOBS"
  else
    echo "dry run: cd $DIR && OFT_CKPT=$OFTPLUS TOTAL_WORKERS=16 WORKER_OFFSET=$OFF sbatch --parsable --time=08:00:00 --job-name=gap-oftplus-B eval_job_oft.sbatch"
  fi
done
