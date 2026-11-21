# Teammates' work and how it joins the comparison

Each teammate adds their summary, code and results as described in [CONTRIBUTING.md](../../CONTRIBUTING.md). Their
summaries live in [`teammates/`](../../teammates). This page covers the rules for putting other models' numbers next to
the TurboVLA and OpenVLA-OFT results in [RESULTS.md](RESULTS.md).

## Work areas
| Area | Where in the repo |
|---|---|
| TurboVLA fine-tuning, instruction-leak test, OpenVLA-OFT references | this repo's `cluster/`, `experiments/robustness/`, `results/` |
| SmolVLA (`lerobot/smolvla_libero`, 450M) and its fine-tunes | to be added by the teammates (`teammates/`, `cluster/smolvla/`, `results/smolvla/`) |
| Image restoration (NAFNet) for Sensor Noise | to be added; related plan: `docs/plans/PLAN_test2_deblur_frontend.md` |

## Rules for putting their numbers next to ours (`docs/plans/PLAN_smolvla_speed_quality.md`)
- **Compare on the same task set.** Full 10,030-task runs, or the same subset on both sides.
- **The protocol has to match before pairing per task.** Check these against the run's protocol card:
  - step limits (ours: 220/280/300/520);
  - executed actions per query (ours: 8 for OFT, 12 for TurboVLA);
  - official instructions;
  - simulator stack (MuJoCo 3.2.0, robosuite 1.4.1);
  - env seed (ours: 7 for TurboVLA).
  - If they match, the model joins the paired tables. If not, show it as an aggregate reference point only, labelled
    "different protocol".
- **Latency** must be measured the same way: A30, batch 1, OFT's sample observation; see
  `cluster/oft_container/turbovla_latency.py`.
- **Checkpoint naming:** use the 450M `lerobot/smolvla_libero`, never the older ~605M `HuggingFaceVLA/smolvla_libero`.
- **Licenses:** models trained on π0.5-generated demonstrations fall under the Gemma Terms of Use if published; see
  `THIRD_PARTY_LICENSES.md`.
