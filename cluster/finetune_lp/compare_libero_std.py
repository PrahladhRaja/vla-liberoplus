"""Paired comparison of two standard-LIBERO runs from evaluate.py logs ("task=T episode=E success=B" lines). Episode E
of task T starts from the same fixed initial state in both runs, so outcomes are paired.

    python3 compare_libero_std.py <baseline dir> <new dir> [out.md]

A run directory holds <suite>*.log files (one suite may be split over several logs, e.g. libero_10_a/_b).
"""

import glob
import math
import os
import re
import sys

SUITES = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]
LINE = re.compile(r"task=(\d+) episode=(\d+) success=(True|False)")


def load(d):
    out = {}
    for path in glob.glob(f"{d}/*.log"):
        name = os.path.basename(path)
        suite = next((s for s in sorted(SUITES, key=len, reverse=True) if name.startswith(s)), None)
        if suite is None:
            continue
        for line in open(path, errors="replace"):
            m = LINE.search(line)
            if m:
                out[(suite, int(m[1]), int(m[2]))] = m[3] == "True"
    return out


def mcnemar(b, c):
    if b + c == 0:
        return "no differing episodes"
    z = (abs(b - c) - 1) / math.sqrt(b + c)
    p = math.erfc(max(z, 0) / math.sqrt(2))
    return f"z = {z:.2f}, p ≈ {p:.3g} ({'significant' if p < 0.05 else 'not significant'} at 5%)"


base_dir, new_dir = sys.argv[1], sys.argv[2]
base, new = load(base_dir), load(new_dir)
both = sorted(set(base) & set(new))
L = ["# Standard LIBERO: baseline vs new model (paired episodes)\n",
     f"- Baseline: `{base_dir}` ({len(base)} episodes); new: `{new_dir}` ({len(new)} episodes); paired: {len(both)}.\n",
     "| Suite | baseline | new | Δ | baseline only | new only | paired test |", "|---|---|---|---|---|---|---|"]
for suite in SUITES + ["all"]:
    keys = [k for k in both if suite == "all" or k[0] == suite]
    if not keys:
        continue
    a = 100 * sum(base[k] for k in keys) / len(keys)
    b = 100 * sum(new[k] for k in keys) / len(keys)
    bo = sum(base[k] and not new[k] for k in keys)
    no = sum(new[k] and not base[k] for k in keys)
    name = f"**{suite}**" if suite == "all" else suite
    L.append(f"| {name} | {a:.1f} | {b:.1f} | {b - a:+.1f} | {bo} | {no} | {mcnemar(bo, no)} |")
L.append("\nPer task (success % baseline → new), tasks whose rate changed by 10 points or more:\n")
for suite in SUITES:
    rows = []
    for t in range(10):
        keys = [k for k in both if k[0] == suite and k[1] == t]
        if keys:
            a = 100 * sum(base[k] for k in keys) / len(keys)
            b = 100 * sum(new[k] for k in keys) / len(keys)
            if abs(b - a) >= 10:
                rows.append(f"task {t}: {a:.0f} → {b:.0f}")
    L.append(f"- {suite}: " + ("; ".join(rows) if rows else "none"))
text = "\n".join(L)
print(text)
if len(sys.argv) > 3:
    open(sys.argv[3], "w").write(text + "\n")
