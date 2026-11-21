"""Model adapter template: the only model-specific code in the kit.

eval_tasks.py owns the episode protocol (identical for every model, so results are comparable):
  * one env per task: OffScreenRenderEnv at `image_size`, env.seed(SEED); random/numpy/torch seeded
    with SEED before each task
  * env.reset(); env.set_init_state(initial state 0 of the task)
  * 10 settling steps with the no-op action [0, 0, 0, 0, 0, 0, -1]
  * then up to the suite's step limit (spatial 220, object 280, goal 300, libero_10 520):
    whenever the action queue is empty it calls `predict(obs, instruction)` and executes every
    returned action in order (open loop) before asking again
  * success = the env reports done within the step limit

Implement the three members below, then set ADAPTER=model_adapter:Adapter in config.sh.
adapters/turbovla.py is a complete working example.
"""

import numpy as np


class Adapter:
    # Camera resolution the env renders at (both agentview and wrist cameras, square).
    image_size = 256

    def __init__(self):
        """Load the model once; it is reused for every task until the evaluator restarts."""
        raise NotImplementedError("load your model here")

    def reset(self) -> None:
        """Called at the start of every episode (clear any history / internal state)."""

    def predict(self, obs: dict, instruction: str) -> np.ndarray:
        """Return actions to execute next, shape (k, 7), in LIBERO env convention.

        obs is the raw LIBERO observation dict, e.g. obs["agentview_image"] and
        obs["robot0_eye_in_hand_image"] (H x W x 3 uint8, upside down: most LIBERO policies rotate
        them 180 degrees, i.e. img[::-1, ::-1]), obs["robot0_eef_pos"], obs["robot0_eef_quat"],
        obs["robot0_gripper_qpos"].

        Env action convention: 6 delta end-effector values (xyz, axis-angle) then the gripper,
        -1 = open, +1 = close. Undo your model's action normalization and gripper convention here.
        Return k = 1 for a closed-loop policy, or the chunk length your model is evaluated with.

        `instruction` is LIBERO-Plus's task.language. Outside the Language category it carries
        file-name suffixes (e.g. "... on the plate view 0 0 100 2 352 initstate 0"); see README.
        """
        raise NotImplementedError
