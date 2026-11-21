#!/bin/bash
# OFT+ setup (docs/oft_reference.md), latency benchmark + action-server checks, one A30:
#  (a) bench_latency.py: controlled latency/FLOPs benchmark of unmodified OFT+ (batch 1, 100 warm-up + 500 timed)
#  (b) check_server.py: oft_libero_server over HTTP via the eval kit's openvla_oft adapter must return action chunks
#      identical to OFT's in-process path on a real LIBERO-Plus episode
#   sbatch p0_tools_test.sbatch            (run from ~/oft_container)
#SBATCH --job-name=oft-p0-tools
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --gres=gpu:1
#SBATCH --time=00:45:00
#SBATCH --output=logs/p0_tools_test_%j.log
#SBATCH --mail-type=FAIL,END

set -uo pipefail
cd "$SLURM_SUBMIT_DIR"
HERE=$PWD
CKPT=/scratch/$USER/ckpts/oftplus
OUT=/scratch/$USER/oft/p0_tools/$SLURM_JOB_ID
mkdir -p "$OUT"
echo "[$(date)] on $(hostname): $(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"
cd "$HOME/turing-vla/openvla-oft"

echo "=== (a) bench_latency"
"$HERE/oft-exec.sh" python -u experiments/robot/bench_latency.py --pretrained_checkpoint "$CKPT" \
  --out "$OUT/bench_oftplus_bf16.json" > "$OUT/bench.log" 2>&1
RA=$?
python3 - "$OUT/bench_oftplus_bf16.json" <<'EOF' || true
import json, sys
r = json.load(open(sys.argv[1]))
for k in ("end_to_end", "vision", "projector", "llm"):
    print(f"{k:11s} median {r[k]['median_ms']:7.1f} ms  p95 {r[k]['p95_ms']:7.1f} ms")
f = r["llm_flops"]
print(f"LLM seq len {r['llm_seq_len']}, {f['all_layers_gflops']:.0f} GFLOPs in {f['num_layers']} layers "
      f"({f['per_layer_gflops']:.1f}/layer) + lm_head {f['lm_head_gflops']:.0f}; attn {r['attn_class']}; "
      f"peak {r['peak_gpu_mem_gb']:.1f} GiB; {r['gpu']}")
EOF

echo "=== (b) check_server"
"$HERE/oft-exec.sh" python -u experiments/robot/libero/check_server.py --pretrained_checkpoint "$CKPT" \
  --kit_dir "$HOME/turing_eval_kit" --queries 30 > "$OUT/check_server.log" 2>&1
RB=$?
grep -E "^task:|^queries|^HTTP|^max|^RESULT" "$OUT/check_server.log"

[ $RA -eq 0 ] || { echo "FAILED: bench_latency (see $OUT/bench.log)"; tail -n 20 "$OUT/bench.log"; exit 1; }
[ $RB -eq 0 ] || { echo "FAILED: check_server (see $OUT/check_server.log)"; tail -n 20 "$OUT/check_server.log"; exit 1; }
echo "[$(date)] done; raw output in $OUT"
