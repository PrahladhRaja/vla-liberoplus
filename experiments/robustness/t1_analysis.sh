#!/bin/bash
# Robustness test 1 analysis (docs/plans/PLAN_test1_instruction_leak.md): paired comparisons of each model's
# clean-instruction and rerun-control runs with its official run, written to ~/robustness_tests/t1_analysis.txt.
# Saved as a script on 2026-11-21 from the command run on 2026-11-11 (minus comparisons of runs outside this repo's
# scope). OpenVLA-OFT+'s test 1 is analysed by gapfill_analysis.sh. Login node, read-only on the
# run dirs except ~/lp_eval_oftL* merges (cluster/oft_container/oftL_merge.sh).
#   bash ~/robustness_tests/t1_analysis.sh
set -euo pipefail
CMP=$HOME/finetune_lp/compare_evals.py
R=$HOME/robustness_tests/t1_analysis.txt
bash "$HOME/oft_container/oftL_merge.sh"
: > "$R"
cmpx() {  # baseline new title
  echo "== $3" >> "$R"
  python3 "$CMP" "$HOME/$1" "$HOME/$2" >> "$R" 2>&1
}
cmpx lp_eval_ft    lp_t1_turbovla_clean  "TurboVLA fine-tuned: clean vs official (8,493 affected)"
cmpx lp_eval_ft    lp_t1_turbovla_rerun  "TurboVLA fine-tuned: same-seed rerun vs official (200)"
cmpx lp_eval_full  lp_t1_turbovlaR_clean "TurboVLA released: clean vs official (1,000)"
cmpx lp_eval_full  lp_t1_turbovlaR_rerun "TurboVLA released: same-seed rerun vs official (200)"
cmpx lp_eval_oftL  lp_t1_oftL_clean      "OpenVLA-OFT (LIBERO-trained): clean vs official (1,000)"
cmpx lp_eval_oftL  lp_t1_oftL_rerun      "OpenVLA-OFT (LIBERO-trained): same-seed rerun vs official (200)"
cmpx lp_t1_oftL_clean lp_t1_turbovlaR_clean "Released TurboVLA clean vs OpenVLA-OFT clean (1,000)"
cmpx lp_eval_oftplus lp_eval_oftL        "OpenVLA-OFT vs OpenVLA-OFT+, official (LIBERO-Plus fine-tuning effect)"
cmpx lp_eval_full  lp_eval_oftL          "OpenVLA-OFT vs released TurboVLA, official"
{ echo "== OpenVLA-OFT standard LIBERO + latency"
  grep -h "Overall success rate" /scratch/$USER/oft/oftL/eval/*/EVAL-*.txt || true
  python3 -c "import json; r=json.load(open('$HOME/oft_results/oftL/bench.json')); print('bench', round(r['end_to_end']['median_ms'],1), round(r['llm']['median_ms'],1))" || true
} >> "$R" 2>&1
echo "wrote $R ($(wc -l < "$R") lines)"; grep "^== " "$R"
