#!/bin/bash
# Robustness test 1, added arm (decision 2026-11-10): RELEASED (non-fine-tuned) TurboVLA, stage A design.
#   ~/lp_t1_turbovlaR_clean : first 1,000 affected (non-Language) rows of the baseline plan, CLEAN_INSTRUCTION=1
#   ~/lp_t1_turbovlaR_rerun : first 200 of those, CLEAN_INSTRUCTION=0 (same-seed rerun-noise floor)
# Paired with the released model's official full run ~/lp_eval_full (seed 7, same plan, same kit protocol).
# The released checkpoint is the adapter default (TURBOVLA_CKPT unset). Login node:
#   bash ~/robustness_tests/t1_released.sh            (job IDs appended to ~/robustness_tests/t1_jobs.env)
set -euo pipefail
KIT=$HOME/turing_eval_kit
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
REL=$HOME/turing-vla/TurboVLA/pretrained/TurboVLA/checkpoints/libero/turbovla_libero.pth
JOBS=$HOME/robustness_tests/t1_jobs.env
for f in "$BASE_PLAN" "$REL" "$KIT/clean_instruction.py"; do [ -e "$f" ] || { echo "missing $f"; exit 1; }; done
grep -q "^CLEAN_INSTRUCTION=" "$KIT/config.sh" || { echo "kit not patched"; exit 1; }
grep -q '^SEED=7' "$HOME/lp_eval_full/config.sh" || { echo "official released run is not seed 7?"; exit 1; }

make_dir() {  # dir clean rows
  local dir=$1 clean=$2 rows=$3
  [ -e "$dir" ] && { echo "$dir exists"; exit 1; }
  cp -r "$KIT" "$dir"; rm -rf "$dir/videos" "$dir/__pycache__"
  awk -F'\t' -v n="$rows" '/^#/ {print; next} $4 != "Language_Instructions" && ++k <= n' "$BASE_PLAN" > "$dir/plan.tsv"
  sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=$clean/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=0/" "$dir/config.sh"
  echo "$dir: $(grep -vc '^#' "$dir/plan.tsv") tasks; $(grep -E '^(ADAPTER|SEED|CLEAN_INSTRUCTION|SAVE_VIDEO)=' "$dir/config.sh" | cut -d' ' -f1 | tr '\n' ' ')"
}
submit() {  # dir time
  local id
  id=$(cd "$1" && env -u TURBOVLA_CKPT sbatch --parsable --time="$2" --job-name=t1-turbovlaR \
       ${MAIL_USER:+--mail-user=$MAIL_USER} --mail-type=FAIL,END eval_job.sbatch)
  echo "$(basename "$1")=$id" | tee -a "$JOBS"
}
make_dir "$HOME/lp_t1_turbovlaR_clean" 1 1000
make_dir "$HOME/lp_t1_turbovlaR_rerun" 0 200
submit "$HOME/lp_t1_turbovlaR_clean" 03:00:00
submit "$HOME/lp_t1_turbovlaR_rerun" 01:00:00
