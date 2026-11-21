#!/usr/bin/env bash
# Run the remaining tasks in plan.tsv order with a hang watchdog.
#   run_plan.sh [STOP_AT]        e.g.  run_plan.sh 09:00
# Results go to results.jsonl as each task finishes, so stopping at any point loses at most the task
# in progress. If no task finishes for STALL_MIN minutes, the evaluator is killed, the task is recorded
# as hung (retried once, then skipped), and the evaluator restarts. A crash mid-task is treated the same.
# Exit codes: 0 plan finished, 3 stopped (STOP_AT or stop.sh), 4 already running, 5 evaluator keeps crashing.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/config.sh"
STOP_AT=${1:-}

# MuJoCo < 3.2 leaks a file handle per mesh file (thousands per LIBERO-Plus Objects Layout scene); raising the soft
# limit to the hard limit is a harmless safety net (the Turing image uses mujoco 3.2.0, which does not leak).
ulimit -n "$(ulimit -Hn)"

# Parallel workers (eval_job.sbatch sets WORKER / NWORKERS): each worker has its own lock, progress, results and log.
export WORKER=${WORKER:-0} NWORKERS=${NWORKERS:-1}
SUF=""; [ "$NWORKERS" -gt 1 ] && SUF=".$WORKER"
CURRENT="$HERE/current$SUF.json"; RESULTS="$HERE/results$SUF.jsonl"; LOG="$HERE/eval$SUF.log"

exec 9> "$HERE/.run$SUF.lock"
flock -n 9 || { echo "[$(date)] another evaluation is already running"; exit 4; }
rm -f "$HERE/STOP"  # a stop request only applies to the run that was active when it was made

DEADLINE_ARGS=()
if [ -n "$STOP_AT" ]; then
  DEADLINE=$(date -d "$STOP_AT" +%s) || exit 1
  [ "$DEADLINE" -le "$(date +%s)" ] && DEADLINE=$((DEADLINE + 86400))
  DEADLINE_ARGS=(--deadline "$DEADLINE")
  echo "[$(date)] running until $(date -d "@$DEADLINE")"
fi

mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }
current_task() { python3 -c "import json; c = json.load(open('$CURRENT')); print(c['suite'], c['task_id'])" 2>/dev/null; }
record_hang() {  # suite task_id [error]
  printf '{"suite": "%s", "task_id": %d, "hung": true, "error": "%s", "time": "%s"}\n' "$1" "$2" "${3:-}" "$(date '+%F %T')" >> "$RESULTS"
}

CRASHES=0
while true; do
  [ -f "$HERE/STOP" ] && { echo "[$(date)] stopped on request (stop.sh)"; exit 3; }
  LAUNCH=$(date +%s)
  (cd "$HERE" && "$PY" eval_tasks.py "${DEADLINE_ARGS[@]}") >> "$LOG" 2>&1 &
  PID=$!
  STALLED=0
  while kill -0 "$PID" 2>/dev/null; do
    sleep 30
    LAST=$(printf "%s\n" "$LAUNCH" "$(mtime "$CURRENT")" "$(mtime "$RESULTS")" | sort -n | tail -1)
    if [ $(( $(date +%s) - LAST )) -ge $((STALL_MIN * 60)) ]; then
      STALLED=1
      TASK=$(current_task)
      echo "[$(date)] no progress for $STALL_MIN min (task: ${TASK:-unknown}); killing evaluator"
      kill "$PID"; sleep 10; kill -9 "$PID" 2>/dev/null
      [ -n "$TASK" ] && record_hang $TASK "stall"
      rm -f "$CURRENT"
    fi
  done
  wait "$PID"; STATUS=$?
  [ "$STALLED" -eq 1 ] && { CRASHES=0; continue; }
  if [ "$STATUS" -ne 0 ] && [ "$STATUS" -ne 2 ] && [ "$STATUS" -ne 3 ] && [ -f "$CURRENT" ]; then
    TASK=$(current_task)
    echo "[$(date)] evaluator crashed with $STATUS during task ${TASK:-unknown}; restarting"
    [ -n "$TASK" ] && record_hang $TASK "crash $STATUS"
    rm -f "$CURRENT"; CRASHES=0; continue
  fi
  case "$STATUS" in
    0) echo "[$(date)] plan finished"; exit 0 ;;
    2) CRASHES=0; continue ;;  # evaluator restarted itself to release leaked file handles
    3) if [ -f "$HERE/STOP" ]; then echo "[$(date)] stopped on request (stop.sh)"; else echo "[$(date)] stopped for the stop time"; fi
       exit 3 ;;
    *) CRASHES=$((CRASHES + 1)); echo "[$(date)] evaluator exited with $STATUS (crash $CRASHES)"
       [ "$CRASHES" -ge 3 ] && { echo "[$(date)] giving up after 3 crashes; see $LOG"; exit 5; }
       sleep 30 ;;
  esac
done
