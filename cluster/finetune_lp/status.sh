#!/bin/bash
# Where is the fine-tuning pipeline? Read-only; safe to run any time from a login node.
source "$HOME/finetune_lp/common.sh"
cd "$FT" || exit 1
[ -f jobs.env ] || { echo "Pipeline not submitted (no jobs.env)."; exit 0; }
source jobs.env

echo "== Stages (sacct)"
ids=$(grep -o '=[0-9]*' jobs.env | tr -d '=' | paste -sd,)
sacct -X -j "$ids" -o JobID,JobName%18,State%14,Start,Elapsed,Timelimit -n 2>/dev/null |
  awk '{printf "  %-9s %-18s %-14s %-19s %9s / %s\n", $1, $2, $3, $4, $5, $6}'
squeue -h --me -j "$ids" -o "  pending reason for %i: %r" -t PD 2>/dev/null | grep -v "None$"

echo; echo "== Pipeline log (last 8)"
tail -n 8 pipeline.log 2>/dev/null | sed 's/^/  /'

if [ -d "$DATA/_download" ] && [ ! -f "$DS_DIR/dataset_info.json" ]; then
  echo; echo "== Download: $(du -sb "$DATA/_download" 2>/dev/null | awk '{printf "%.1f", $1/1e9}') of 75.5 GB"
fi
[ -f smoke_summary.txt ] && { echo; echo "== Smoke test"; sed 's/^/  /' smoke_summary.txt; }
if [ -f logs/train.log ]; then
  echo; echo "== Training (latest checkpoint: step $(latest_step "$CKPT_DIR"))"
  tr '\r' '\n' < logs/train.log | grep 'training:' | tail -1 | sed 's/^/  /'
fi
if [ -f "$FT_EVAL/plan.tsv" ]; then
  echo; echo "== Fine-tuned evaluation: $(python3 plan_done.py "$FT_EVAL") tasks"
  python3 - "$BASE_EVAL" "$FT_EVAL" <<'EOF'
import glob, json, sys
def load(d):
    out = {}
    for p in glob.glob(f"{d}/results*.jsonl"):
        for line in open(p):
            r = json.loads(line)
            if not r.get("hung"): out[(r["suite"], r["task_id"])] = r["success"]
    return out
b, n = load(sys.argv[1]), load(sys.argv[2])
k = [x for x in n if x in b]
if k:
    print(f"  success on the {len(k)} tasks done so far: baseline {100*sum(b[x] for x in k)/len(k):.1f}% -> "
          f"fine-tuned {100*sum(n[x] for x in k)/len(k):.1f}%")
EOF
fi
[ -f report.md ] && { echo; echo "== Done: report at $FT/report.md"; }
