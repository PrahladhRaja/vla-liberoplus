"""Detailed paired analysis of released vs fine-tuned TurboVLA on LIBERO-Plus (same 10,030 tasks, Turing).

    python3 analyze_lp_ft.py <baseline eval dir> <fine-tuned eval dir> [out.md]
"""

import collections
import glob
import json
import math
import os
import sys

CLS = os.path.expanduser("~/LIBERO-plus/libero/libero/benchmark/task_classification.json")
BDDL = os.path.expanduser("~/LIBERO/libero/libero/bddl_files")
SUITES = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]
CATS = ["Camera Viewpoints", "Robot Initial States", "Language Instructions", "Light Conditions",
        "Background Textures", "Sensor Noise", "Objects Layout"]
SHORT = dict(zip(CATS, ["Camera", "Robot", "Language", "Light", "Background", "Noise", "Layout"]))

info = {(s, it["id"] - 1): it for s, items in json.load(open(CLS)).items() for it in items}
base_names = {s: sorted((os.path.basename(p)[:-5] for p in glob.glob(f"{BDDL}/{s}/*.bddl")), key=len, reverse=True)
              for s in SUITES}


def base_task(suite, name):
    for b in base_names[suite]:
        if name == b or name.startswith(b + "_"):
            return b
    return None


def load(d):
    out, secs = {}, {}
    for p in glob.glob(f"{d}/results*.jsonl"):
        for line in open(p):
            r = json.loads(line)
            if not r.get("hung"):
                out[(r["suite"], r["task_id"])] = r["success"]
                secs[(r["suite"], r["task_id"])] = r["seconds"]
    return out, secs


B, Bs = load(sys.argv[1])
F, Fs = load(sys.argv[2])
keys = sorted(set(B) & set(F))
L = []


def stats(ks):
    n = len(ks)
    a = sum(B[k] for k in ks) / n
    f = sum(F[k] for k in ks) / n
    d = [F[k] - B[k] for k in ks]
    md = sum(d) / n
    sd = math.sqrt(sum((x - md) ** 2 for x in d) / max(1, n - 1))
    return n, 100 * a, 100 * f, 100 * md, 196 * sd / math.sqrt(n)


n, a, f, md, ci = stats(keys)
L.append("# TurboVLA on LIBERO-Plus: released vs fine-tuned (detailed, paired)\n")
L.append(f"All {n} tasks: **{a:.1f}% → {f:.1f}%**, Δ = {md:+.1f} points (95% CI ±{ci:.1f}). "
         f"Solved by both {sum(B[k] and F[k] for k in keys)}, neither {sum(not B[k] and not F[k] for k in keys)}, "
         f"baseline only {sum(B[k] and not F[k] for k in keys)}, fine-tuned only {sum(F[k] and not B[k] for k in keys)}.\n")

L.append("## By category and difficulty level (success %, baseline → fine-tuned)\n")
L.append("| Category | L1 | L2 | L3 | L4 | L5 | all (Δ ± 95% CI) |\n|---|---|---|---|---|---|---|")
for c in CATS:
    cells = []
    for lvl in range(1, 6):
        ks = [k for k in keys if info[k]["category"] == c and info[k]["difficulty_level"] == lvl]
        cells.append(f"{stats(ks)[1]:.0f}→{stats(ks)[2]:.0f} <sub>n={len(ks)}</sub>" if ks else "–")
    ks = [k for k in keys if info[k]["category"] == c]
    _, a, f, md, ci = stats(ks)
    L.append(f"| {SHORT[c]} | " + " | ".join(cells) + f" | {a:.1f}→{f:.1f} ({md:+.1f} ±{ci:.1f}) |")
cells = []
for lvl in range(1, 6):
    ks = [k for k in keys if info[k]["difficulty_level"] == lvl]
    cells.append(f"{stats(ks)[1]:.0f}→{stats(ks)[2]:.0f}")
L.append("| **all** | " + " | ".join(cells) + f" | {stats(keys)[1]:.1f}→{stats(keys)[2]:.1f} |")
nolvl = [k for k in keys if info[k]["difficulty_level"] is None]
if nolvl:
    L.append(f"\n({len(nolvl)} tasks have no difficulty level; included in 'all'.)")

L.append("\n## By original LIBERO task (all perturbations of it), sorted by gain\n")
L.append("| Suite | Original task | tasks | baseline | fine-tuned | Δ |\n|---|---|---|---|---|---|")
groups = collections.defaultdict(list)
unmapped = 0
for k in keys:
    b = base_task(k[0], info[k]["name"])
    if b is None:
        unmapped += 1
    else:
        groups[(k[0], b)].append(k)
rows = []
for (s, b), ks in groups.items():
    _, a, f, md, _ = stats(ks)
    rows.append((md, s, b, len(ks), a, f))
for md, s, b, nk, a, f in sorted(rows, reverse=True):
    short = b.split("SCENE", 1)[-1].split("_", 1)[-1] if "SCENE" in b else b
    L.append(f"| {s.replace('libero_', '')} | {short.replace('_', ' ')} | {nk} | {a:.1f} | {f:.1f} | {md:+.1f} |")
if unmapped:
    L.append(f"\n({unmapped} tasks could not be matched to an original task.)")

L.append("\n## Where the fine-tuned model still fails most (suite × category, fine-tuned success %)\n")
worst = []
for s in SUITES:
    for c in CATS:
        ks = [k for k in keys if k[0] == s and info[k]["category"] == c]
        _, a, f, md, _ = stats(ks)
        worst.append((f, s, c, a, len(ks)))
L.append("| Suite | Category | tasks | baseline | fine-tuned |\n|---|---|---|---|---|")
for f, s, c, a, nk in sorted(worst)[:8]:
    L.append(f"| {s} | {SHORT[c]} | {nk} | {a:.1f} | {f:.1f} |")

L.append("\n## Regressions (solved by the baseline, not by the fine-tuned model)\n")
reg = [k for k in keys if B[k] and not F[k]]
by = collections.Counter((k[0], SHORT[info[k]["category"]]) for k in reg)
L.append(f"{len(reg)} tasks ({100 * len(reg) / len(keys):.1f}% of all). Largest groups: " +
         ", ".join(f"{s.replace('libero_', '')}/{c} {m}" for (s, c), m in by.most_common(6)) + ".")

L.append("\n## Episode time (seconds per task, mean)\n")
L.append("| | baseline | fine-tuned |\n|---|---|---|")
for label, ks in [("all", keys), ("successes (each run's own)", None), ("Sensor Noise", [k for k in keys if info[k]["category"] == "Sensor Noise"])]:
    if ks is None:
        bs = [Bs[k] for k in keys if B[k]]
        fs = [Fs[k] for k in keys if F[k]]
    else:
        bs = [Bs[k] for k in ks]
        fs = [Fs[k] for k in ks]
    L.append(f"| {label} | {sum(bs) / len(bs):.1f} | {sum(fs) / len(fs):.1f} |")
L.append(f"| total worker-hours | {sum(Bs[k] for k in keys) / 3600:.1f} | {sum(Fs[k] for k in keys) / 3600:.1f} |")

text = "\n".join(L)
print(text)
if len(sys.argv) > 3:
    open(sys.argv[3], "w").write(text + "\n")
