#!/bin/bash
# Create an eval-kit run directory for an OpenVLA-OFT checkpoint (login node; copies small files only).
#   bash setup_oft_eval.sh <run dir> [first N plan rows | all] [save videos 0|1]
# The plan is the baseline's plan.tsv (~/lp_eval_full/plan.tsv, the TurboVLA runs' task order) so every OFT run is
# paired with the others task by task; N > 0 keeps the first N rows (the plan is round-robin over all 28
# suite x category cells, so any prefix covers every cell). Videos go to /scratch/$USER/<run name>_videos.
set -euo pipefail
DIR=$1; ROWS=${2:-all}; VIDEO=${3:-0}
KIT=$HOME/turing_eval_kit
[ -e "$DIR" ] && { echo "$DIR exists"; exit 1; }
cp -r "$KIT" "$DIR"
rm -rf "$DIR/videos" "$DIR/__pycache__"
sed -i "s|^export LP_EXEC=.*|export LP_EXEC=\${LP_EXEC:-\$HOME/oft_container/oft-exec.sh}|" "$DIR/config.sh"
sed -i "s|^ADAPTER=.*|ADAPTER=adapters.openvla_oft:OpenVLAOFTAdapter|" "$DIR/config.sh"
sed -i "s|^SAVE_VIDEO=[01]|SAVE_VIDEO=$VIDEO|" "$DIR/config.sh"
sed -i "s|^# ENV_SEED=0 .*|ENV_SEED=0               # OpenVLA-OFT protocol: env.seed(0) as in OFT's run_libero_eval.py|" "$DIR/config.sh"
if [ "$ROWS" = all ]; then cp "$HOME/lp_eval_full/plan.tsv" "$DIR/plan.tsv"
else awk -v n="$ROWS" '/^#/ {print; next} ++k <= n' "$HOME/lp_eval_full/plan.tsv" > "$DIR/plan.tsv"; fi
V=/scratch/$USER/$(basename "$DIR")_videos; mkdir -p "$V"; ln -sfn "$V" "$DIR/videos"
grep -E "^export LP_EXEC|^ADAPTER|^SAVE_VIDEO|^STALL_MIN|^SEED|^ENV_SEED" "$DIR/config.sh"
echo "$(grep -vc '^#' "$DIR/plan.tsv") tasks in $DIR/plan.tsv"
