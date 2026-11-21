# Settings for this evaluation on Turing. Every script sources this file (inside and outside the container).
# One copy of the kit = one evaluation (results are written next to the scripts).

KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Python inside the LIBERO-Plus container: kit-python runs `lp-exec.sh python -u` (GPU EGL, assets, PYTHONPATH).
PY=$KIT_DIR/kit-python
export LP_EXEC=${LP_EXEC:-$HOME/oft_container/oft-exec.sh}
# Extra PYTHONPATH entries for your model's code (only needed with the starter kit's generic lp-exec.sh).
# export LP_PYTHONPATH=$HOME/turing-vla/MyVLA

# LIBERO-Plus checkout and its config dir (written by setup_code.sh / setup_libero_plus.sh).
LIBERO_PLUS_ROOT=$HOME/turing-vla/LIBERO-plus
export LIBERO_CONFIG_PATH=$HOME/.libero-plus

# Model adapter as "module:Class" (module path relative to this folder). See model_adapter.py.
ADAPTER=adapters.openvla_oft:OpenVLAOFTAdapter

# Evaluation protocol (keep identical across models you want to compare).
SEED=7
ENV_SEED=0               # OpenVLA-OFT protocol: env.seed(0) as in OFT's run_libero_eval.py
SAVE_VIDEO=1             # 1 = save one MP4 per task (~300 KB each), 0 = no videos

# Watchdog: kill and restart the evaluator if no task finishes for this many minutes.
# Must exceed your slowest real episode: TurboVLA's longest LIBERO-Plus episodes (libero_10 Sensor Noise, 520 steps)
# take up to ~15 min on Turing with 8 workers per GPU; 15 recorded 6 of them as hangs. Slower models: raise it.
STALL_MIN=30
