# TurboVLA fine-tuning on LIBERO-Plus (Turing pipeline)

Fine-tunes the released TurboVLA LIBERO model on the LIBERO-Plus training data for 1 epoch on 2 A30s, then evaluates
it on the full LIBERO-Plus benchmark in the baseline's task order and writes a paired comparison. Runs unattended as
chained SLURM jobs; you can disconnect after submitting.

```bash
cd ~/finetune_lp && ./submit_pipeline.sh   # once
./status.sh                                # any time: stages, download/training/eval progress
./stop.sh                                  # cancel whatever is pending/running (data and checkpoints stay)
```
Emails (to the submitting user, or `--mail-user` if you add it): any stage failing or requeuing, training finished, pipeline finished (report.md).

| Stage | What | Resources | Expected |
|---|---|---|---|
| s0 | finish the baseline run (`~/lp_eval_full`): rerun its 6 watchdog-skipped tasks with STALL_MIN=30 | 1 GPU | ~1 h |
| s1 | `tools.sif` (p7zip, zip, unzip); the training/eval image stays as it was for the baseline | CPU | ~2 min |
| s2 | download `Sylvest/libero_plus_rlds` (75.5 GB) to `/scratch/$USER/libero_plus_data` | CPU | 1–3 h |
| s3 | extract, verify (14,347 episodes, shapes), delete the zips | CPU | ~1 h |
| s3b | training-data stats vs released stats → `stats/compare.txt` (nothing waits on it) | CPU | hours |
| s4 | smoke test: 300 steps on 2 GPUs; full weight load, finite loss, checkpoint loads in the eval adapter; measures speed and shortens s5's time limit | 2 GPUs | ~20 min |
| s5 | train 17,500 steps (global batch 128 = 2 × 32 × 2), checkpoint every 500 → `/scratch/$USER/finetune_lp/checkpoints`, `final.pth` | 2 GPUs | ~4–5 h |
| s6 | LIBERO-Plus eval of `final.pth` (EMA) in `~/lp_eval_ft`, baseline `plan.tsv`, 2 jobs × 8 workers | 2 × 1 GPU | ~5.5 h |
| s7 | `report.md`: paired comparison with the baseline per suite/category + training summary | CPU | 1 min |

Recipe: start from `turbovla_libero.pth` (linked as step 0, `--resume_mode model`), lr 5e-5, 1,000 warmup steps from
10% then constant, AdamW (0.9, 0.95), grad clip 1.0, masked L1 loss on 12-step action chunks, DINOv3 bf16 autocast,
BERT frozen, EMA 0.999 saved in every checkpoint, released normalization stats (`libero_all4_no_noops`).

Requeues: s2, s5 and s6 requeue themselves near their time limit (same job ID, so later stages keep waiting), at most
twice each (Turing docs, "Auto Requeuing"). s5 resumes from its latest checkpoint with `--resume_mode all` and a new
data seed (the EMA restarts from the current weights). Real failures are not retried.

Files: `pipeline.log` (one line per stage event), `jobs.env` (job IDs), `logs/` (job logs, `train.log`,
`smoke_train.log`), `smoke_summary.txt`, `stats/`, `report.md`.
