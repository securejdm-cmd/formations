#!/usr/bin/env python3
"""Add explicit types to := assignments after Variant param migration."""
import re
import subprocess
import sys

FILES = [
    "scripts/sim/sim_combat_resolver.gd",
    "scripts/sim/sim_formation_geometry.gd",
    "scripts/sim/sim_edge_contact.gd",
]

FLOAT_HINTS = (
    "dist_m", "reach", "strength_pct", "cohesion_factor", "base", "gap_m",
    "center_distance_m", "current_px", "half_correction_px", "shift_m",
    "move_px", "gap_px", "max_dim", "half_depth", "half_frontage", "dist",
    "along", "across", "front_touch", "cohesion_drain", "pct_lost", "applied",
    "old_strength", "reach_px", "half_depth_m", "half_frontage_m",
)
VECTOR_HINTS = ("to_b", "to_a", "dir", "forward", "delta", "old_pos", "correction_dir", "local", "push_normal")
BOOL_HINTS = ("a_sees_b", "b_sees_a", "ok", "has_contact")


def guess_type(name: str) -> str:
    if name in BOOL_HINTS or name.startswith("is_") or name.startswith("has_"):
        return "bool"
    if name in VECTOR_HINTS or name.endswith("_dir") or name.endswith("_normal"):
        return "Vector2"
    if name in FLOAT_HINTS or name.endswith("_m") or name.endswith("_px") or name.endswith("_pct"):
        return "float"
    if name.endswith("_i") or name.endswith("_idx"):
        return "int"
    return "Variant"


def fix_file(path: str) -> None:
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    out = []
    for line in lines:
        m = re.match(r"^(\s*)var\s+(\w+)\s*:=\s*(.+)$", line)
        if m:
            indent, name, expr = m.groups()
            if name in ("attacker", "defender", "loser", "mover", "partner", "unit", "enemy", "other", "seg_attacker", "seg_defender"):
                out.append(line)
                continue
            typ = guess_type(name)
            out.append(f"{indent}var {name}: {typ} = {expr}\n")
        else:
            out.append(line)
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)


for fp in FILES:
    fix_file(fp)

print("fixed", len(FILES), "files")
