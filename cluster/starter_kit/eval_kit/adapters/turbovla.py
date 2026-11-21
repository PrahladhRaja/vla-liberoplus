"""TurboVLA adapter (worked example), matching TurboVLA's experiments/libero/evaluate.py settings:
bf16, 12-step chunks executed open loop, 256 px images rotated 180 degrees, DINOv3 ViT-B + BERT.
Needs the TurboVLA repo on PYTHONPATH (lp-exec.sh does this) and its weights under <TURBOVLA_ROOT>/pretrained/.
"""

import os

import numpy as np

TURBOVLA_ROOT = os.environ.get("TURBOVLA_ROOT", os.path.expanduser("~/turing-vla/TurboVLA"))


def _path(rel):
    return os.path.join(TURBOVLA_ROOT, rel)


class TurboVLAAdapter:
    image_size = 256

    def __init__(self):
        from turbovla.evaluation.suite_policy import TurboVLAPolicy, rotate_libero_image

        self._rotate = rotate_libero_image
        self.policy = TurboVLAPolicy(
            ckpt_path=_path("pretrained/TurboVLA/checkpoints/libero/turbovla_libero.pth"),
            dinov3_path=_path("pretrained/dinov3-vitb16-pretrain-lvd1689m"),
            bert_path=_path("pretrained/bert-base-uncased"),
            stats_path=_path("experiments/libero/configs/libero_all4_stats.json"),
            stats_key="libero_all4_no_noops",
            precision="bf16",
        )

    def reset(self):
        pass

    def predict(self, obs, instruction):
        primary = self._rotate(obs["agentview_image"])
        wrist = self._rotate(obs["robot0_eye_in_hand_image"])
        return np.asarray(self.policy.predict_env_action_chunk(primary, wrist, instruction, obs, execute_steps=12))
