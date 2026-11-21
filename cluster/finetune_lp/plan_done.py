"""Is an eval-kit run finished? Prints "<finished>/<plan rows> (<skipped> skipped)"; exit code 0 when every plan row has
a result or was skipped after two hangs, else 1.
    python3 plan_done.py <eval dir>
"""

import collections
import glob
import json
import sys

d = sys.argv[1]
plan = {(s, int(t)) for s, t in (l.split("\t")[1:3] for l in open(f"{d}/plan.tsv") if not l.startswith("#"))}
done, hung = set(), collections.Counter()
for path in glob.glob(f"{d}/results*.jsonl"):
    for line in open(path):
        r = json.loads(line)
        key = (r["suite"], r["task_id"])
        if r.get("hung"):
            hung[key] += 1
        else:
            done.add(key)
skipped = {k for k, n in hung.items() if n >= 2} - done
finished = (done | skipped) & plan
print(f"{len(finished)}/{len(plan)} ({len(skipped & plan)} skipped)")
sys.exit(0 if len(finished) == len(plan) else 1)
