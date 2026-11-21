#!/usr/bin/env bash
# Start the plan runner by hand, detached from the terminal (e.g. for extra daytime runs).
#   start_plan.sh [STOP_AT]     e.g.  start_plan.sh 18:00
HERE=$(cd "$(dirname "$0")" && pwd)
if ! flock -n "$HERE/.run.lock" true; then
  echo "An evaluation is already running; check with $HERE/status.sh"; exit 1
fi
setsid nohup "$HERE/run_plan.sh" "$@" >> "$HERE/manual.log" 2>&1 < /dev/null &
echo "Started (log: $HERE/manual.log, evaluator output: $HERE/eval.log). Check progress with: $HERE/status.sh"
