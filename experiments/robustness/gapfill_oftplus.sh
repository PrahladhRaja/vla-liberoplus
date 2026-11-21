#!/bin/bash
# Data-gap runs for the final presentation (2026-11-21), released OpenVLA-OFT+ only (no fine-tuned adapter):
#   1. test 1 on OFT+ itself, stage-A design as every other model:
#        ~/lp_t1_oftplus_clean : first 1,000 affected (non-Language) rows of the baseline plan, CLEAN_INSTRUCTION=1
#        ~/lp_t1_oftplus_rerun : first 200 of those, CLEAN_INSTRUCTION=0, ENV_SEED=0 (same-seed rerun-noise floor)
#   2. env-seed check: ~/lp_seed7_oftplus : first 500 plan rows (all 7 categories), official instructions,
#        ENV_SEED=7 (TurboVLA's seed) instead of OFT's 0 -> flip rate / net shift vs ~/lp_eval_oftplus (seed 0)
# All three are paired task by task with OFT+'s official run ~/lp_eval_oftplus (same plan order, same kit).
#   bash ~/robustness_tests/gapfill_oftplus.sh            dry run: creates the dirs, prints the sbatch commands
#   SUBMIT=1 bash ~/robustness_tests/gapfill_oftplus.sh   creates the dirs and submits (IDs -> gapfill_jobs.env)
set -euo pipefail
KIT=$HOME/turing_eval_kit
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
OFTPLUS=/scratch/$USER/ckpts/oftplus
JOBS=$HOME/robustness_tests/gapfill_jobs.env
for f in "$BASE_PLAN" "$OFTPLUS" "$KIT/clean_instruction.py" "$HOME/lp_eval_oftplus/plan.tsv"; do
  [ -e "$f" ] || { echo "missing $f"; exit 1; }
done
grep -q "^CLEAN_INSTRUCTION=" "$KIT/config.sh" || { echo "kit not patched"; exit 1; }
grep -q '^ENV_SEED=0' "$HOME/lp_eval_oftplus/config.sh" || { echo "official OFT+ run is not ENV_SEED=0?"; exit 1; }
cmp -s <(grep -v '^#' "$BASE_PLAN") <(grep -v '^#' "$HOME/lp_eval_oftplus/plan.tsv") \
  || { echo "OFT+ official plan differs from the baseline plan"; exit 1; }

make_dir() {  # dir clean env_seed rows-selector(affected:N | first:N)
  local dir=$1 clean=$2 seed=$3 sel=$4 n=${4#*:}
  [ -e "$dir" ] && { echo "$dir exists"; exit 1; }
  bash "$HOME/oft_container/setup_oft_eval.sh" "$dir" 1 0 > /dev/null
  if [ "${sel%%:*}" = affected ]; then
    awk -F'\t' -v n="$n" '/^#/ {print; next} $4 != "Language_Instructions" && ++k <= n' "$BASE_PLAN" > "$dir/plan.tsv"
  else
    awk -v n="$n" '/^#/ {print; next} ++k <= n' "$BASE_PLAN" > "$dir/plan.tsv"
  fi
  sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=$clean/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=0/; s/^ENV_SEED=0 /ENV_SEED=$seed /" "$dir/config.sh"
  grep -q "^ENV_SEED=$seed " "$dir/config.sh" || { echo "$dir: ENV_SEED not set"; exit 1; }
  echo "$dir: $(grep -vc '^#' "$dir/plan.tsv") tasks; $(grep -E '^(ADAPTER|SEED|ENV_SEED|CLEAN_INSTRUCTION|SAVE_VIDEO)=' "$dir/config.sh" | cut -d' ' -f1 | tr '\n' ' ')"
}

RUNS=( "lp_t1_oftplus_clean 1 0 affected:1000 02:30:00"
       "lp_t1_oftplus_rerun 0 0 affected:200 01:00:00"
       "lp_seed7_oftplus 0 7 first:500 01:30:00" )
mkdir -p "$HOME/robustness_tests"
for r in "${RUNS[@]}"; do set -- $r; make_dir "$HOME/$1" "$2" "$3" "$4"; done
for r in "${RUNS[@]}"; do
  set -- $r
  cmd="cd $HOME/$1 && OFT_CKPT=$OFTPLUS sbatch --parsable --time=$5 --job-name=gap-$1 eval_job_oft.sbatch"
  if [ "${SUBMIT:-0}" = 1 ]; then
    id=$(cd "$HOME/$1" && OFT_CKPT=$OFTPLUS sbatch --parsable --time="$5" --job-name="gap-$1" eval_job_oft.sbatch)
    echo "$1=$id" | tee -a "$JOBS"
  else
    echo "dry run: $cmd"
  fi
done
