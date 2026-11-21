#!/usr/bin/env bash
# Stop a running evaluation cleanly: it finishes the task in progress (up to ~2-3 min) and exits.
# Nothing is lost; the next run (nightly or start_plan.sh) continues where it stopped.
# This does not pause the schedule; for that use: schedule.sh pause
HERE=$(cd "$(dirname "$0")" && pwd)
if flock -n "$HERE/.run.lock" true; then
  echo "No evaluation is running."; exit 0
fi
touch "$HERE/STOP"
echo "Stop requested; waiting for the current task to finish..."
for _ in $(seq 1 120); do
  if flock -n "$HERE/.run.lock" true; then
    rm -f "$HERE/STOP"; echo "Stopped."; exit 0
  fi
  sleep 5
done
echo "Still running after 10 minutes (the task may be hung; the watchdog will end it within 15 min of the hang)."
echo "The stop request stays in place, so it will stop as soon as that task ends."
exit 1
