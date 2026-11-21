"""OpenVLA-OFT(+) adapter (client side). The model runs in a separate server process on the job's GPU
(openvla-oft `experiments/robot/libero/oft_libero_server.py`, started by eval_job_oft.sbatch); this adapter sends the
raw LIBERO observation and instruction and gets back the executable action chunk (8, 7). All preprocessing (180°
rotation, resize to 224, center crop, proprio = eef pos + axis-angle + gripper, normalization) and post-processing
(gripper binarize + invert) happen in the server with OpenVLA-OFT's own functions, so the result is identical to
run_libero_eval.py.

Env: OFT_SERVER_URL (default http://127.0.0.1:8777), OFT_SERVER_WAIT_S (default 900: model load can take minutes).
"""

import os
import time

import json_numpy
import numpy as np
import requests

OBS_KEYS = ("agentview_image", "robot0_eye_in_hand_image", "robot0_eef_pos", "robot0_eef_quat", "robot0_gripper_qpos")


class OpenVLAOFTAdapter:
    image_size = 256  # OFT's LIBERO eval renders at 256 (env_img_res) and resizes to 224 itself

    def __init__(self):
        self.url = os.environ.get("OFT_SERVER_URL", "http://127.0.0.1:8777")
        self.session = requests.Session()
        deadline = time.time() + float(os.environ.get("OFT_SERVER_WAIT_S", 900))
        while True:
            try:
                if self.session.get(f"{self.url}/health", timeout=10).ok:
                    return
            except requests.RequestException:
                pass
            if time.time() > deadline:
                raise RuntimeError(f"OFT server at {self.url} not reachable")
            time.sleep(5)

    def reset(self):
        pass

    def predict(self, obs, instruction):
        data = json_numpy.dumps({"obs": {k: np.asarray(obs[k]) for k in OBS_KEYS}, "instruction": instruction})
        # A query is stateless, so retry on a dropped connection: uvicorn closes keep-alive connections idle > 5 s,
        # and a request sent on one just as it closes fails with "Connection reset by peer" (3 tasks lost that way
        # in the OFT+ baseline run, jobs 2430419/2430420). Retry on a fresh connection.
        for attempt in range(3):
            try:
                r = self.session.post(f"{self.url}/act", data=data,
                                      headers={"Content-Type": "application/json"}, timeout=300)
                r.raise_for_status()
                return np.asarray(json_numpy.loads(r.json()), dtype=np.float64)
            except requests.ConnectionError:
                if attempt == 2:
                    raise
                self.session.close()
                self.session = requests.Session()
                time.sleep(1)
