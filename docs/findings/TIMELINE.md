# Timeline (in-scope work only; all dates are 2026)

| Date | What happened | Where recorded |
|---|---|---|
| before 10-18 | Released TurboVLA run on all 10,030 LIBERO-Plus tasks on the desktop: **44.6 %**, 86.5 h of episodes | `cluster/eval_kit_desktop/reference/` |
| 10-18 | LIBERO-Plus container built and verified on Turing (jobs 2390583, 2390510, 2390584). Found the MuJoCo 3.1.6 file-handle leak; pinned 3.2.0 | `cluster/liberoplus_container/README.md` |
| 10-19 | Eval kit on Turing: 29-task check (1 vs 8 workers per GPU, identical outcomes, about 7.3× throughput). Full released-TurboVLA run in 5 h 20 min on 2 GPUs: **45.5 %** (jobs 2392416/7) | `results/turbovla/reports/README.md`, `lp_eval_full_vs_desktop.md` |
| 10-20 | Starter kit for teammates packaged | `cluster/starter_kit/` |
| 10-21 | Fine-tuning pipeline submitted: LIBERO-Plus training data downloaded and extracted (78 GB), smoke test passed, 1-epoch training started | `cluster/finetune_lp/README.md` |
| 10-22 | Training finished (3 h 51 min). Fine-tuned TurboVLA on LIBERO-Plus: **68.9 % (+23.5)**. Standard LIBERO released 93.8 vs fine-tuned **96.5**. Step-10k checkpoint already gets 98 % of the gain | `results/turbovla/reports/lp_eval_ft_*.md`, `libero_std_released_vs_finetuned.md`, `ck10k_vs_final.md` |
| 10-29 | Checkpoints and video tars archived to `/archive/<user>/turbovla_liberoplus_2026-10/` | `docs/findings/DATA_MAP.md` §4 |
| 10-30 | OpenVLA-OFT+ set up on Turing: LIBERO-Plus **80.5 %** (paper 79.6), standard LIBERO **96.6 %**, latency 143.3 ms per query | `docs/oft_reference.md` |
| early Nov | TurboVLA A30 latency benchmark: 30.7 ms per query, 2.56 ms per action, 0.43 GB (job 2471859) | `docs/oft_reference.md` |
| 11-09 | Instruction leak confirmed in the LIBERO-Plus source (8,493 of 10,030 tasks), after a teammate's observation with SmolVLA. Test 1 (leak) and test 2 (deblur front end) planned | `docs/plans/PLAN_test1_*.md`, `PLAN_test2_*.md` |
| 11-10 | Test 1 stage A (1,000 tasks): fine-tuned TurboVLA +15.9. Stage B submitted. Original OFT reference runs submitted | `PLAN_test1_*.md` §7, `PLAN_oft_libero_reference.md` |
| 11-11 | Test 1 stage B: fine-tuned TurboVLA **+15.6 → ≈ 82.1 % clean**. Released TurboVLA +15.1. Original OFT: LIBERO-Plus **68.7 %** (paper 69.6), standard 96.1, leak +3.0 | `docs/plans/PLAN_test1_*.md`, `docs/findings/TEAMMATES.md` |
| 11-14 | Video reruns for slides (jobs 2519596, 2519790). Progress deck | `experiments/robustness/vid_*.sh` |
| 11-21 | Reference pack written; OFT+ clean-instruction (all 8,493 affected tasks), rerun and seed-7 runs submitted (jobs 2563982–84, 2564221/2); repo `vla-liberoplus` built | `docs/findings/`, `experiments/robustness/gapfill_*` |

Not done: test 2 (deblur front end), the SmolVLA latency benchmark, and the merge of SmolVLA into the shared table.
See [GAPS.md](GAPS.md).
