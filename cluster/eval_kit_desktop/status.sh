#!/usr/bin/env bash
# Show whether the evaluation is running, progress through plan.tsv, and results so far.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/config.sh"
cd "$HERE"
if flock -n .run.lock true; then
  echo "Status: not running"
else
  CUR=$("$PY" -c "import json, time; c = json.load(open('current.json')); print(f\"{c['suite']} task {c['task_id']} (started {time.strftime('%H:%M:%S', time.localtime(c['started']))})\")" 2>/dev/null)
  echo "Status: running${CUR:+, on $CUR}"
fi
[ -f STOP ] && echo "Stop requested (stop.sh); stopping after the current task"
command -v powershell.exe > /dev/null && echo "Schedule: $(./schedule.sh status | sed 's/^State: Disabled/State: PAUSED (schedule.sh resume)/')"
if [ -f results.jsonl ] && [ -f plan.tsv ]; then
  "$PY" - <<'EOF'
import json
recs = [json.loads(l) for l in open("results.jsonl")]
ok = [r for r in recs if not r.get("hung")]
plan = sum(1 for l in open("plan.tsv") if not l.startswith("#"))
line = f"Plan: {len(ok)}/{plan} tasks done"
if ok:
    line += f"; last finished {ok[-1]['time']}; avg {sum(r['seconds'] for r in ok[-50:]) / len(ok[-50:]):.0f} s/task (last 50)"
print(line)
EOF
fi
echo
"$PY" summarize.py | sed -n '1,20p'
