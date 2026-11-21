#!/bin/bash
# Run the evaluation plan (plan.tsv) with several parallel workers sharing one GPU, until the job's time limit.
# Worker k of N takes plan rows k, k+N, ...; results go to results.<k>.jsonl as each task finishes.
# Resubmit to continue where it stopped (any number of workers; finished tasks are skipped).
#   sbatch eval_job.sbatch                         (default: 16 CPUs -> 8 workers x 2 CPUs, up to 47 h)
#   sbatch --time=00:45:00 eval_job.sbatch         (short run)
#   Two GPUs at once (your academic max), one plan: workers 0-7 and 8-15 of 16 in two jobs:
#     TOTAL_WORKERS=16 WORKER_OFFSET=0 sbatch eval_job.sbatch
#     TOTAL_WORKERS=16 WORKER_OFFSET=8 sbatch eval_job.sbatch
# Measured (TurboVLA, A30 + 16 CPUs on Xeon Gold 6342 = 8 physical cores): 8 workers x 2 CPUs gave ~7.3x the
# throughput of 1 worker with identical outcomes; 16 single-CPU workers gain nothing (hyperthreads share a core).
# Why workers: TurboVLA uses ~1 GB of an A30 and episodes are mostly CPU-bound (physics, LIBERO-Plus noise filters),
# so one process per GPU leaves the GPU idle. Each worker needs ~3-4 GB RAM.
#SBATCH --job-name=lp-eval
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --gres=gpu:1
#SBATCH --time=47:00:00
#SBATCH --output=eval_job_%j.log

set -u
cd "$SLURM_SUBMIT_DIR"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader

CPW=${CPUS_PER_WORKER:-2}
NW=${NWORKERS:-$(( SLURM_CPUS_PER_TASK / CPW ))}; [ "$NW" -ge 1 ] || NW=1
# Cap each worker's library threads to its CPUs (a safeguard; measured on Turing it makes no difference, since jobs
# only see their allocated cores).
export OMP_NUM_THREADS=$CPW MAGICK_THREAD_LIMIT=$CPW OPENBLAS_NUM_THREADS=$CPW MKL_NUM_THREADS=$CPW

# Stop starting new tasks STOP_MARGIN_MIN minutes before the job's time limit (squeue %L: [D-]HH:MM:SS or MM:SS).
LEFT=$(squeue -h -j "$SLURM_JOB_ID" -o %L)
SECS=$(awk -F'[-:]' '{n=NF; s=$n+$(n-1)*60; if (n>=3) s+=$(n-2)*3600; if (n>=4) s+=$1*86400; print s}' <<< "$LEFT")
STOP=$(( $(date +%s) + SECS - ${STOP_MARGIN_MIN:-10} * 60 ))
echo "[$(date)] job $SLURM_JOB_ID on $(hostname): workers ${WORKER_OFFSET:-0}..$(( ${WORKER_OFFSET:-0} + NW - 1 )) of ${TOTAL_WORKERS:-$NW}, $CPW CPUs each; time left $LEFT; no new tasks after $(date -d "@$STOP")"

PIDS=()
TOTAL=${TOTAL_WORKERS:-$NW}; OFFSET=${WORKER_OFFSET:-0}
for ((k = 0; k < NW; k++)); do
  WORKER=$((OFFSET + k)) NWORKERS=$TOTAL ./run_plan.sh "@$STOP" > "run_plan.$((OFFSET + k)).out" 2>&1 &
  PIDS+=($!)
  sleep 5   # stagger model loading
done
RCS=()
for pid in "${PIDS[@]}"; do wait "$pid"; RCS+=($?); done
python3 summarize.py > /dev/null
echo "[$(date)] worker exit codes: ${RCS[*]} (0 = plan finished, 3 = stopped for the time limit)"
for rc in "${RCS[@]}"; do case $rc in 0|3) ;; *) exit "$rc" ;; esac; done
exit 0
