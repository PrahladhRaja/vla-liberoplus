#!/bin/bash
# Set up a LIBERO-Plus eval of an intermediate fine-tuning checkpoint on a stratified sample of the baseline plan
# (same fraction of every suite x category cell, fixed seed), for a paired comparison with the final model.
#   bash setup_ckpt_eval.sh <step> [fraction, default 0.30]     -> ~/lp_eval_ck<step>/
set -euo pipefail
source "$HOME/finetune_lp/common.sh"
STEP=$1; FRAC=${2:-0.30}
CK=$CKPT_DIR/turbovla_step_$STEP.pth
DIR=$HOME/lp_eval_ck$STEP
[ -s "$CK" ] || { echo "no checkpoint $CK"; exit 1; }
[ -e "$DIR" ] && { echo "$DIR already exists"; exit 1; }
cp -r "$KIT" "$DIR"
rm -rf "$DIR/videos" "$DIR/__pycache__"
sed -i 's/^SAVE_VIDEO=1/SAVE_VIDEO=0/' "$DIR/config.sh"
python3 - "$BASE_EVAL/plan.tsv" "$DIR/plan.tsv" "$FRAC" <<'EOF'
import collections, random, sys
src, dst, frac = sys.argv[1], sys.argv[2], float(sys.argv[3])
lines = open(src).read().splitlines()
header = [l for l in lines if l.startswith("#")]
rows = [l for l in lines if not l.startswith("#")]
cells = collections.defaultdict(list)
for i, l in enumerate(rows):
    f = l.split("\t")
    cells[(f[1], f[3])].append(i)
rng = random.Random(0)
keep = set()
for idx in cells.values():
    keep.update(rng.sample(idx, round(len(idx) * frac)))
open(dst, "w").write("\n".join(header + [rows[i] for i in sorted(keep)]) + "\n")
print(f"{len(keep)} of {len(rows)} tasks, {len(cells)} cells")
EOF
echo "$CK" > "$DIR/CHECKPOINT"
echo "set up $DIR for $CK"
