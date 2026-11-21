#!/bin/bash
# Analysis of the OFT+ gap-fill runs (gapfill_oftplus.sh, gapfill_oftplus_B.sh; 2026-11-21). Login node, read-only on
# the run dirs; writes ~/lp_t1_oftplus_clean_all (merged copy of stage A + B results) and
# ~/robustness_tests/gapfill_analysis.txt. Safe to run on partial results (each section reports its task count).
#   bash ~/robustness_tests/gapfill_analysis.sh
set -euo pipefail
CMP=$HOME/finetune_lp/compare_evals.py
R=$HOME/robustness_tests/gapfill_analysis.txt
SUM=$HOME/robustness_tests/gapfill_summary.py

# merge the two clean-instruction dirs (rows 1-1,000 and 1,001-8,493 of the affected plan)
M=$HOME/lp_t1_oftplus_clean_all
rm -rf "$M"; mkdir -p "$M"
head -1 "$HOME/lp_eval_full/plan.tsv" > "$M/plan.tsv"
for part in A:lp_t1_oftplus_clean B:lp_t1_oftplus_cleanB; do
  src=$HOME/${part#*:}
  for f in "$src"/results*.jsonl; do [ -f "$f" ] && cp "$f" "$M/results.${part%%:*}.$(basename "$f")"; done
  grep -v '^#' "$src/plan.tsv" >> "$M/plan.tsv"
done

status() {  # dir -> "done/plan"
  echo "$(cat "$1"/results*.jsonl 2>/dev/null | grep -vc hung || true)/$(grep -vc '^#' "$1/plan.tsv")"
}
cmpx() {  # baseline new title
  echo "== $3   (new run: $(status "$HOME/$2") tasks done)" >> "$R"
  python3 "$CMP" "$HOME/$1" "$HOME/$2" >> "$R" 2>&1
  echo >> "$R"
}

{ echo "# OFT+ gap-fill analysis, $(date)"
  for d in lp_t1_oftplus_clean lp_t1_oftplus_cleanB lp_t1_oftplus_clean_all lp_t1_oftplus_rerun lp_seed7_oftplus; do
    echo "  $d: $(status "$HOME/$d") tasks done"
  done
  echo; } > "$R"
cmpx lp_eval_oftplus lp_t1_oftplus_rerun     "1a OFT+ same-seed official rerun vs official (rerun-noise floor, 200 tasks)"
cmpx lp_eval_oftplus lp_t1_oftplus_clean     "1b OFT+ clean vs official, stage A (first 1,000 affected)"
cmpx lp_eval_oftplus lp_t1_oftplus_clean_all "1c OFT+ clean vs official, all 8,493 affected"
cmpx lp_t1_oftplus_clean_all lp_t1_turbovla_clean "1d TurboVLA fine-tuned clean vs OFT+ clean (affected tasks)"
cmpx lp_eval_oftplus lp_seed7_oftplus        "2  OFT+ env seed 7 vs seed 0, official (first 500 plan rows)"
{ echo "== 3  Full-benchmark clean-instruction estimates"; python3 "$SUM"; } >> "$R" 2>&1
echo "wrote $R ($(wc -l < "$R") lines)"
grep -E "^== |done$|INCOMPLETE" "$R"
