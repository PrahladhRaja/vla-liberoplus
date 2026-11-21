"""Write plan.tsv: the order in which the 10,030 LIBERO-Plus tasks are evaluated.

Every (suite, category) cell is visited round-robin, one task per cell per round, with tasks drawn in
random order within each cell. Stopping at any point therefore leaves every cell with about the same
number of random-sample episodes, which summarize.py turns into unbiased estimates; running to the end
covers every task.

plan.tsv columns: order, suite, task_id, category, round. Rows with round -1 are "block" rows, evaluated
in full before sampling starts and counted exactly (used by reference/paired_plan.tsv).

The plan must not change once an evaluation has started, so this refuses to overwrite plan.tsv.

    python make_plan.py [--seed 0]
"""

import argparse
import json
import random
import sys

import kitconfig

SUITES = ["libero_spatial", "libero_object", "libero_goal", "libero_10"]

parser = argparse.ArgumentParser()
parser.add_argument("--seed", type=int, default=0)
args = parser.parse_args()

kitconfig.load()
plan_path = kitconfig.KIT / "plan.tsv"
if plan_path.exists():
    sys.exit(f"{plan_path} already exists; not overwriting")

classification = json.load(open(kitconfig.classification_path()))
rng = random.Random(args.seed)
cells = {}
for suite in SUITES:
    for item in classification[suite]:
        cells.setdefault((suite, item["category"]), []).append(item["id"] - 1)
for tasks in cells.values():
    rng.shuffle(tasks)

rows, round_no = [], 0
while any(cells.values()):
    order = [key for key, tasks in cells.items() if tasks]
    rng.shuffle(order)
    for suite, category in order:
        rows.append((suite, cells[(suite, category)].pop(), category, round_no))
    round_no += 1

with open(plan_path, "w") as f:
    f.write("# order\tsuite\ttask_id\tcategory\tround\n")
    for i, (suite, task_id, category, r) in enumerate(rows):
        f.write(f"{i}\t{suite}\t{task_id}\t{category.replace(' ', '_')}\t{r}\n")
print(f"wrote {plan_path}: {len(rows)} tasks, {len(cells)} cells, {round_no} rounds")
