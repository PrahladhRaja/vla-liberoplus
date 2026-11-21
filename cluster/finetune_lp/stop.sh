#!/bin/bash
# Stop the pipeline: cancel every stage that is still pending or running. Finished results, downloaded data and
# saved checkpoints stay; training resumes from its latest checkpoint if the pipeline is submitted again.
source "$HOME/finetune_lp/common.sh"
cd "$FT" || exit 1
[ -f jobs.env ] || { echo "No jobs.env; nothing to stop."; exit 0; }
ids=$(grep -o '=[0-9]*' jobs.env | tr -d '=' | paste -sd,)
active=$(squeue -h --me -j "$ids" -o %i 2>/dev/null | paste -sd' ')
if [ -z "$active" ]; then echo "No pipeline jobs are pending or running."; exit 0; fi
echo "Cancelling: $active"
scancel $active
plog "stopped by stop.sh (cancelled $active)"
