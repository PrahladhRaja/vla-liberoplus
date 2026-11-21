#!/bin/bash
# One-time code setup on Turing (light: run on the login node).
# Clones TurboVLA and LIBERO-Plus at the commits used for the desktop results, applies the local TurboVLA fix,
# and writes the LIBERO-Plus config that points at the assets mounted inside the container.
#   bash setup_code.sh          (run from this directory)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CODE=$HOME/turing-vla
mkdir -p "$CODE"

clone() {  # url dir commit
  if [ ! -d "$CODE/$2/.git" ]; then git clone "$1" "$CODE/$2"; fi
  git -C "$CODE/$2" checkout --quiet "$3"
  echo "$2 at $(git -C "$CODE/$2" rev-parse --short HEAD)"
}
clone https://github.com/H-EmbodVis/TurboVLA.git TurboVLA 6727c875666f8d5dda8d8cca0043da200738fe73
clone https://github.com/sylvestf/LIBERO-plus.git LIBERO-plus 4976dc30028e805ff8094b55501d532c48fec182

# Local fix: fall back to `model_state_dict` when a checkpoint has no EMA weights (released HF checkpoint).
PATCH=${PATCH:-$HERE/patches/0001-eval-ema-fallback.patch}   # repo patches/TurboVLA/, copied next to this script
[ -f "$PATCH" ] || { echo "missing $PATCH (copy patches/TurboVLA/*.patch to $HERE/patches/)"; exit 1; }
if git -C "$CODE/TurboVLA" apply --check "$PATCH" 2>/dev/null; then
  git -C "$CODE/TurboVLA" apply "$PATCH" && echo "applied $(basename "$PATCH")"
else
  echo "$(basename "$PATCH") already applied (or does not apply cleanly); check: git -C $CODE/TurboVLA diff --stat"
fi

# LIBERO-Plus config: code paths from the checkout. Assets: lp-exec.sh mounts assets.sqfs over the (empty)
# package-relative assets dir, because some LIBERO code ignores the config and always reads <package>/assets.
R=$CODE/LIBERO-plus/libero/libero
mkdir -p "$R/assets" "$HOME/.libero-plus"
cat > "$HOME/.libero-plus/config.yaml" <<EOF
assets: $R/assets
bddl_files: $R/bddl_files
benchmark_root: $R
datasets: $R/../datasets
init_states: $R/init_files
EOF
echo "wrote $HOME/.libero-plus/config.yaml"
