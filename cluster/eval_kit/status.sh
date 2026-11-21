#!/usr/bin/env bash
# Show whether the evaluation is running (per worker), progress through plan.tsv, and results so far.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/config.sh"
cd "$HERE"
RUNNING=0
for lock in .run*.lock; do
  [ -e "$lock" ] || continue
  flock -n "$lock" true && continue
  RUNNING=$((RUNNING + 1))
  suf=${lock#.run}; suf=${suf%.lock}             # "" or ".<k>"
  CUR=$(python3 -c "import json, time; c = json.load(open('current$suf.json')); print(f\"{c['suite']} task {c['task_id']} (started {time.strftime('%H:%M:%S', time.localtime(c['started']))})\")" 2>/dev/null)
  k=${suf#.}; echo "Worker ${k:-0}: running${CUR:+, on $CUR}"
done
[ "$RUNNING" -eq 0 ] && echo "Status: not running" || echo "Status: $RUNNING worker(s) running"
[ -f STOP ] && echo "Stop requested (stop.sh); workers stop after their current task"
if compgen -G "results*.jsonl" > /dev/null && [ -f plan.tsv ]; then
  python3 - <<'EOF'
import glob, json
recs = [json.loads(l) for f in sorted(glob.glob("results*.jsonl")) for l in open(f)]
ok = sorted((r for r in recs if not r.get("hung")), key=lambda r: r["time"])
plan = sum(1 for l in open("plan.tsv") if not l.startswith("#"))
line = f"Plan: {len({(r['suite'], r['task_id']) for r in ok})}/{plan} tasks done"
if ok:
    line += f"; last finished {ok[-1]['time']}; avg {sum(r['seconds'] for r in ok[-50:]) / len(ok[-50:]):.0f} s/task per worker (last 50)"
print(line)
EOF
fi
echo
python3 summarize.py | sed -n '1,20p'
