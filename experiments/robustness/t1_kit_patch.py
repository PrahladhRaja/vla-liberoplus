"""Apply robustness test 1's CLEAN_INSTRUCTION switch to an eval-kit copy (eval_tasks.py, config.sh). Idempotent.
    python3 t1_kit_patch.py ~/turing_eval_kit"""
import sys
from pathlib import Path

kit = Path(sys.argv[1])
p = kit / "eval_tasks.py"; s = p.read_text()
if "CLEAN_INSTRUCTION" not in s:
    reps = [
        ('''    save_video = os.environ.get("SAVE_VIDEO", "1") == "1"
''', '''    save_video = os.environ.get("SAVE_VIDEO", "1") == "1"
    # Robustness test 1 (diagnostic, not the official protocol): CLEAN_INSTRUCTION=1 feeds non-Language variants
    # their parent task's instruction instead of LIBERO-Plus's file-name instruction with leaked perturbation ids.
    clean_instruction = os.environ.get("CLEAN_INSTRUCTION", "0") == "1"
'''),
        ('''    from libero.libero.envs import OffScreenRenderEnv
''', '''    from libero.libero.envs import OffScreenRenderEnv

    if clean_instruction:
        from clean_instruction import CleanInstructions

        clean = CleanInstructions(get_libero_path("bddl_files"))
        logging.info("CLEAN_INSTRUCTION=1: non-Language variants get their parent task's instruction (diagnostic)")
'''),
        ('''            env.seed(env_seed)
            success, frames = run_episode(env, adapter, task.language, initial_states[0], TASK_MAX_STEPS[suite])''',
         '''            env.seed(env_seed)
            instruction = clean(suite, task.name, task.language) if clean_instruction else task.language
            success, frames = run_episode(env, adapter, instruction, initial_states[0], TASK_MAX_STEPS[suite])'''),
        ('''        append_result({"suite": suite, "task_id": task_id, "success": bool(success), "seconds": round(seconds, 1)})''',
         '''        record = {"suite": suite, "task_id": task_id, "success": bool(success), "seconds": round(seconds, 1)}
        if clean_instruction:
            record.update(instruction_fed=instruction, instruction_official=task.language)
        append_result(record)'''),
    ]
    for a, b in reps:
        assert s.count(a) == 1, f"eval_tasks.py differs from the expected kit version near: {a[:60]!r}"
        s = s.replace(a, b)
    p.write_text(s)
c = kit / "config.sh"; t = c.read_text()
if "CLEAN_INSTRUCTION=" not in t:
    t += ('\n# Robustness test 1 only (diagnostic, NOT the official LIBERO-Plus protocol): 1 = non-Language variants get their\n'
          "# parent task's instruction instead of the file-name instruction with leaked perturbation ids (clean_instruction.py).\n"
          "CLEAN_INSTRUCTION=0\n")
    c.write_text(t)
print("patched", kit)
