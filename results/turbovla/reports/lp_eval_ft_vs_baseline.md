# LIBERO-Plus: baseline vs new model (paired, same tasks)

- Baseline: `/home/<user>/lp_eval_full` (10030 tasks); new: `/home/<user>/lp_eval_ft` (10030 tasks); compared: 10030 tasks.
- Skipped after two hangs: baseline 0, new 0.

## Success rate (%): baseline → new (Δ)

| | Camera | Robot | Language | Light | Background | Noise | Layout | Total |
|---|---|---|---|---|---|---|---|---|
| libero_spatial | 22.6 → 71.5 (+48.9) | 35.7 → 43.4 (+7.7) | 76.2 → 83.6 (+7.4) | 78.8 → 95.5 (+16.8) | 54.7 → 96.9 (+42.2) | 42.5 → 71.2 (+28.8) | 59.5 → 75.3 (+15.8) | **52.3 → 75.6 (+23.3)** |
| libero_object | 31.8 → 86.6 (+54.8) | 38.7 → 43.7 (+5.0) | 94.6 → 99.2 (+4.5) | 91.2 → 99.3 (+8.1) | 79.4 → 99.2 (+19.8) | 31.8 → 93.1 (+61.4) | 64.0 → 76.7 (+12.7) | **58.6 → 83.8 (+25.3)** |
| libero_goal | 12.0 → 55.6 (+43.6) | 15.2 → 17.6 (+2.4) | 28.0 → 32.4 (+4.4) | 41.9 → 57.3 (+15.4) | 26.7 → 52.0 (+25.3) | 20.1 → 37.7 (+17.7) | 37.4 → 37.2 (-0.2) | **25.2 → 40.1 (+14.9)** |
| libero_10 | 27.0 → 76.6 (+49.6) | 44.5 → 57.5 (+13.0) | 77.3 → 81.7 (+4.4) | 56.9 → 86.5 (+29.6) | 34.6 → 78.5 (+43.9) | 32.5 → 85.5 (+53.0) | 60.9 → 76.6 (+15.7) | **46.7 → 77.3 (+30.6)** |
| all suites | 23.3 → 72.5 (+49.2) | 33.3 → 40.3 (+7.0) | 67.9 → 73.1 (+5.2) | 67.8 → 85.0 (+17.3) | 47.7 → 80.8 (+33.1) | 31.5 → 73.1 (+41.5) | 54.8 → 65.3 (+10.5) | **45.5 → 68.9 (+23.5)** |

## Which tasks changed

| Category | tasks | baseline only | new only | net | test |
|---|---|---|---|---|---|
| Camera | 1599 | 30 | 817 | +787 | McNemar z = 27.01, p ≈ 1.21e-160 (significant at 5%) |
| Robot | 1550 | 116 | 224 | +108 | McNemar z = 5.80, p ≈ 6.52e-09 (significant at 5%) |
| Language | 1537 | 90 | 170 | +80 | McNemar z = 4.90, p ≈ 9.61e-07 (significant at 5%) |
| Light | 1142 | 42 | 239 | +197 | McNemar z = 11.69, p ≈ 1.39e-31 (significant at 5%) |
| Background | 1076 | 35 | 391 | +356 | McNemar z = 17.20, p ≈ 2.66e-66 (significant at 5%) |
| Noise | 1601 | 33 | 698 | +665 | McNemar z = 24.56, p ≈ 3.47e-133 (significant at 5%) |
| Layout | 1525 | 76 | 236 | +160 | McNemar z = 9.00, p ≈ 2.22e-19 (significant at 5%) |
| **all** | 10030 | 422 | 2775 | +2353 | McNemar z = 41.60, p ≈ 0 (significant at 5%) |

'baseline only' = solved by the baseline but not the new model; 'new only' = the reverse. For reference, the same released model run on the desktop vs Turing differed on ~13% of tasks (6.2% / 7.1% each way), so per-task flips at that level are noise; the paired test accounts for this.

## Training

- Checkpoint: `/scratch/<user>/finetune_lp/checkpoints/turbovla_step_17500.pth` (evaluated with its EMA weights)
- smoke test 2026-10-21 23:25:52: 1.235 steps/s on 2 A30s, loss (20-step avg) 0.06853, peak GPU memory 13691 MiB, checkpoint size 2G; 1 epoch (17500 steps) ~ 3.9 h 
- Last training progress line: `training: 100%|██████████| 17500/17500 [3:51:28<00:00,  1.26it/s, loss=0.04515, avg=0.04583, lr=5.00e-05]`

## Training data statistics vs released stats

```
== action: released (LIBERO) -> LIBERO-Plus mix, per dimension
  min  -0.938->-0.938  -0.938->-0.938  -0.938->-0.938  -0.258->-0.258  -0.375->-0.375  -0.368->-0.364  -1.000->-1.000
  max  +0.938->+0.938  +0.938->+0.938  +0.938->+0.938  +0.356->+0.356  +0.375->+0.375  +0.375->+0.375  +1.000->+1.000
  mean +0.063->+0.066  +0.087->+0.091  -0.090->-0.092  +0.001->+0.000  +0.006->+0.006  -0.005->-0.004  -0.050->-0.035
  std  +0.336->+0.336  +0.378->+0.382  +0.445->+0.454  +0.039->+0.038  +0.063->+0.063  +0.078->+0.076  +0.999->+0.999
== proprio: released (LIBERO) -> LIBERO-Plus mix, per dimension
  min  -0.483->-0.486  -0.326->-0.331  +0.008->+0.008  +0.353->+0.842  -3.641->-3.617  -1.843->-1.843  -0.001->-0.003  -0.042->-0.042
  max  +0.210->+0.210  +0.391->+0.391  +1.366->+1.366  +3.671->+3.774  +3.561->+3.575  +1.386->+1.375  +0.042->+0.042  +0.001->+0.001
  mean -0.047->-0.045  +0.034->+0.036  +0.765->+0.744  +2.972->+2.989  -0.220->-0.138  -0.126->-0.107  +0.027->+0.027  -0.027->-0.027
  std  +0.105->+0.105  +0.152->+0.153  +0.379->+0.384  +0.344->+0.330  +0.907->+0.829  +0.325->+0.312  +0.014->+0.014  +0.014->+0.014

action dims whose new range exceeds the released range (clamped in training): none
```
