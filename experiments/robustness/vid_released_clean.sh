#!/bin/bash
# Slide 4 videos (2026-11-14): RELEASED TurboVLA with CLEAN instructions, videos on. Slide 4 shows released-fails /
# fine-tuned-succeeds pairs on visual perturbations; this gives the "before" clips without leaked perturbation IDs.
#   slide tasks : libero_spatial 1536 (fog, max), libero_10 2245 (blue light), libero_object 57 (black table)
#                 -- test 1 already measured released+clean = failure on all three; this rerun adds the videos
#   unverified  : libero_goal 1607 (fog, max), libero_goal 159 (carpet table) -- striking, not in test 1
# Same protocol as the released official run ~/lp_eval_full (adapter-default checkpoint, seed 7).
#   bash ~/robustness_tests/vid_released_clean.sh   (login node; job ID -> ~/robustness_tests/vid_jobs.env)
set -euo pipefail
KIT=$HOME/turing_eval_kit
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
DIR=$HOME/vid_turbovlaR_clean
JOBS=$HOME/robustness_tests/vid_jobs.env
TASKS="libero_spatial:1536 libero_10:2245 libero_object:57 libero_goal:1607 libero_goal:159"
grep -q "^CLEAN_INSTRUCTION=" "$KIT/config.sh" || { echo "kit not patched"; exit 1; }
grep -q '^SEED=7' "$HOME/lp_eval_full/config.sh" || { echo "official released run is not seed 7?"; exit 1; }
[ -e "$DIR" ] && { echo "$DIR exists"; exit 1; }

# Already measured in test 1 (released, clean, no video)? Print so the outcome can be predicted.
for st in $TASKS; do
  grep -h "\"suite\": \"${st%%:*}\", \"task_id\": ${st##*:}," "$HOME"/lp_t1_turbovlaR_clean/results*.jsonl 2>/dev/null \
    | sed "s/^/test-1 result: /" || true
done

cp -r "$KIT" "$DIR"; rm -rf "$DIR/videos" "$DIR/__pycache__"; mkdir -p "$DIR/videos"
{ head -1 "$BASE_PLAN"
  for st in $TASKS; do
    awk -F'\t' -v s="${st%%:*}" -v t="${st##*:}" '/^#/ {next} $2 == s && $3 == t' "$BASE_PLAN"
  done; } > "$DIR/plan.tsv"
sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=1/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=1/" "$DIR/config.sh"
echo "$DIR: $(grep -vc '^#' "$DIR/plan.tsv") tasks; $(grep -E '^(SEED|CLEAN_INSTRUCTION|SAVE_VIDEO)=' "$DIR/config.sh" | cut -d' ' -f1 | tr '\n' ' ')"
[ "$(grep -vc '^#' "$DIR/plan.tsv")" = 5 ] || { echo "expected 5 plan rows"; exit 1; }

if [ "${SUBMIT:-0}" = 1 ]; then
  id=$(cd "$DIR" && env -u TURBOVLA_CKPT sbatch --parsable --time=00:45:00 --job-name=vid-turbovlaR eval_job.sbatch)
  echo "vid_turbovlaR_clean=$id" | tee -a "$JOBS"
else
  echo "dry run: set up only. Submit with:  cd $DIR && env -u TURBOVLA_CKPT sbatch --time=00:45:00 --job-name=vid-turbovlaR eval_job.sbatch"
fi
