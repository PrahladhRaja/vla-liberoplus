"""Paired comparison of two eval-kit runs on the same LIBERO-Plus tasks (e.g. released vs fine-tuned TurboVLA).

    python3 compare_evals.py <baseline eval dir> <new eval dir> [out.md]
"""

import collections
import glob
import json
import math
import os
import sys

CLASSIFICATION = os.environ.get("LP_CLASSIFICATION") or os.path.expanduser("~/turing-vla/LIBERO-plus/libero/libero/benchmark/task_classification.json")
COLUMNS = ["Camera Viewpoints", "Robot Initial States", "Language Instructions", "Light Conditions",
           "Background Textures", "Sensor Noise", "Objects Layout"]
SHORT = ["Camera", "Robot", "Language", "Light", "Background", "Noise", "Layout"]
SUITES = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]

cat = {(s, it["id"] - 1): it["category"] for s, items in json.load(open(CLASSIFICATION)).items() for it in items}


def load(d):
    out, hung = {}, collections.Counter()
    for p in glob.glob(f"{d}/results*.jsonl"):
        for line in open(p):
            r = json.loads(line)
            key = (r["suite"], r["task_id"])
            if r.get("hung"):
                hung[key] += 1
            else:
                out[key] = r["success"]
    return out, hung


def rate(keys, d):
    return 100 * sum(d[k] for k in keys) / len(keys) if keys else float("nan")


def mcnemar(b, c):
    if b + c == 0:
        return "no differing tasks"
    z = (abs(b - c) - 1) / math.sqrt(b + c)
    p = math.erfc(max(z, 0) / math.sqrt(2))
    return f"McNemar z = {z:.2f}, p ≈ {p:.3g} ({'significant' if p < 0.05 else 'not significant'} at 5%)"


base_dir, new_dir = sys.argv[1], sys.argv[2]
out_md = sys.argv[3] if len(sys.argv) > 3 else None
base, base_h = load(base_dir)
new, new_h = load(new_dir)
both = sorted(set(base) & set(new))
L = [f"# LIBERO-Plus: baseline vs new model (paired, same tasks)\n",
     f"- Baseline: `{base_dir}` ({len(base)} tasks); new: `{new_dir}` ({len(new)} tasks); compared: {len(both)} tasks.",
     f"- Skipped after two hangs: baseline {sum(1 for k, n in base_h.items() if n >= 2 and k not in base)}, "
     f"new {sum(1 for k, n in new_h.items() if n >= 2 and k not in new)}.\n",
     "## Success rate (%): baseline → new (Δ)\n",
     "| | " + " | ".join(SHORT) + " | Total |", "|---" * (len(SHORT) + 2) + "|"]
for suite in SUITES + ["all suites"]:
    cells = []
    for c in COLUMNS + [None]:
        keys = [k for k in both if (c is None or cat[k] == c) and (suite == "all suites" or k[0] == suite)]
        a, b = rate(keys, base), rate(keys, new)
        cell = f"{a:.1f} → {b:.1f} ({b - a:+.1f})"
        cells.append(f"**{cell}**" if c is None else cell)
    L.append(f"| {suite} | " + " | ".join(cells) + " |")

L.append("\n## Which tasks changed\n")
L.append("| Category | tasks | baseline only | new only | net | test |\n|---|---|---|---|---|---|")
for c, s in list(zip(COLUMNS, SHORT)) + [(None, "**all**")]:
    keys = [k for k in both if c is None or cat[k] == c]
    b = sum(base[k] and not new[k] for k in keys)
    n = sum(new[k] and not base[k] for k in keys)
    L.append(f"| {s} | {len(keys)} | {b} | {n} | {n - b:+d} | {mcnemar(b, n)} |")
L.append("\n'baseline only' = solved by the baseline but not the new model; 'new only' = the reverse. For reference, "
         "the same released model run on the desktop vs Turing differed on ~13% of tasks (6.2% / 7.1% each way), so "
         "per-task flips at that level are noise; the paired test accounts for this.")
text = "\n".join(L)
print(text)
if out_md:
    open(out_md, "w").write(text + "\n")
