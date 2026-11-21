#!/bin/bash
# Stage 3b (informational, nothing waits on it): compute action/state statistics of the LIBERO-Plus training data and
# compare them with the released stats used for training and evaluation. Writes stats/compare.txt.
#SBATCH --job-name=ft-s3b-stats
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --mail-type=FAIL

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname)"
export LP_EGL_VENDOR=/usr/share/glvnd/egl_vendor.d/50_mesa.json
mkdir -p "$FT/stats"
"$LP_EXEC" python -u "$TV/scripts/libero/compute_mixed_stats.py" --dataset_dir "$DS_DIR" \
  --output "$FT/stats/libero_mix_stats.json" --stats_key libero_mix --overwrite --log_every 1000 \
  || fail "compute_mixed_stats.py failed"
python3 - "$STATS" "$STATS_KEY" "$FT/stats/libero_mix_stats.json" > "$FT/stats/compare.txt" <<'EOF'
import json, sys
old = json.load(open(sys.argv[1]))[sys.argv[2]]
new = json.load(open(sys.argv[3]))["libero_mix"]
for sec in ("action", "proprio"):
    print(f"== {sec}: released (LIBERO) -> LIBERO-Plus mix, per dimension")
    for stat in ("min", "max", "mean", "std"):
        print(f"  {stat:4s}", "  ".join(f"{a:+.3f}->{b:+.3f}" for a, b in zip(old[sec][stat], new[sec][stat])))
a_old, a_new = old["action"], new["action"]
out = [i for i in range(len(a_old["min"])) if a_new["min"][i] < a_old["min"][i] - 1e-6 or a_new["max"][i] > a_old["max"][i] + 1e-6]
print("\naction dims whose new range exceeds the released range (clamped in training):", out or "none")
EOF
plog "OK: stats compared (stats/compare.txt)"
