#!/bin/bash
# Original LIBERO-trained OpenVLA-OFT (non-fine-tuned reference; decision 2026-11-10). Login node, ~/oft_container:
#   bash oftL_submit.sh                 download → (standard LIBERO + bench) and full LIBERO-Plus + test 1, all afterok
#   T1=0 bash oftL_submit.sh            without test 1
# The 4-suite model has DIFFERENT action norm stats per suite (libero_<suite>_no_noops), and the OFT server uses one
# key, so every LIBERO-Plus run is split by suite: one eval-kit dir and job per suite, server --unnorm_key <suite>.
# Plans are the baseline plan (~/lp_eval_full/plan.tsv) filtered by suite, keeping plan order, so the union of the
# 4 dirs = exactly the task set every other model ran (full) or the same first-1,000/200 affected rows (test 1).
#   full:   ~/lp_eval_oftL_<suite>              (official instructions; ENV_SEED=0 like all OFT runs)
#   test 1: ~/lp_t1_oftL_<suite>_clean / _rerun (CLEAN_INSTRUCTION=1 / 0)
# Job IDs → oftL_jobs.env. Merge the per-suite dirs for analysis with oftL_merge.sh (later).
set -euo pipefail
cd "$(dirname "$0")"
T1=${T1:-1}
CK=/scratch/$USER/ckpts/oft_libero
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
JOBS=oftL_jobs.env
SUITES="libero_spatial libero_object libero_goal libero_10"
[ -f "$JOBS" ] && { echo "$JOBS exists: already submitted?"; exit 1; }
[ -f "$BASE_PLAN" ] || { echo "missing $BASE_PLAN"; exit 1; }
grep -q "^CLEAN_INSTRUCTION=" "$HOME/turing_eval_kit/config.sh" || { echo "eval kit not patched for test 1"; exit 1; }

plan_for() {  # suite, mode (full | affected:N)
  local suite=$1 mode=$2
  if [ "$mode" = full ]; then
    awk -F'\t' -v s="$suite" '/^#/ {print; next} $2 == s' "$BASE_PLAN"
  else
    awk -F'\t' -v s="$suite" -v n="${mode#affected:}" \
      '/^#/ {print; next} $4 != "Language_Instructions" && ++k <= n && $2 == s' "$BASE_PLAN"
  fi
}

make_dir() {  # dir suite mode clean
  local dir=$1 suite=$2 mode=$3 clean=$4
  [ -e "$dir" ] && { echo "$dir exists"; exit 1; }
  bash ./setup_oft_eval.sh "$dir" 1 0 > /dev/null
  plan_for "$suite" "$mode" > "$dir/plan.tsv"
  sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=$clean/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=0/" "$dir/config.sh"
  echo "$dir: $(grep -vc '^#' "$dir/plan.tsv") tasks, CLEAN_INSTRUCTION=$clean"
}

submit_kit() {  # dir suite time name
  (cd "$1" && OFT_CKPT=$CK OFT_SERVER_ARGS="--unnorm_key $2" \
   sbatch --parsable --dependency=afterok:$D --kill-on-invalid-dep=yes --time="$3" --job-name="$4" eval_job_oft.sbatch)
}

D=$(sbatch --parsable download_oft_libero.sbatch)
echo "DOWNLOAD=$D" | tee -a "$JOBS"
echo "STD=$(sbatch --parsable --dependency=afterok:$D --kill-on-invalid-dep=yes oftL_eval_std.sbatch)" | tee -a "$JOBS"
for s in $SUITES; do
  make_dir "$HOME/lp_eval_oftL_$s" "$s" full 0
  echo "LP_$s=$(submit_kit "$HOME/lp_eval_oftL_$s" "$s" 08:00:00 "oftL-lp-${s#libero_}")" | tee -a "$JOBS"
done
if [ "$T1" = 1 ]; then
  for s in $SUITES; do
    make_dir "$HOME/lp_t1_oftL_${s}_clean" "$s" affected:1000 1
    echo "T1CLEAN_$s=$(submit_kit "$HOME/lp_t1_oftL_${s}_clean" "$s" 01:30:00 "t1-oftL-${s#libero_}")" | tee -a "$JOBS"
    make_dir "$HOME/lp_t1_oftL_${s}_rerun" "$s" affected:200 0
    echo "T1RERUN_$s=$(submit_kit "$HOME/lp_t1_oftL_${s}_rerun" "$s" 00:45:00 "t1-oftL-${s#libero_}-r")" | tee -a "$JOBS"
  done
fi
