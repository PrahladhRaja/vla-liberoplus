"""Clean instructions for LIBERO-Plus variants (robustness test 1, docs/plans/PLAN_test1_instruction_leak.md).

LIBERO-Plus derives task.language from the variant's bddl file name, so perturbation ids leak into the instruction
for every category except Language ("... place it on the plate view 0 0 100 2 352 initstate 0"; GitHub issue #64).
The clean instruction is the parent task's file-name instruction: one of the 40 original LIBERO instructions (the
training-time strings). Language variants keep their rewritten instruction: that rewrite is the perturbation.

Standard library only, so the same code runs in the eval container and on a login node (check below).

    python3 clean_instruction.py <LIBERO-plus root>      # check every task of task_classification.json
"""

import json
import os
import re
import sys
from pathlib import Path

PERTURBED = re.compile(r"_view_|_table_\d|_tb_\d|_light_|_language_|_add_|_level\d| copy")


def filename_instruction(stem: str) -> str:
    """LIBERO-Plus's grab_language_from_filename for non-Language variants."""
    if stem[0].isupper():  # LIBERO-10 / LIBERO-100 names: KITCHEN_SCENE3_turn_on_the_stove...
        stem = stem[stem.find("SCENE") + (8 if "SCENE10" in stem else 7):]
    return " ".join(stem.split("_"))


class CleanInstructions:
    def __init__(self, bddl_root):
        self.bddl_root = Path(bddl_root)
        self._parents = {}

    def parents(self, suite):
        if suite not in self._parents:
            stems = [f[:-5] for f in os.listdir(self.bddl_root / suite) if f.endswith(".bddl")]
            self._parents[suite] = sorted((s for s in stems if not PERTURBED.search(s)), key=len, reverse=True)
        return self._parents[suite]

    def __call__(self, suite, task_name, official):
        """Instruction to feed for variant `task_name` (bddl stem) of `suite`, given its official instruction."""
        if "_language_" in task_name:
            return official
        parent = next((p for p in self.parents(suite) if task_name.startswith(p)), None)
        if parent is None:
            raise ValueError(f"{suite}/{task_name}: no parent task")
        if filename_instruction(task_name) != official:  # our reconstruction of the official string must match
            raise ValueError(f"{suite}/{task_name}: official instruction {official!r} is not file-name derived")
        return filename_instruction(parent)


def check(libero_plus_root):
    root = Path(libero_plus_root) / "libero" / "libero"
    tc = json.load(open(root / "benchmark" / "task_classification.json"))
    clean = CleanInstructions(root / "bddl_files")
    changed, unchanged, strings = 0, 0, {}
    for suite, items in tc.items():
        assert len(clean.parents(suite)) == 10, (suite, len(clean.parents(suite)))
        for it in items:
            name = it["name"]
            official = None if "_language_" in name else filename_instruction(name)
            fed = clean(suite, name, official)
            if "_language_" in name:
                unchanged += 1
            else:
                changed += fed != official
                strings.setdefault(suite, set()).add(fed)
    n = sum(len(v) for v in tc.values())
    print(f"{n} tasks: {changed} non-Language tasks get a clean instruction, {unchanged} Language tasks unchanged")
    for suite, s in strings.items():
        print(f"  {suite}: {len(s)} distinct clean instructions")
    assert changed == n - unchanged and all(len(s) == 10 for s in strings.values())
    print("OK")


if __name__ == "__main__":
    check(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/turing-vla/LIBERO-plus"))
