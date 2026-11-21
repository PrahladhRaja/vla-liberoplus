#!/bin/bash
# Stage 3: unpack the split zip (7z; fallback: merge with zip -s 0, then unzip), move the TFDS dataset to $DS_DIR,
# verify it (14,347 train episodes; one episode has 256x256 images, 8-D state, 7-D actions), then delete the zips.
#SBATCH --job-name=ft-s3-extract
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --mail-type=FAIL

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname)"
module load apptainer
tools() { apptainer exec -B /scratch "$TOOLS_SIF" "$@"; }

verify() {
  "$LP_EXEC" python -u - "$DS_DIR" "$DS_EPISODES" <<'EOF'
import sys
import tensorflow as tf
tf.config.set_visible_devices([], "GPU")
import tensorflow_datasets as tfds
b = tfds.builder_from_directory(sys.argv[1])
n = b.info.splits["train"].num_examples
print("train episodes:", n)
assert n == int(sys.argv[2]), f"expected {sys.argv[2]} episodes"
ep = next(iter(b.as_dataset(split="train").take(1)))
step = next(iter(ep["steps"].take(1)))
obs = step["observation"]
shapes = {k: tuple(obs[k].shape) for k in obs}
print("observation:", shapes, "action:", tuple(step["action"].shape),
      "instruction:", step["language_instruction"].numpy().decode()[:80])
assert shapes["image"] == (256, 256, 3) and shapes["wrist_image"] == (256, 256, 3)
assert shapes["state"] == (8,) and tuple(step["action"].shape) == (7,)
EOF
}
export LP_EGL_VENDOR=/usr/share/glvnd/egl_vendor.d/50_mesa.json   # CPU-only job (see lp-exec.sh)

if [ ! -f "$DS_DIR/dataset_info.json" ]; then
  rm -rf "$DATA/_extract"; mkdir -p "$DATA/_extract"
  plog "extracting with 7z"
  if ! tools 7z x -y -o"$DATA/_extract" "$DATA/_download/libero_plus_mixdata.zip" > "$FT/logs/extract_7z.log" 2>&1; then
    plog "7z failed (see logs/extract_7z.log); merging with zip -s 0 and unzipping"
    rm -rf "$DATA/_extract"; mkdir -p "$DATA/_extract"
    tools zip -s 0 "$DATA/_download/libero_plus_mixdata.zip" --out "$DATA/_merged.zip" || fail "zip -s 0 failed"
    tools unzip -q "$DATA/_merged.zip" -d "$DATA/_extract" || fail "unzip failed"
    rm -f "$DATA/_merged.zip"
  fi
  src=$(find "$DATA/_extract" -type d -path '*/libero_mix/1.0.0' | head -1)
  [ -n "$src" ] || fail "no libero_mix/1.0.0 folder in the archive"
  mkdir -p "$(dirname "$DS_DIR")"
  mv "$src" "$DS_DIR"
fi
verify || fail "dataset verification failed"
rm -rf "$DATA/_extract" "$DATA/_download"
plog "OK: dataset at $DS_DIR ($(du -sh "$DS_DIR" | cut -f1)); zips deleted"
