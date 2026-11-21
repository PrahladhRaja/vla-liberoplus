#!/bin/bash
# Re-run a few LIBERO-Plus tasks WITH videos for the slides (2026-11-14): instruction-leak examples.
# Fine-tuned TurboVLA with CLEAN_INSTRUCTION=1 on libero_goal 1000 1024 1003 (three candidates, because a same-seed
# rerun can occasionally change the outcome; picked with pick_video_tasks.py). Their official-instruction videos come
# from the full run. One 1-GPU eval-kit job (~10-20 min), same protocol as the official run (seed 7).
# The released model's clean-instruction clips are vid_released_clean.sh.
#   bash ~/robustness_tests/vid_reruns.sh       (login node; job ID -> ~/robustness_tests/vid_jobs.env)
set -euo pipefail
KIT=$HOME/turing_eval_kit
TV=/scratch/$USER/finetune_lp/checkpoints/turbovla_step_17500.pth
BASE_PLAN=$HOME/lp_eval_full/plan.tsv
JOBS=$HOME/robustness_tests/vid_jobs.env
DIR=$HOME/vid_turbovla_clean
TASKS="libero_goal:1000 libero_goal:1024 libero_goal:1003"
[ -e "$DIR" ] && { echo "$DIR exists"; exit 1; }
cp -r "$KIT" "$DIR"; rm -rf "$DIR/videos" "$DIR/__pycache__"; mkdir -p "$DIR/videos"
{ head -1 "$BASE_PLAN"
  for st in $TASKS; do
    awk -F'\t' -v s="${st%%:*}" -v t="${st##*:}" '/^#/ {next} $2 == s && $3 == t' "$BASE_PLAN"
  done; } > "$DIR/plan.tsv"
sed -i "s/^CLEAN_INSTRUCTION=.*/CLEAN_INSTRUCTION=1/; s/^SAVE_VIDEO=[01]/SAVE_VIDEO=1/" "$DIR/config.sh"
echo "$DIR: $(grep -vc '^#' "$DIR/plan.tsv") tasks, CLEAN_INSTRUCTION=1, SAVE_VIDEO=1"
id=$(cd "$DIR" && TURBOVLA_CKPT=$TV sbatch --parsable --time=00:30:00 --job-name=vid-turbovla eval_job.sbatch)
echo "vid_turbovla_clean=$id" | tee -a "$JOBS"
