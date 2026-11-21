# Shared settings and helpers for the fine-tuning pipeline. Sourced by every stage script, status.sh and stop.sh.

FT=$HOME/finetune_lp                                   # this folder (scripts, logs, pipeline.log, jobs.env)
LPC=$HOME/liberoplus_container                         # LIBERO-Plus container scripts (lp-exec.sh)
LP_EXEC=$LPC/lp-exec.sh
SIF=/scratch/$USER/liberoplus/liberoplus.sif           # training/eval image (unchanged since the baseline run)
TOOLS_SIF=/scratch/$USER/finetune_lp/tools.sif         # small image with p7zip/zip/unzip (stage 1)
TV=$HOME/turing-vla/TurboVLA                           # TurboVLA checkout (pretrained/ -> scratch)
RELEASE_CKPT=$TV/pretrained/TurboVLA/checkpoints/libero/turbovla_libero.pth
STATS=$TV/experiments/libero/configs/libero_all4_stats.json
STATS_KEY=libero_all4_no_noops

DATA=/scratch/$USER/libero_plus_data                   # download + extraction area
DS_DIR=$DATA/libero_mix/1.0.0                          # the extracted TFDS dataset
DS_EPISODES=14347
WORK=/scratch/$USER/finetune_lp                        # checkpoints, smoke-test run
CKPT_DIR=$WORK/checkpoints
SMOKE_DIR=$WORK/smoke

BASE_EVAL=$HOME/lp_eval_full                           # baseline LIBERO-Plus eval (released model)
FT_EVAL=$HOME/lp_eval_ft                               # fine-tuned model's LIBERO-Plus eval
KIT=$HOME/turing_eval_kit

TARGET_STEPS=17500                                     # 1 epoch: 2.24M samples / 128
MAX_REQUEUES=2

# Log one line to pipeline.log (and the job's own log).
plog() {
  local line="[$(date '+%a %F %T')] ${SLURM_JOB_NAME:-login}(${SLURM_JOB_ID:-}) $*"
  echo "$line" >> "$FT/pipeline.log"
  echo "$line"
}

# Called from a SIGUSR1 trap shortly before the time limit (#SBATCH --signal=B:USR1@...). Requeues this job (same job
# ID, so later stages keep waiting on it) at most MAX_REQUEUES times; after that the stage fails. (Turing docs:
# "Auto Requeuing".)
requeue_or_fail() {
  local n=${SLURM_RESTART_COUNT:-0}
  if [ "$n" -lt "$MAX_REQUEUES" ]; then
    plog "time limit near: requeueing (requeue $((n + 1)) of $MAX_REQUEUES)"
    kill $(jobs -p) 2>/dev/null; sleep 20
    scontrol requeue "$SLURM_JOB_ID"
    exit 0
  fi
  plog "FAILED: time limit reached and already requeued $MAX_REQUEUES times"
  kill $(jobs -p) 2>/dev/null
  exit 1
}

fail() { plog "FAILED: $*"; exit 1; }

# Training command shared by the smoke test (stage 4) and the real run (stage 5); run it from $TV (the trainer's
# defaults are relative to the repo root). Args: checkpoint dir, max steps,
# save every N steps, seed. Starts from the newest <dir>/turbovla_step_<N>.pth: the released model linked as step 0
# (weights only, fresh optimizer) or a saved checkpoint (weights + optimizer + scheduler + step).
train_cmd() {
  local dir=$1 steps=$2 save=$3 seed=$4 mode=model
  ls "$dir"/turbovla_step_*.pth 2>/dev/null | grep -qv '_step_0.pth$' && mode=all
  echo torchrun --standalone --nproc_per_node=2 "$TV/experiments/libero/train.py" \
    --dataset_dir "$DS_DIR" --dataset_dirs "$DS_DIR" \
    --stats_path "$STATS" --stats_key "$STATS_KEY" \
    --text_layout_path "$TV/experiments/libero/configs/online_text_layout.json" \
    --dinov3_path "$TV/pretrained/dinov3-vitb16-pretrain-lvd1689m" \
    --bert_path "$TV/pretrained/bert-base-uncased" \
    --pretrained_init_ckpt "$RELEASE_CKPT" \
    --no_require_feature_enhancer_preload --no_load_text_projection_from_init --no_require_text_proj_preload \
    --checkpoint_dir "$dir" --resume_mode "$mode" \
    --batch_size 32 --grad_accum_steps 2 \
    --lr 5e-5 --warmup_steps 1000 --lr_schedule_steps "$TARGET_STEPS" --min_lr_ratio 1.0 \
    --dinov3_precision bf16_autocast --max_steps "$steps" --save_steps "$save" --seed "$seed" --num_workers 4
}

# Latest saved step in a checkpoint dir (0 if only the step-0 link exists).
latest_step() {
  ls "$1"/turbovla_step_*.pth 2>/dev/null | sed 's/.*_step_\([0-9]*\)\.pth/\1/' | sort -n | tail -1
}
