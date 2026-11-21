# Settings for this evaluation. Every script sources this file; edit it before the first run.
# One copy of the kit = one evaluation (results are written next to the scripts).

# Python of the conda env that has LIBERO-Plus and your model installed.
PY=/home/USER/miniforge3/envs/liberoplus/bin/python

# LIBERO-Plus checkout, and the LIBERO config dir that points at it (see README, "Setup").
LIBERO_PLUS_ROOT=/home/USER/LIBERO-plus
export LIBERO_CONFIG_PATH=/home/USER/.libero-plus

# Model adapter as "module:Class" (module path relative to this folder). See model_adapter.py.
ADAPTER=model_adapter:Adapter

# Evaluation protocol (keep identical across models you want to compare).
SEED=7
SAVE_VIDEO=1             # 1 = save one MP4 per task (~300 KB each), 0 = no videos

# Nightly schedule (Windows Task Scheduler, see schedule.sh).
WINDOW_START=01:00
WINDOW_END=09:00
TASK_NAME="LIBERO-Plus nightly eval"   # must be unique per evaluation on the same PC

# Watchdog: kill and restart the evaluator if no task finishes for this many minutes.
STALL_MIN=15

# Offscreen rendering. These values are for WSL2 with an NVIDIA GPU (renders through Direct3D 12);
# on native Linux use MUJOCO_GL=egl PYOPENGL_PLATFORM=egl and drop the two Mesa variables.
export MUJOCO_GL=egl PYOPENGL_PLATFORM=egl GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA
