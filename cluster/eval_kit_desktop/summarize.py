"""Summarize results.jsonl as a LIBERO-Plus leaderboard table, with estimates for unfinished cells.

plan.tsv rows with round -1 ("block" rows) are counted exactly; all other evaluated tasks are a random
sample of their cell's non-block tasks. For a (suite, category) cell of N tasks with D block tasks and a
random sample S of the R = N - D others, the estimate is (successes in D + p_S * R) / N, with variance
(R/N)^2 * p_S (1 - p_S) / |S| * (1 - |S|/R). Categories, suites and the total are task-weighted
combinations of cells, which is how the LIBERO-Plus leaderboard aggregates. "±" is a 95% interval
(normal approximation); values without "±" are exact. Writes summary.txt.

    python summarize.py
"""

import collections
import json
import math

import kitconfig

kitconfig.load()
KIT = kitconfig.KIT
COLUMNS = ["Camera Viewpoints", "Robot Initial States", "Language Instructions", "Light Conditions",
           "Background Textures", "Sensor Noise", "Objects Layout"]
SHORT = ["Camera", "Robot", "Language", "Light", "Background", "Noise", "Layout"]
SUITES = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]

classification = json.load(open(kitconfig.classification_path()))
cell_of = {(s, it["id"] - 1): (s, it["category"]) for s, items in classification.items() for it in items}
level_of = {(s, it["id"] - 1): it["difficulty_level"] for s, items in classification.items() for it in items}
size = collections.Counter(cell_of.values())

block = set()
plan_path = KIT / "plan.tsv"
if plan_path.exists():
    for line in open(plan_path):
        if not line.startswith("#"):
            _, suite, task_id, _, round_no = line.rstrip("\n").split("\t")
            if int(round_no) < 0:
                block.add((suite, int(task_id)))

exact, sample, hung = {}, {}, collections.Counter()
results = KIT / "results.jsonl"
if results.exists():
    for line in open(results):
        rec = json.loads(line)
        key = (rec["suite"], rec["task_id"])
        if rec.get("hung"):
            hung[key] += 1
        else:
            (exact if key in block else sample)[key] = rec["success"]
skipped = {key for key, n in hung.items() if n >= 2 and key not in exact and key not in sample}


def cell_estimate(cell):
    """(estimate, variance, n_exact, n_sample); estimate is None when part of the cell has no data."""
    n = size[cell]
    block_n = sum(1 for k in block if cell_of[k] == cell)
    d = [v for k, v in exact.items() if cell_of[k] == cell]
    s = [v for k, v in sample.items() if cell_of[k] == cell]
    if len(d) < block_n:  # block rows not finished yet: no unbiased estimate
        return None, None, len(d), len(s)
    remaining = n - len(d)
    if remaining == 0 or len(s) == remaining:
        return (sum(d) + sum(s)) / n, 0.0, len(d), len(s)
    if not s:
        return None, None, len(d), 0
    p = sum(s) / len(s)
    est = (sum(d) + p * remaining) / n
    var = (remaining / n) ** 2 * p * (1 - p) / len(s) * max(0.0, 1 - len(s) / remaining)
    return est, var, len(d), len(s)


cells = {c: cell_estimate(c) for c in size}


def combine(keys):
    keys = list(keys)
    if any(cells[k][0] is None for k in keys):
        return None
    total = sum(size[k] for k in keys)
    return (sum(size[k] * cells[k][0] for k in keys) / total,
            sum((size[k] / total) ** 2 * cells[k][1] for k in keys))


def fmt(result, width=13):
    if result is None:
        return f"{'-':>{width}s}"
    est, var = result
    half = 1.96 * math.sqrt(var)
    text = f"{100 * est:.1f}" if half < 0.0005 else f"{100 * est:.1f}±{100 * half:.0f}"
    return f"{text:>{width}s}"


lines = [f"Tasks evaluated: {len(exact) + len(sample)}/{len(cell_of)}  ({len(exact)} block, {len(sample)} random-sample)"]
if hung:
    lines.append(f"Hangs/crashes recorded: {sum(hung.values())} on {len(hung)} tasks; {len(skipped)} tasks skipped after two")
lines += ["", "Success rate % (± = 95% CI; values without ± are exact)", ""]
lines.append(f"{'':16s}" + "".join(f"{s:>13s}" for s in SHORT) + f"{'Total':>13s}")
for suite in SUITES:
    row = [cells[(suite, c)][:2] if cells[(suite, c)][0] is not None else None for c in COLUMNS]
    lines.append(f"{suite:16s}" + "".join(fmt(r) for r in row) + fmt(combine((suite, c) for c in COLUMNS)))
lines.append(f"{'all suites':16s}" + "".join(fmt(combine((s, c) for s in SUITES)) for c in COLUMNS) + fmt(combine(size.keys())))
lines += ["", "Episodes per cell (evaluated / cell size):", ""]
lines.append(f"{'':16s}" + "".join(f"{s:>13s}" for s in SHORT))
for suite in SUITES:
    lines.append(f"{suite:16s}" + "".join(
        f"{f'{cells[(suite, c)][2] + cells[(suite, c)][3]}/{size[(suite, c)]}':>13s}" for c in COLUMNS))

by_level = collections.defaultdict(lambda: [0, 0])
for key, success in list(exact.items()) + list(sample.items()):
    bucket = by_level[(cell_of[key][1], level_of[key])]
    bucket[0] += success
    bucket[1] += 1
lines += ["", "By difficulty level, all evaluated tasks (unweighted; indicative only; L? = no level in LIBERO-Plus):"]
for c, s in zip(COLUMNS, SHORT):
    levels = sorted((lv for cat, lv in by_level if cat == c), key=lambda lv: (lv is None, lv or 0))
    lines.append(f"  {s:11s}" + "  ".join(
        f"L{'?' if lv is None else lv}: {100 * by_level[(c, lv)][0] / by_level[(c, lv)][1]:.0f}% (n={by_level[(c, lv)][1]})"
        for lv in levels))

text = "\n".join(lines)
print(text)
(KIT / "summary.txt").write_text(text + "\n")
