#!/bin/bash
# Original LIBERO-trained OpenVLA-OFT (non-fine-tuned reference), one A30:
#   1. bench_latency.py (batch 1, 50 warm-up + 300 timed queries); architecture = OFT+, so this checks it matches
#   2. standard LIBERO with OFT's run_libero_eval.py, 4 suites x 10 tasks x 50 trials (OFT+'s reference protocol:
#      env.seed(0), seed 7); run_libero_eval picks each suite's own norm stats (<suite>_no_noops)
#   sbatch oftL_eval_std.sbatch            (run from ~/oft_container)
# Resubmitting skips suites already done. Results: /scratch/$USER/oft/oftL/eval/, logs copied to ~/oft_results/oftL/.
#SBATCH --job-name=oftL-std
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --gres=gpu:1
#SBATCH --time=10:00:00
#SBATCH --output=logs/oftL_eval_std_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
HERE=$PWD
CK=/scratch/$USER/ckpts/oft_libero
OUT=/scratch/$USER/oft/oftL/eval
KEEP=$HOME/oft_results/oftL
mkdir -p "$OUT" "$KEEP"
[ -s "$CK/dataset_statistics.json" ] || { echo "no checkpoint at $CK"; exit 1; }
echo "[$(date)] original OFT on $(hostname): $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"
cd "$HOME/turing-vla/openvla-oft"
echo "code: $(cut -c1-12 ".git/$(sed "s/^ref: //" .git/HEAD)" 2>/dev/null); checkpoint $CK"
RC=0

echo "=== bench_latency"
if "$HERE/oft-exec.sh" python -u experiments/robot/bench_latency.py --pretrained_checkpoint "$CK" \
     --warmup 50 --iters 300 --out "$OUT/bench.json" > "$OUT/bench.log" 2>&1; then
  cp "$OUT/bench.json" "$KEEP/"
  python3 -c "import json,sys; r=json.load(open(sys.argv[1])); print(f\"end-to-end {r['end_to_end']['median_ms']:.1f} ms, LLM {r['llm']['median_ms']:.1f} ms\")" "$OUT/bench.json"
else
  echo "bench FAILED"; tail -n 20 "$OUT/bench.log"; RC=1
fi

export OFT_BENCH=libero
for SUITE in libero_spatial libero_object libero_goal libero_10; do
  D=$OUT/$SUITE; mkdir -p "$D"
  if grep -qs "Overall success rate" "$D"/EVAL-*.txt; then echo "[$(date)] $SUITE already done"; continue; fi
  rm -f "$D"/EVAL-*.txt
  echo "[$(date)] $SUITE start"
  (cd "$D" && "$HERE/oft-exec.sh" python -u "$HOME/turing-vla/openvla-oft/experiments/robot/libero/run_libero_eval.py" \
      --pretrained_checkpoint "$CK" --task_suite_name "$SUITE" \
      --num_trials_per_task 50 --use_l1_regression True --use_diffusion False --use_film False \
      --num_images_in_input 2 --use_proprio True --center_crop True \
      --local_log_dir "$D" --seed 7) > "$D/stdout.log" 2>&1
  LOG=$(ls -t "$D"/EVAL-*.txt 2>/dev/null | head -1)
  if ! grep -qs "Overall success rate" "$LOG"; then echo "[$(date)] $SUITE FAILED (see $D/stdout.log)"; RC=1; continue; fi
  ERR=$(grep -c "Episode error" "$LOG")
  echo "[$(date)] $SUITE done: $(grep 'Overall success rate' "$LOG"); episode errors: $ERR"
  [ "$ERR" -eq 0 ] || RC=1
  cp "$LOG" "$KEEP/$SUITE.txt"
done

echo "=== summary (original OFT; OFT+ reference 96.6 %, OFT paper ~97 %)"
for SUITE in libero_spatial libero_object libero_goal libero_10; do
  echo "$SUITE: $(grep -hs 'Overall success rate' "$KEEP/$SUITE.txt" | tr '\n' ' ')"
done
exit $RC
