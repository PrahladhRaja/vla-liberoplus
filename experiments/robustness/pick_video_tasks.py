"""Pick LIBERO-Plus tasks whose rollout videos illustrate the project's findings (for slides).
Reads each run's results*.jsonl (suite, task_id, success, seconds) and the plan's category column; login node, stdlib.
    python3 pick_video_tasks.py > video_candidates.txt
Each theme lists up to N tasks, shortest successful episode first (short clips suit slides). Outcomes are required to
agree across neighbouring models where possible, so a same-seed rerun with videos is likely to reproduce them.
"""
import glob
import json
import os
from pathlib import Path

H = Path.home()
N = 6
RUNS = {
    "tv_rel": "lp_eval_full", "tv_ft": "lp_eval_ft", "tv_ft_clean": "lp_t1_turbovla_clean",
    "tv_rel_clean": "lp_t1_turbovlaR_clean", "oftplus": "lp_eval_oftplus", "oftL": "lp_eval_oftL",
}
VIDEO_DIRS = {"tv_rel": "lp_eval_full_videos", "tv_ft": "lp_eval_ft_videos", "oftplus": "lp_eval_oftplus_videos"}


def load(name):
    out = {}
    for p in glob.glob(str(H / name / "results*.jsonl")):
        for line in open(p):
            r = json.loads(line)
            if r.get("hung"):
                continue
            out[(r["suite"], int(r["task_id"]))] = (bool(r["success"]), float(r.get("seconds", 0)))
    return out


R = {k: load(v) for k, v in RUNS.items()}
cat = {}
for line in open(H / "lp_eval_full" / "plan.tsv"):
    if line.startswith("#"):
        continue
    _, suite, tid, c, _ = line.rstrip("\n").split("\t")
    cat[(suite, int(tid))] = c


def s(run, key):  # success or None
    v = R[run].get(key)
    return None if v is None else v[0]


def sec(run, key):
    return R[run].get(key, (None, 9e9))[1]


def video(run, key):
    if run not in VIDEO_DIRS:
        return "(rerun needed)"
    suite, tid = key
    ok = "success" if s(run, key) else "failure"
    p = Path("/scratch") / H.name / VIDEO_DIRS[run] / suite / f"task{tid:04d}_{ok}.mp4"
    return str(p) if p.exists() else f"(missing {p.name})"


THEMES = [
    ("1 Instruction leak: TurboVLA fine-tuned fails with official instruction, succeeds with clean one",
     lambda k: s("tv_ft", k) is False and s("tv_ft_clean", k) and s("tv_rel_clean", k) is not False
     and s("oftplus", k) and cat[k] in ("Background_Textures", "Sensor_Noise", "Camera_Viewpoints") and k[0] == "libero_goal",
     [("tv_ft", "official, fails"), ("tv_ft_clean", "clean, succeeds")], "tv_ft_clean"),
    ("2 LIBERO-Plus fine-tuning: released TurboVLA fails, fine-tuned succeeds (Camera)",
     lambda k: s("tv_rel", k) is False and s("tv_ft", k) and s("oftplus", k) and cat[k] == "Camera_Viewpoints",
     [("tv_rel", "released, fails"), ("tv_ft", "fine-tuned, succeeds")], "tv_ft"),
    ("3 Robot initial state: TurboVLA fine-tuned succeeds where OFT+ fails",
     lambda k: s("tv_ft", k) and s("tv_ft_clean", k) and s("oftplus", k) is False
     and cat[k] == "Robot_Initial_States",
     [("tv_ft", "TurboVLA fine-tuned, succeeds"), ("oftplus", "OFT+, fails")], "tv_ft"),
]

print("Runs loaded:", {k: len(v) for k, v in R.items()})
for title, cond, shows, sort_run in THEMES:
    keys = [k for k in cat if cond(k)]
    keys.sort(key=lambda k: sec(sort_run, k))
    print(f"\n== {title}: {len(keys)} candidates")
    for k in keys[:N]:
        print(f"  {k[0]} task {k[1]} ({cat[k]}), {sec(sort_run, k):.0f} s")
        for run, label in shows:
            print(f"      {label:32s} {video(run, k)}")
