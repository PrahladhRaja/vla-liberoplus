# Pinned upstream code, models and data

Upstream code is not vendored in this repo. The setup scripts clone these exact commits; our changes to them are in
[`patches/`](../patches).

## Code
| Project | Commit | Cloned by | Our patches |
|---|---|---|---|
| [TurboVLA](https://github.com/H-EmbodVis/TurboVLA) | `6727c875666f8d5dda8d8cca0043da200738fe73` (2026-09-27) | `cluster/liberoplus_container/setup_code.sh` | `patches/TurboVLA/0001-eval-ema-fallback.patch` |
| [LIBERO-Plus](https://github.com/sylvestf/LIBERO-plus) | `4976dc30028e805ff8094b55501d532c48fec182` (2026-01-21) | `cluster/liberoplus_container/setup_code.sh` | none |
| [LIBERO](https://github.com/Lifelong-Robot-Learning/LIBERO) (standard benchmark) | `8f1084e3132a39270c3a13ebe37270a43ece2a01` (2025-03-15) | `cluster/finetune_lp/libero_std.sbatch` | none |
| [openvla-oft](https://github.com/moojink/openvla-oft) | `e4287e94541f459edc4feabc4e181f537cd569a8` (2025-09-08) | `cluster/oft_container/setup_oft_code.sh` | `patches/openvla-oft/0001-…`, `0002-…` |

## Models (Hugging Face)
| Model | Revision | Used for |
|---|---|---|
| `H-EmbodVis/TurboVLA` (`checkpoints/libero/turbovla_libero.pth`) | `9cdb576e…` (downloaded 2026-10-01) | released TurboVLA; start of our fine-tune |
| DINOv3 ViT-B/16 (`facebook/dinov3-vitb16-pretrain-lvd1689m`), BERT base uncased | as downloaded with TurboVLA (`cluster/liberoplus_container/download_weights.sbatch`) | TurboVLA encoders |
| `Sylvest/openvla-7b-oft-finetuned-libero-plus-mixdata` | not pinned; downloaded 2026-10-29 (15,082,474,368 bytes of merged weights, heads `--150000`) | OpenVLA-OFT+ |
| `moojink/openvla-7b-oft-finetuned-libero-spatial-object-goal-10` | `638918f3d1c2e43a39a8a20772bdb8b91835e4b7` | original OpenVLA-OFT |

## Data
| Dataset | Notes |
|---|---|
| `Sylvest/libero_plus_rlds` | LIBERO-Plus training mix, 14,347 episodes / 2,238,036 steps after extraction (`cluster/finetune_lp/s2_download.sbatch`, `s3_extract.sbatch`) |
| LIBERO-Plus assets (`assets.zip`) | packed into `assets.sqfs` by `cluster/liberoplus_container/make_assets.sbatch` |

## Simulator stack
MuJoCo 3.2.0 and robosuite 1.4.1 in both containers. MuJoCo 3.1.6 leaks file handles in long runs; see
`cluster/liberoplus_container/README.md`.
