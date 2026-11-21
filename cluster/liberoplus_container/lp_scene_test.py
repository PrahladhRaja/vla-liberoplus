"""Smoke test inside liberoplus.sif: imports, then one LIBERO-Plus scene per perturbation category.

For each category it builds the env (as the TurboVLA evaluator does), steps 50 no-op actions, reports steps/s,
and saves the agentview + wrist frame as a PPM next to this script's output directory.
    lp-exec.sh python lp_scene_test.py <output_dir>
"""

import json
import os
import sys
import time
from pathlib import Path

import numpy as np

out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
out_dir.mkdir(parents=True, exist_ok=True)

import mujoco, robosuite, torch, wand.image  # noqa: E401  (import check)
print(f"torch {torch.__version__} cuda={torch.cuda.is_available()} | mujoco {mujoco.__version__} | robosuite {robosuite.__version__}")

from libero.libero import benchmark, get_libero_path
from libero.libero.envs import OffScreenRenderEnv

print("assets dir:", get_libero_path("assets"), "->", sorted(os.listdir(get_libero_path("assets")))[:4], "...")
classification = json.load(open(Path(get_libero_path("benchmark_root")) / "benchmark" / "task_classification.json"))
suite_name = "libero_spatial"
suite = benchmark.get_benchmark_dict()[suite_name]()
first_of = {}
for item in classification[suite_name]:
    first_of.setdefault(item["category"], item["id"] - 1)

for category, task_id in first_of.items():
    task = suite.get_task(task_id)
    t0 = time.time()
    env = OffScreenRenderEnv(
        bddl_file_name=os.path.join(get_libero_path("bddl_files"), task.problem_folder, task.bddl_file),
        camera_heights=256, camera_widths=256,
    )
    env.seed(7)
    env.reset()
    obs = env.set_init_state(suite.get_task_init_states(task_id)[0])
    t1 = time.time()
    for _ in range(50):
        obs, _, _, _ = env.step([0, 0, 0, 0, 0, 0, -1])
    sps = 50 / (time.time() - t1)
    frame = np.concatenate([obs["agentview_image"][::-1, ::-1], obs["robot0_eye_in_hand_image"][::-1, ::-1]], axis=1)
    path = out_dir / f"scene_{category.split()[0].lower()}_task{task_id}.ppm"
    with open(path, "wb") as f:
        f.write(f"P6 {frame.shape[1]} {frame.shape[0]} 255\n".encode() + np.ascontiguousarray(frame).tobytes())
    env.close()
    print(f"{category:22s} task {task_id:4d}: env {t1 - t0:5.1f}s, {sps:5.1f} steps/s, mean pixel {frame.mean():5.1f} -> {path.name}")
print("open file handles:", len(os.listdir("/proc/self/fd")))
