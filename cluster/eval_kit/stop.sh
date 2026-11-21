#!/usr/bin/env bash
# Stop a running evaluation cleanly: every worker finishes the task in progress (up to a few min) and exits.
# Nothing is lost; the next eval_job.sbatch continues where it stopped.
HERE=$(cd "$(dirname "$0")" && pwd)
any_running() {
  for lock in "$HERE"/.run*.lock; do
    [ -e "$lock" ] || continue
    flock -n "$lock" true || return 0
  done
  return 1
}
if ! any_running; then
  echo "No evaluation is running."; exit 0
fi
touch "$HERE/STOP"
echo "Stop requested; waiting for the workers' current tasks to finish..."
for _ in $(seq 1 120); do
  if ! any_running; then
    rm -f "$HERE/STOP"; echo "Stopped."; exit 0
  fi
  sleep 5
done
echo "Still running after 10 minutes (a task may be hung; the watchdog ends it within STALL_MIN of the hang)."
echo "The stop request stays in place, so workers stop as soon as their tasks end."
exit 1
