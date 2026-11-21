"""Full-benchmark clean-instruction estimates for OFT+ (gap-fill runs, 2026-11-21) and fine-tuned TurboVLA.

Clean estimate = clean-instruction results on the 8,493 affected (non-Language) tasks + the model's official results
on the 1,537 Language tasks (whose instruction is the perturbation and is never cleaned), as for TurboVLA's ~82.1.
Prints per-category rates, completeness, and a paired McNemar test OFT+ vs TurboVLA on the tasks both have.
Login node, stdlib only:   python3 gapfill_summary.py
"""
import glob
import json
import math
import os

H = os.path.expanduser("~")
PLAN = f"{H}/lp_eval_full/plan.tsv"
CATS = ["Camera_Viewpoints", "Robot_Initial_States", "Language_Instructions", "Light_Conditions",
        "Background_Textures", "Sensor_Noise", "Objects_Layout"]
SHORT = ["Camera", "Robot", "Language", "Light", "Background", "Noise", "Layout"]
MODELS = {  # name: (official run, clean run on the affected tasks)
    "OFT+": ("lp_eval_oftplus", "lp_t1_oftplus_clean_all"),
    "TurboVLA fine-tuned": ("lp_eval_ft", "lp_t1_turbovla_clean"),
}

cat = {}
for line in open(PLAN):
    if line.startswith("#"):
        continue
    _, suite, tid, c, _ = line.rstrip("\n").split("\t")
    cat[(suite, int(tid))] = c
unknown = sorted({c for c in cat.values() if c not in CATS})
assert not unknown, f"unexpected categories in plan: {unknown}"


def load(d):
    out = {}
    for p in glob.glob(f"{H}/{d}/results*.jsonl"):
        for line in open(p):
            r = json.loads(line)
            if not r.get("hung"):
                out[(r["suite"], int(r["task_id"]))] = bool(r["success"])
    return out


def mcnemar(b, c):  # normal approximation with continuity correction, two-sided
    if b + c == 0:
        return float("nan"), 1.0
    z = (abs(b - c) - 1) / math.sqrt(b + c)
    return z, math.erfc(z / math.sqrt(2))


full = {}
for name, (off_dir, clean_dir) in MODELS.items():
    off, clean = load(off_dir), load(clean_dir)
    est = {k: (off.get(k) if c == "Language_Instructions" else clean.get(k)) for k, c in cat.items()}
    full[name] = {k: v for k, v in est.items() if v is not None}
    n_aff = sum(1 for k, c in cat.items() if c != "Language_Instructions")
    n_clean = sum(1 for k, c in cat.items() if c != "Language_Instructions" and k in clean)
    print(f"{name}: official {len(off)}/{len(cat)} tasks, clean {n_clean}/{n_aff} affected tasks"
          + ("" if n_clean == n_aff else "  ** INCOMPLETE: numbers below are partial **"))

print("\nFull-benchmark estimate, clean instructions (Language official), success %:")
print("| Model | " + " | ".join(SHORT) + " | All | n |")
print("|---" * (len(SHORT) + 3) + "|")
for name, res in full.items():
    cells = []
    for c in CATS:
        ks = [k for k in res if cat[k] == c]
        cells.append(f"{100 * sum(res[k] for k in ks) / len(ks):.1f}" if ks else "-")
    cells.append(f"{100 * sum(res.values()) / len(res):.1f}" if res else "-")
    print(f"| {name} | " + " | ".join(cells) + f" | {len(res)} |")

a, b = full["OFT+"], full["TurboVLA fine-tuned"]
both = [k for k in a if k in b]
print(f"\nPaired, TurboVLA fine-tuned vs OFT+ on {len(both)} tasks both have (clean estimate):")
for c in CATS + ["all"]:
    ks = [k for k in both if c == "all" or cat[k] == c]
    if not ks:
        continue
    oft_only = sum(1 for k in ks if a[k] and not b[k])
    tv_only = sum(1 for k in ks if b[k] and not a[k])
    z, p = mcnemar(oft_only, tv_only)
    ra, rb = (100 * sum(d[k] for k in ks) / len(ks) for d in (a, b))
    print(f"  {c:22s} n={len(ks):5d}  OFT+ {ra:5.1f}  TurboVLA {rb:5.1f}  diff {rb - ra:+5.1f}  "
          f"flips OFT+only/TVonly {oft_only}/{tv_only}  p={p:.2g}")
