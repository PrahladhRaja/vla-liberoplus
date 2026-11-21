"""Compare TurboVLA's full LIBERO-Plus run on Turing with the earlier desktop run, task by task.

    python3 compare_runs.py <turing results.jsonl (all workers concatenated)> [out.md]

Desktop run: ~/TurboVLA/outputs/evaluation/liberoplus_bf16 (chunks/*.json block runs + results.jsonl sampled runs;
MuJoCo 3.1.6, RTX 3080, WSL2). Turing run: MuJoCo 3.2.0, A30, 16 workers.
"""

import collections
import glob
import json
import math
import os
import sys

CLASSIFICATION = os.path.expanduser("~/LIBERO-plus/libero/libero/benchmark/task_classification.json")
DESKTOP = os.path.expanduser("~/TurboVLA/outputs/evaluation/liberoplus_bf16")
COLUMNS = ["Camera Viewpoints", "Robot Initial States", "Language Instructions", "Light Conditions",
           "Background Textures", "Sensor Noise", "Objects Layout"]
SHORT = ["Camera", "Robot", "Language", "Light", "Background", "Noise", "Layout"]
SUITES = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]

cls = json.load(open(CLASSIFICATION))
cat = {(s, it["id"] - 1): it["category"] for s, items in cls.items() for it in items}


def load_desktop():
    out, hung = {}, collections.Counter()
    for p in glob.glob(f"{DESKTOP}/chunks/*.json"):
        r = json.load(open(p))
        for t in r["tasks"]:
            out[(r["task_suite_name"], t["task_id"])] = t["successes"] > 0
    for line in open(f"{DESKTOP}/results.jsonl"):
        r = json.loads(line)
        key = (r["suite"], r["task_id"])
        if r.get("hung"):
            hung[key] += 1
        else:
            out[key] = r["success"]
    return out, hung


def load_turing(path):
    out, hung, secs = {}, collections.Counter(), []
    for line in open(path):
        r = json.loads(line)
        key = (r["suite"], r["task_id"])
        if r.get("hung"):
            hung[key] += 1
        else:
            out[key] = r["success"]; secs.append(r["seconds"])
    return out, hung, secs


turing_path = sys.argv[1]
out_md = sys.argv[2] if len(sys.argv) > 2 else None
desk, desk_hung = load_desktop()
tur, tur_hung, tur_secs = load_turing(turing_path)
both = sorted(set(desk) & set(tur))
L = []
L.append(f"# TurboVLA on LIBERO-Plus: Turing vs desktop\n")
L.append(f"- Desktop: {len(desk)} tasks evaluated; Turing: {len(tur)} tasks evaluated; compared: {len(both)} tasks "
         f"(of {len(cat)}).")
skipped_t = [k for k, n in tur_hung.items() if n >= 2 and k not in tur]
L.append(f"- Turing hang/crash records: {sum(tur_hung.values())} on {len(tur_hung)} tasks; skipped after two: {len(skipped_t)}.")
L.append(f"- Turing episode time: {sum(tur_secs) / 3600:.1f} worker-hours (desktop full run: 86.5 h of episodes).\n")

# success rates (exact over the compared tasks)
def rate(keys, d):
    return 100 * sum(d[k] for k in keys) / len(keys) if keys else float("nan")

L.append("## Success rate (%), compared tasks; Δ = Turing − desktop\n")
L.append("| | " + " | ".join(SHORT) + " | Total |")
L.append("|---" * (len(SHORT) + 2) + "|")
for suite in SUITES + ["all suites"]:
    cells = []
    for c in COLUMNS:
        keys = [k for k in both if cat[k] == c and (suite == "all suites" or k[0] == suite)]
        cells.append(f"{rate(keys, desk):.1f} → {rate(keys, tur):.1f} ({rate(keys, tur) - rate(keys, desk):+.1f})")
    keys = [k for k in both if suite == "all suites" or k[0] == suite]
    cells.append(f"**{rate(keys, desk):.1f} → {rate(keys, tur):.1f} ({rate(keys, tur) - rate(keys, desk):+.1f})**")
    L.append(f"| {suite} | " + " | ".join(cells) + " |")

# agreement
a = sum(desk[k] and tur[k] for k in both); b = sum(desk[k] and not tur[k] for k in both)
c_ = sum((not desk[k]) and tur[k] for k in both); d = len(both) - a - b - c_
L.append("\n## Task-by-task agreement\n")
L.append(f"| | Turing success | Turing failure |\n|---|---|---|\n| **Desktop success** | {a} | {b} |\n"
         f"| **Desktop failure** | {c_} | {d} |\n")
L.append(f"Same outcome on {100 * (a + d) / len(both):.1f}% of tasks; {b + c_} differ ({b} desktop-only, {c_} Turing-only).")
if b + c_:
    z = (abs(b - c_) - 1) / math.sqrt(b + c_)  # McNemar with continuity correction
    p = math.erfc(z / math.sqrt(2))
    L.append(f"McNemar test (are flips biased in one direction?): z = {z:.2f}, p ≈ {p:.3g} "
             f"({'no significant difference' if p >= 0.05 else 'significant difference'} at 5%).")
L.append("\nPer category, share of tasks whose outcome differs:\n")
L.append("| Category | differing | of tasks | % |\n|---|---|---|---|")
for c, s in zip(COLUMNS, SHORT):
    keys = [k for k in both if cat[k] == c]
    n = sum(desk[k] != tur[k] for k in keys)
    L.append(f"| {s} | {n} | {len(keys)} | {100 * n / len(keys):.1f} |")
text = "\n".join(L)
print(text)
if out_md:
    open(out_md, "w").write(text + "\n")
