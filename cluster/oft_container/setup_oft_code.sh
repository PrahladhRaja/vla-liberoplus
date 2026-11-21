#!/bin/bash
# One-time code setup for OpenVLA-OFT on Turing (light: run on the login node, which has git).
# Clones openvla-oft at the pinned upstream commit, next to the existing LIBERO-plus checkout, and applies this
# project's two patches (repo patches/openvla-oft/: libero_mix registration + eval timing; latency benchmark +
# LIBERO action server). Copy them to ~/oft_container/patches/ first, or set PATCH_DIR.
#   bash setup_oft_code.sh
set -euo pipefail
CODE=$HOME/turing-vla
OFT_COMMIT=e4287e94541f459edc4feabc4e181f537cd569a8   # upstream main, 2025-09-08 (third_party/VERSIONS.md)
mkdir -p "$CODE"
if [ ! -d "$CODE/openvla-oft/.git" ]; then git clone https://github.com/moojink/openvla-oft.git "$CODE/openvla-oft"; fi
PATCH_DIR=${PATCH_DIR:-$HOME/oft_container/patches}
ls "$PATCH_DIR"/0*.patch > /dev/null 2>&1 || { echo "no patches in $PATCH_DIR"; exit 1; }
if [ -n "$(git -C "$CODE/openvla-oft" status --porcelain --untracked-files=no)" ]; then
  echo "$CODE/openvla-oft has local changes; not touching it"; exit 1; fi
git -C "$CODE/openvla-oft" checkout --quiet --detach "$OFT_COMMIT"
git -C "$CODE/openvla-oft" -c user.name="vla-liberoplus" -c user.email="vla-liberoplus@localhost" am -q "$PATCH_DIR"/0*.patch
echo "openvla-oft at $(git -C "$CODE/openvla-oft" rev-parse --short HEAD)"
[ -d "$CODE/LIBERO-plus/.git" ] || echo "WARNING: $CODE/LIBERO-plus missing (run ~/liberoplus_container/setup_code.sh)"
[ -f "$HOME/.libero-plus/config.yaml" ] || echo "WARNING: ~/.libero-plus/config.yaml missing"
