#!/bin/bash
# Stage 6: full LIBERO-Plus evaluation of the fine-tuned model (EMA weights of $WORK/final.pth) with the eval kit, in
# the same task order as the baseline (~/lp_eval_full/plan.tsv). Submitted twice (WORKER_OFFSET=0 and 8 of 16 workers,
# one GPU each), like the baseline run. The first job to start creates ~/lp_eval_ft. Near the time limit the workers
# stop cleanly (eval kit) and the job requeues itself (at most twice). Succeeds when the whole plan is finished.
#SBATCH --job-name=ft-s6-eval
#SBATCH --partition=academic
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --gres=gpu:1
#SBATCH --time=09:00:00
#SBATCH --output=logs/%x_%j.log
#SBATCH --open-mode=append
#SBATCH --requeue
#SBATCH --mail-type=FAIL,REQUEUE

set -uo pipefail
source "$HOME/finetune_lp/common.sh"
plog "started on $(hostname) (restart ${SLURM_RESTART_COUNT:-0}), workers from ${WORKER_OFFSET} of ${TOTAL_WORKERS}"
[ -e "$WORK/final.pth" ] || fail "no fine-tuned checkpoint at $WORK/final.pth"

(
  flock 9
  if [ ! -f "$FT_EVAL/plan.tsv" ]; then
    mkdir -p "$FT_EVAL"
    cp -r "$KIT"/. "$FT_EVAL"/
    rm -rf "$FT_EVAL/videos" "$FT_EVAL/__pycache__"
    mkdir -p "/scratch/$USER/lp_eval_ft_videos" && ln -sfn "/scratch/$USER/lp_eval_ft_videos" "$FT_EVAL/videos"
    cp "$BASE_EVAL/plan.tsv" "$FT_EVAL/plan.tsv"
    plog "created $FT_EVAL (kit copy, baseline plan.tsv)"
  fi
) 9> "$FT/.eval_setup.lock"

cd "$FT_EVAL"
export TURBOVLA_CKPT=$(readlink -f "$WORK/final.pth") SLURM_SUBMIT_DIR=$FT_EVAL
bash eval_job.sbatch > "eval_job_${SLURM_JOB_ID}_r${SLURM_RESTART_COUNT:-0}.log" 2>&1

if state=$(python3 "$FT/plan_done.py" "$FT_EVAL"); then plog "OK: evaluation complete: $state"; exit 0; fi
# Plan not finished: either the other job still has tasks, or time ran out. This job's share is done when none of
# its workers' rows are left; otherwise requeue.
left=$(python3 - "$FT_EVAL" "$WORKER_OFFSET" "$TOTAL_WORKERS" <<'EOF'
import glob, json, sys, collections
d, off, tot = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rows = [l.split("\t") for l in open(f"{d}/plan.tsv") if not l.startswith("#")]
done, hung = set(), collections.Counter()
for p in glob.glob(f"{d}/results*.jsonl"):
    for line in open(p):
        r = json.loads(line); k = (r["suite"], r["task_id"])
        (hung.update([k]) if r.get("hung") else done.add(k))
mine = [(r[1], int(r[2])) for i, r in enumerate(rows) if off <= i % tot < off + 8]
print(sum(1 for k in mine if k not in done and hung[k] < 2))
EOF
)
if [ "$left" -eq 0 ]; then plog "OK: this job's share is finished; overall $state"; exit 0; fi
if [ "${SLURM_RESTART_COUNT:-0}" -lt "$MAX_REQUEUES" ]; then
  plog "$left of this job's tasks left (overall $state): requeueing"
  scontrol requeue "$SLURM_JOB_ID"; exit 0
fi
fail "$left of this job's tasks left after $MAX_REQUEUES requeues (overall $state)"
