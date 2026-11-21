#!/bin/bash
# Standard LIBERO evaluation (regression check): 4 suites x 10 tasks x 50 trials with TurboVLA's own evaluator
# (experiments/libero/evaluate.py, same settings as the desktop baseline run), on the ORIGINAL LIBERO benchmark.
#   MODEL=released  sbatch libero_std.sbatch     (released turbovla_libero.pth)
#   MODEL=finetuned sbatch libero_std.sbatch     (EMA weights of /scratch/$USER/finetune_lp/final.pth)
# 8 parallel evaluators on one GPU: each suite split into tasks 0-4 and 5-9. Results: ~/libero_std/<MODEL>/.
# First run clones LIBERO (commit 8f1084e, as on the desktop) to ~/turing-vla/LIBERO and writes ~/.libero/config.yaml.
#SBATCH --job-name=libero-std
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --gres=gpu:1
#SBATCH --time=07:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
LIB=$HOME/turing-vla/LIBERO
LIB_COMMIT=8f1084e3132a39270c3a13ebe37270a43ece2a01
case "${MODEL:-}" in
  released) CKPT=$RELEASE_CKPT ;;
  finetuned) CKPT=$(readlink -f "$WORK/final.pth") ;;
  *) echo "set MODEL=released or MODEL=finetuned"; exit 1 ;;
esac
OUT=$HOME/libero_std/$MODEL
plog "standard LIBERO ($MODEL) started on $(hostname): $CKPT"
module load apptainer
git() { apptainer exec -B /scratch "$SIF" git "$@"; }   # compute nodes have no git; the image does

(
  flock 9
  if [ ! -d "$LIB/.git" ]; then
    git clone -q https://github.com/Lifelong-Robot-Learning/LIBERO.git "$LIB" && git -C "$LIB" checkout -q "$LIB_COMMIT" \
      || { rm -rf "$LIB"; exit 1; }
  fi
  if [ ! -f "$HOME/.libero/config.yaml" ]; then
    mkdir -p "$HOME/.libero"
    R=$LIB/libero/libero
    printf 'assets: %s/assets\nbddl_files: %s/bddl_files\nbenchmark_root: %s\ndatasets: %s/../datasets\ninit_states: %s/init_files\n' \
      "$R" "$R" "$R" "$R" "$R" > "$HOME/.libero/config.yaml"
  fi
) 9> "$FT/.libero_setup.lock" || fail "LIBERO clone failed"
[ "$(git -C "$LIB" rev-parse HEAD)" = "$LIB_COMMIT" ] || fail "LIBERO checkout is not at $LIB_COMMIT"

mkdir -p "$OUT"
cd "$TV"
export OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 OPENBLAS_NUM_THREADS=2
run() {   # suite, task ids, tag
  apptainer exec --nv -B /scratch \
    --env "PYTHONPATH=$LIB:$TV:$TV/third_party/vla_adapter,LIBERO_CONFIG_PATH=$HOME/.libero" \
    --env "__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json" \
    "$SIF" python -u experiments/libero/evaluate.py \
      --ckpt_path "$CKPT" --libero_root "$LIB" \
      --dinov3_path pretrained/dinov3-vitb16-pretrain-lvd1689m --bert_path pretrained/bert-base-uncased \
      --stats_path experiments/libero/configs/libero_all4_stats.json --stats_key libero_all4_no_noops \
      --task_suite_name "$1" --task_ids "$2" \
      --num_trials_per_task 50 --chunk_size 12 --num_open_loop_steps 12 --seed 7 --precision bf16 \
      --mujoco_gl egl --pyopengl_platform egl \
      --log_path "$OUT/$3.log" --result_json_path "$OUT/$3.json" > "$OUT/$3.stdout" 2>&1
}
PIDS=()
for SUITE in libero_spatial libero_object libero_goal libero_10; do
  run "$SUITE" 0,1,2,3,4 "${SUITE}_a" & PIDS+=($!); sleep 5
  run "$SUITE" 5,6,7,8,9 "${SUITE}_b" & PIDS+=($!); sleep 5
done
RC=0; for p in "${PIDS[@]}"; do wait "$p" || RC=1; done

n=$(ls "$OUT"/*.json 2>/dev/null | wc -l)
[ "$RC" -eq 0 ] && [ "$n" -eq 8 ] || fail "standard LIBERO ($MODEL): $n of 8 evaluators finished (see $OUT/*.stdout)"
plog "OK: standard LIBERO ($MODEL): $(python3 - "$OUT" <<'EOF'
import glob, json, sys
s = n = 0
for p in glob.glob(f"{sys.argv[1]}/*.json"):
    r = json.load(open(p)); s += r["total_successes"]; n += r["total_episodes"]
print(f"{s}/{n} = {100 * s / n:.1f}%")
EOF
)"
