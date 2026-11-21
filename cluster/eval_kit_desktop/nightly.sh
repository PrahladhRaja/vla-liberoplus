#!/usr/bin/env bash
# Nightly driver: works through plan.tsv between WINDOW_START and WINDOW_END (config.sh).
# Started by the Windows task (schedule.sh) or by hand; exits at once outside the window or if an
# evaluation is already running. Log: nightly.log.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/config.sh"
exec >> "$HERE/nightly.log" 2>&1

now=$(date +%s)
if [ "$now" -lt "$(date -d "$WINDOW_START" +%s)" ] || [ "$now" -ge "$(date -d "$WINDOW_END" +%s)" ]; then
  echo "[$(date)] outside the $WINDOW_START-$WINDOW_END window; not starting"
  exit 0
fi
if ! flock -n "$HERE/.run.lock" true; then
  echo "[$(date)] an evaluation is already running; not starting"
  exit 0
fi

echo "[$(date)] nightly run starting; stop by $WINDOW_END"
"$HERE/run_plan.sh" "$WINDOW_END"
STATUS=$?
echo "[$(date)] run_plan.sh exited with $STATUS"
(cd "$HERE" && "$PY" summarize.py > /dev/null)
echo "[$(date)] nightly run finished"
