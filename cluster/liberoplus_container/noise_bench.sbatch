#!/bin/bash
# CPU benchmark of LIBERO-Plus sensor-noise filters on a Turing node (no GPU needed).
#   A) thread settings with 4 cores (like the earlier eval job): default vs capped to 1 / 4 threads
#   B) parallel scaling: 1, 4, 8, 16 single-core workers running the glass + zoom filters at once
#   sbatch noise_bench.sbatch          (run from this directory)
#SBATCH --job-name=lp-noise
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=16G
#SBATCH --time=00:20:00
#SBATCH --output=noise_bench_%j.log

set -u
cd "$SLURM_SUBMIT_DIR"
# No GPU in this job: MuJoCo initializes EGL on import, so use the Mesa (CPU) EGL vendor. Nothing is rendered.
export LP_EGL_VENDOR=/usr/share/glvnd/egl_vendor.d/50_mesa.json
CORES=($(python3 -c "import os; print(*sorted(os.sched_getaffinity(0)))"))
echo "allocated cores: ${CORES[*]}"
run() {  # print result lines; on failure, the last lines of output
  local out; out=$(./lp-exec.sh python -u noise_bench.py "$@" 2>&1)
  grep '^\[' <<< "$out" | grep -v 'robosuite WARNING' || tail -n 5 <<< "$out"
}

echo "### A: 4 cores, thread settings"
taskset -c "${CORES[0]},${CORES[1]},${CORES[2]},${CORES[3]}" bash -c "$(declare -f run); run 4cores-default"
OMP_NUM_THREADS=1 MAGICK_THREAD_LIMIT=1 OPENBLAS_NUM_THREADS=1 \
  taskset -c "${CORES[0]},${CORES[1]},${CORES[2]},${CORES[3]}" bash -c "$(declare -f run); run 4cores-1thread"
OMP_NUM_THREADS=4 MAGICK_THREAD_LIMIT=4 OPENBLAS_NUM_THREADS=4 \
  taskset -c "${CORES[0]},${CORES[1]},${CORES[2]},${CORES[3]}" bash -c "$(declare -f run); run 4cores-4threads"

echo "### B: parallel single-core workers (glass + zoom)"
for k in 1 4 8 16; do
  for ((i = 0; i < k; i++)); do
    OMP_NUM_THREADS=1 MAGICK_THREAD_LIMIT=1 OPENBLAS_NUM_THREADS=1 \
      taskset -c "${CORES[$i]}" bash -c "$(declare -f run); run par$k-w$i glass,zoom" &
  done
  wait
done
echo "### done"
