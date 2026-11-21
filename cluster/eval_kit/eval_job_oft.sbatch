#!/bin/bash
# OpenVLA-OFT variant of eval_job.sbatch. A 7B model needs ~16.5 GB of an A30, so instead of one model per worker it
# runs ONE model server per GPU (openvla-oft experiments/robot/libero/oft_libero_server.py, OFT's own pre/post-
# processing) and the kit's usual CPU env workers query it through adapters/openvla_oft.py. Episode protocol, plan,
# results files, watchdog and deadline handling are the unchanged kit (eval_job.sbatch / run_plan.sh / eval_tasks.py).
#   OFT_CKPT=/scratch/$USER/ckpts/oftplus sbatch eval_job_oft.sbatch
#   two GPUs on one plan:  OFT_CKPT=... TOTAL_WORKERS=16 WORKER_OFFSET=0|8 sbatch eval_job_oft.sbatch
#   extra server flags, e.g. per-suite norm stats: OFT_SERVER_ARGS="--unnorm_key libero_goal"
#   (passed to the server; /health then also reports the per-layer keep frequency and mean executed layers)
# config.sh must set LP_EXEC to the OFT container (~/oft_container/oft-exec.sh) and
# ADAPTER=adapters.openvla_oft:OpenVLAOFTAdapter.
#SBATCH --job-name=lp-eval-oft
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --gres=gpu:1
#SBATCH --time=24:00:00
#SBATCH --output=eval_job_oft_%j.log
#SBATCH --mail-type=FAIL,END

set -u
cd "$SLURM_SUBMIT_DIR"
source ./config.sh
: "${OFT_CKPT:?set OFT_CKPT to the OpenVLA-OFT checkpoint directory}"
OFT_CODE=${OFT_CODE:-$HOME/turing-vla/openvla-oft}
PORT=$((8700 + SLURM_JOB_ID % 250))          # per job, in case two eval jobs share a node
export OFT_SERVER_URL=http://127.0.0.1:$PORT

echo "[$(date)] starting OFT server for $OFT_CKPT ${OFT_SERVER_ARGS:-} on port $PORT"
"$LP_EXEC" python -u "$OFT_CODE/experiments/robot/libero/oft_libero_server.py" \
  --pretrained_checkpoint "$OFT_CKPT" --port "$PORT" ${OFT_SERVER_ARGS:-} > "server_${SLURM_JOB_ID}.log" 2>&1 &
SERVER=$!
for i in $(seq 1 180); do
  curl -sf "$OFT_SERVER_URL/health" > /dev/null && break
  kill -0 $SERVER 2>/dev/null || { echo "server exited during startup:"; tail -n 30 "server_${SLURM_JOB_ID}.log"; exit 1; }
  sleep 5
done
curl -sf "$OFT_SERVER_URL/health" > /dev/null || { echo "server not healthy after 15 min"; kill $SERVER; exit 1; }
echo "[$(date)] server healthy"

nvidia-smi --query-gpu=timestamp,memory.used,utilization.gpu --format=csv,noheader -l 30 > "gpu_${SLURM_JOB_ID}.csv" &
SMI=$!
bash eval_job.sbatch          # workers (inherit OFT_SERVER_URL); writes eval_job output to stdout of this job
RC=$?
echo "[$(date)] server answered $(curl -sf "$OFT_SERVER_URL/health")"
kill $SMI $SERVER 2>/dev/null
wait $SERVER 2>/dev/null
exit $RC
