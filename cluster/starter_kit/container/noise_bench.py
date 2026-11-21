"""Time LIBERO-Plus's per-step sensor-noise filters (exactly the env_wrapper functions) on a 256x256 frame.
    python -u noise_bench.py [label] [families, e.g. glass,zoom (default: all)]
Prints ms per call for each filter family at a mid severity, plus CPU model and thread settings.
"""

import os
import sys
import time

import numpy as np
from PIL import Image

from libero.libero.envs import env_wrapper as ew

label = sys.argv[1] if len(sys.argv) > 1 else ""
only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
cpu = next((l.split(":", 1)[1].strip() for l in open("/proc/cpuinfo") if l.startswith("model name")), "?")
threads = {k: os.environ.get(k) for k in ("OMP_NUM_THREADS", "MAGICK_THREAD_LIMIT", "OPENBLAS_NUM_THREADS")}
print(f"[{label}] CPU: {cpu} | usable cores: {len(os.sched_getaffinity(0))} | {threads}", flush=True)

rng = np.random.default_rng(0)
img = Image.fromarray(rng.integers(0, 256, (256, 256, 3), dtype=np.uint8))
np.random.seed(0)
families = [("motion  (1-10)", ew.motion_blur, 5), ("gaussian(11-20)", ew.gaussian_blur, 5),
            ("zoom    (21-30)", ew.zoom_blur, 5), ("fog     (31-40)", ew.fog, 5), ("glass   (41-50)", ew.glass_blur, 5)]
for name, fn, sev in families:
    if only and name.split()[0] not in only:
        continue
    fn(img, severity=sev)  # warm up
    n, t = 0, time.time()
    while time.time() - t < 3 or n < 3:
        fn(img, severity=sev); n += 1
    print(f"[{label}] {name}: {(time.time() - t) / n * 1000:8.1f} ms/step", flush=True)
