"""OFT+ setup (docs/oft_reference.md): build the `libero_mix` dataset with OpenVLA-OFT's own loader and check that the statistics it
computes (and caches next to the dataset, where training will reuse them) reproduce OFT+'s released
dataset_statistics.json. Run inside the OFT container from the openvla-oft repo root:
    oft-exec.sh python -u check_dataset_stats.py <data_root_dir> <oftplus checkpoint dir>
Exit code 0 if every field matches within tolerance.
"""

import json
import sys

sys.argv.append("libero")  # makes prismatic.vla.constants select the LIBERO constants (as finetune.py does)
import numpy as np  # noqa: E402

from prismatic.vla.datasets.rlds.dataset import make_dataset_from_rlds  # noqa: E402
from prismatic.vla.datasets.rlds.oxe.materialize import make_oxe_dataset_kwargs  # noqa: E402

data_root, ckpt_dir = sys.argv[1], sys.argv[2]
kwargs = make_oxe_dataset_kwargs("libero_mix", data_root, load_camera_views=("primary", "wrist"))
_, ours = make_dataset_from_rlds(**kwargs, train=True)
ref = json.load(open(f"{ckpt_dir}/dataset_statistics.json"))["libero_spatial"]  # all 4 suite keys are identical

ok = True
for key in ("num_transitions", "num_trajectories"):
    a, b = int(np.asarray(ours[key])), int(ref[key])
    print(f"{key}: ours {a}, OFT+ {b}", "OK" if a == b else "MISMATCH")
    ok &= a == b
for group in ("action", "proprio"):
    for stat, ref_vals in ref[group].items():
        if stat not in ours[group]:
            print(f"{group}.{stat}: not computed by our loader")
            ok = False
            continue
        a, b = np.asarray(ours[group][stat], dtype=np.float64), np.asarray(ref_vals, dtype=np.float64)
        if a.shape != b.shape:
            print(f"{group}.{stat}: shape {a.shape} vs {b.shape} MISMATCH")
            ok = False
            continue
        diff = float(np.abs(a - b).max()) if a.size else 0.0
        tol = 0 if a.dtype == bool else 1e-4  # q01/q99 come from the same samples, so exact up to float noise
        print(f"{group}.{stat}: max |diff| {diff:.2e}", "OK" if diff <= tol else "MISMATCH")
        ok &= diff <= tol
print("RESULT:", "statistics reproduce OFT+" if ok else "statistics DIFFER from OFT+")
sys.exit(0 if ok else 1)
