# Test 2: does a test-time image-restoration front end recover TurboVLA's Sensor Noise losses?

**Status:** plan, 2026-11-09. Not implemented or run (as of 2026-11-21). Separate from test 1
(`PLAN_test1_instruction_leak.md`). **Instructions stay official in this test**, so the two effects are not mixed.
**Model:** TurboVLA fine-tuned on LIBERO-Plus (`/scratch/$USER/finetune_lp/checkpoints/turbovla_step_17500.pth`).
**Origin:** a teammate's development screen with an off-the-shelf NAFNet on SmolVLA suggested a gain.

## 1. Why TurboVLA, and what "Sensor Noise" actually is
- **TurboVLA's Sensor Noise score is 73.1 % vs OFT+'s 94.9 %**: 21.8 pts of headroom, and a front end needs no
  retraining. (OFT+ has little to gain there.)
- **LIBERO-Plus "Sensor Noise" is blur and fog, not pixel noise.** Verified in `libero/libero/envs/env_wrapper.py`:
  - it is applied to the **front (agentview) camera only**; the wrist camera is clean;
  - five subtypes with 10 severities each:

| Subtype (noise id) | Tasks | spatial / object / goal / libero_10 |
|---|---|---|
| motion blur (1–10) | 336 | 76 / 90 / 80 / 90 |
| gaussian blur (11–20) | 341 | 82 / 88 / 82 / 89 |
| zoom blur (21–30) | 288 | 56 / 77 / 67 / 88 |
| fog (31–40) | 272 | 52 / 71 / 60 / 89 |
| glass blur (41–50) | 364 | 85 / 96 / 90 / 93 |

So a **deblurring** model is the right family, not a denoiser:
- **Primary:** NAFNet trained on GoPro (motion deblur), width 32 (smaller, faster) and width 64.
- **Fog:** not covered by any deblurring model. Expect no gain; report it separately.

## 2. Hypotheses (fixed before running)
- **H1:** with the front end, TurboVLA's Sensor Noise success rises ≥ 3 pts (McNemar p < 0.05), paired with its
  official run.
- **H2 (no harm):** on clean-image tasks the front end changes success by |Δ| ≤ 1 pt, not significant.
- **H3:** gains concentrate in the blur subtypes (motion > gaussian/glass/zoom); fog ≈ 0.
- **Cost:** the latency overhead is reported alongside, against TurboVLA's 30.7 ms per query.

## 3. Deployment rule (no oracle)
At test time the policy doesn't know a task is perturbed. So the front end runs on **every** front-camera frame of
every evaluated task, clean or not, and never on the wrist camera. It is applied before the 180° rotation and
TurboVLA's own preprocessing, at the 256 px eval resolution, in bf16/fp16 on the same GPU.

## 4. Steps
**Step 0: weights and code (no GPU).**
- Vendor NAFNet's architecture file (MIT licence, plain PyTorch, no BasicSR runtime needed) into the eval kit.
- Fetch the official GoPro width-32 and width-64 weights with a small CPU job into `/scratch/$USER/nafnet/`, with
  checksums recorded. The official links are Google Drive / Baidu; if no direct or HF-mirrored link works from
  Turing, download locally and transfer.

**Step 1: offline screen (≈ 1 GPU-h, one job). Pick the variant before spending rollout time.**
1. Collect ~300 clean front-camera frames from rollouts of the 40 base tasks, plus TurboVLA's predicted action
   chunk on each.
2. Corrupt each frame with LIBERO-Plus's own functions (`env_wrapper.py`) at all 5 subtypes × severities
   {2, 5, 8}.
3. For {none, NAFNet-32, NAFNet-64}, measure:
   - **image:** PSNR / SSIM against the clean frame, per subtype;
   - **policy-aware:** L1 distance between TurboVLA's action chunk on the restored frame and on the clean frame,
     against the corrupted frame. This is what matters for control, and is a teammate's "policy-aware" idea.
   - **clean-frame harm:** the same action distance when the front end runs on already-clean frames.
4. **Choose the variant** with the largest action-error reduction on blur subtypes and negligible clean-frame
   harm; prefer width 32 at near-equal benefit (latency).
5. **Stop here** if neither reduces action error meaningfully, e.g. < 20 % on the blur subtypes.

**Step 2: latency (minutes, same job or `turbovla_latency.py --frontend`).** End to end and front-end-only time
per query on the A30, batch 1, with the chosen variant.

**Step 3: rollouts (≈ 3 GPU-h; eval kit, seed 7, official instructions; one GPU job with 8 workers).**
| Panel | Tasks | Paired with | Purpose |
|---|---|---|---|
| Sensor Noise, all | 1,601 | TurboVLA's official LIBERO-Plus run | H1, H3 (per subtype and per suite) |
| Clean-image control | 500 (first 500 Language-category rows of the plan; front camera unperturbed) | same official run | H2 |
| Rerun-noise control | 200 Sensor Noise rows, front end **off** | same official run | same-seed rerun disagreement floor |

- **Implementation:** an adapter `adapters/turbovla_restore.py` that wraps `adapters/turbovla.py` and restores
  `agentview_image` before `predict`. `RESTORE=nafnet32|nafnet64|none` goes in `config.sh`, and the plan files
  hold the selected rows.

## 5. Decision
- **Promote** (as an optional deployment configuration for TurboVLA, reported with its latency) if H1 and H2 both
  hold and the gain exceeds the rerun-noise floor.
- **Then, optionally:**
  1. the full benchmark with the front end, ≈ 11 GPU-h, to confirm no losses elsewhere (Camera, Background and
     Light also change front-camera images);
- **Otherwise** record it as a negative result (with the offline screen numbers) and stop.

## 6. Cost and scheduling
- **Total:** ≈ 4–5 GPU-h (step 1 ≈ 1, step 3 ≈ 3, latency minutes), plus an optional ≈ 11 for the full benchmark.
- **Scheduling:** one GPU at a time; it can run alongside another single-GPU job.

## 7. Risks and caveats
- **Off-the-shelf restoration models are trained on real camera blur** (GoPro), not LIBERO-Plus's synthetic
  kernels, and can hallucinate texture. That's why step 1 measures action error, not only PSNR.
- **No oracle gating.** Running on all frames is the honest setting, so H2 is required, not optional.
- **The two tests are independent.** Test 1 changes instructions, test 2 changes images, and each is paired with
  the same official run. Combining them (clean instructions + restoration) is a later question.
