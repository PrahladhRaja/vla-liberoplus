"""Check that a fine-tuning checkpoint has EMA weights and loads in the eval kit's TurboVLA adapter (as evaluation will).
    lp-exec.sh python -u check_ckpt.py <checkpoint.pth> <eval kit dir>
"""

import os
import sys

import torch

ckpt_path, kit = sys.argv[1], sys.argv[2]
ckpt = torch.load(ckpt_path, map_location="cpu")
for key in ("model_state_dict", "ema_model_state_dict", "model_config", "global_step"):
    assert key in ckpt, f"checkpoint has no {key}"
print(f"checkpoint step {ckpt['global_step']}, loss {ckpt.get('loss')}, EMA decay {ckpt.get('ema_decay')}")
del ckpt

os.environ["TURBOVLA_CKPT"] = ckpt_path
sys.path.insert(0, kit)
from adapters.turbovla import TurboVLAAdapter  # noqa: E402

TurboVLAAdapter()
print("loads in the eval adapter: OK")
