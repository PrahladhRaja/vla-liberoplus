#!/bin/bash
# Merge the original-OFT per-suite eval-kit dirs (oftL_submit.sh) into one results dir per run, for compare_evals.py
# and summarize-style analysis. Read-only on the source dirs; writes ~/lp_eval_oftL, ~/lp_t1_oftL_clean,
# ~/lp_t1_oftL_rerun (each holds copies results.<suite>.<file>.jsonl + the union plan). Re-run any time to refresh.
#   bash oftL_merge.sh
set -euo pipefail
SUITES="libero_spatial libero_object libero_goal libero_10"
merge() {  # target, source pattern (with SUITE placeholder)
  local out=$1 pat=$2
  rm -rf "$out"; mkdir -p "$out"
  head -1 "$HOME/lp_eval_full/plan.tsv" > "$out/plan.tsv"
  for s in $SUITES; do
    local src=${pat//SUITE/$s}
    [ -d "$src" ] || { echo "missing $src"; continue; }
    for f in "$src"/results*.jsonl; do [ -f "$f" ] && cp "$f" "$out/results.$s.$(basename "$f")"; done
    grep -v '^#' "$src/plan.tsv" >> "$out/plan.tsv"
  done
  echo "$out: $(cat "$out"/results*.jsonl 2>/dev/null | grep -vc hung) results, plan $(grep -vc '^#' "$out/plan.tsv") tasks"
}
merge "$HOME/lp_eval_oftL" "$HOME/lp_eval_oftL_SUITE"
merge "$HOME/lp_t1_oftL_clean" "$HOME/lp_t1_oftL_SUITE_clean"
merge "$HOME/lp_t1_oftL_rerun" "$HOME/lp_t1_oftL_SUITE_rerun"
