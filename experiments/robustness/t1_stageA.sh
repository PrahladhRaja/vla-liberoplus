#!/bin/bash
# Robustness test 1, stage A (docs/plans/PLAN_test1_instruction_leak.md): leaked perturbation ids vs clean instructions,
# fine-tuned TurboVLA (step 17,500, seed 7). Login node, from anywhere:  bash ~/robustness_tests/t1_stageA.sh
# Creates 2 eval-kit run dirs and submits one 1-GPU eval job per dir (job IDs -> ~/robustness_tests/t1_jobs.env):
#   ~/lp_t1_turbovla_clean : first N affected (non-Language) rows of the baseline plan, CLEAN_INSTRUCTION=1
#   ~/lp_t1_turbovla_rerun : first NR of those rows, CLEAN_INSTRUCTION=0 (same-seed rerun-noise floor)
# Everything else is identical to the model's official LIBERO-Plus run, which every result is paired with
# (compare_evals.py). Other models in test 1: released TurboVLA (t1_released.sh), OpenVLA-OFT+ (gapfill_oftplus*.sh),
# original OpenVLA-OFT (cluster/oft_container/oftL_submit.sh).
set -euo pipefail
N=${N:-1000}; NR=${NR:-200}
KIT=$HOME/turing_eval_kit
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
TV=/scratch/$USER/finetune_lp/checkpoints/turbovla_step_17500.pth
JOBS=$HOME/robustness_tests/t1_jobs.env
for f in "$BASE_PLAN" "$TV" "$KIT/clean_instruction.py"; do
  [ -e "$f" ] || { echo "missing $f"; exit 1; }
done
grep -q "^CLEAN_INSTRUCTION=" "$KIT/config.sh" || { echo "kit not updated (no CLEAN_INSTRUCTION in config.sh)"; exit 1; }

affected_plan() {  # header + first $1 non-Language rows, in baseline plan order
  awk -F'\t' -v n="$1" '/^#/ {print; next} $4 != "Language_Instructions" && ++k <= n' "$BASE_PLAN"
}

make_dir() {  # dir clean rows
  local dir=$1 clean=$2 rows=$3
  [ -e "$dir" ] && { echo "$dir exists"; exit 1; }
  cp -r "$KIT" "$dir"; rm -rf "$dir/videos" "$dir/__pycache__"
  affected_plan "$rows" > "$dir/plan.tsv"
  sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=$clean/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=0/" "$dir/config.sh"
  echo "$dir: $(grep -vc '^#' "$dir/plan.tsv") tasks; $(grep -E '^(ADAPTER|SEED|CLEAN_INSTRUCTION|SAVE_VIDEO)=' "$dir/config.sh" | cut -d' ' -f1 | tr '\n' ' ')"
}

submit() {  # dir time
  local dir=$1 time=$2 id
  id=$(cd "$dir" && TURBOVLA_CKPT=$TV sbatch --parsable --time="$time" --job-name=t1-turbovla \
       ${MAIL_USER:+--mail-user=$MAIL_USER} --mail-type=FAIL,END eval_job.sbatch)
  echo "$(basename "$dir")=$id" | tee -a "$JOBS"
}

mkdir -p "$HOME/robustness_tests"
make_dir "$HOME/lp_t1_turbovla_clean" 1 "$N"
make_dir "$HOME/lp_t1_turbovla_rerun" 0 "$NR"
submit "$HOME/lp_t1_turbovla_clean" 03:00:00
submit "$HOME/lp_t1_turbovla_rerun" 01:00:00
