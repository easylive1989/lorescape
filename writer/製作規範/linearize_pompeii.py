#!/usr/bin/env python3
"""依定稿路線把龐貝互動劇本攤平成無選項、單結局小說。"""

from __future__ import annotations

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STORIES = ROOT / "writer/創作/龐貝/stories"

# 依玩家在各篇遇到 choice 的順序，指定定稿選項（從 0 起算）。
ROUTES = {
    "01_港口的外地人": [0, 0, 0, 1, 1, 1, 0],
    "02_烤爐熄了": [0, 1, 0, 0, 2],
    "03_井水退了": [0, 0, 0, 0],
    "04_天上那棵樹": [1, 0, 0, 1],
    "05_蠟板": [1, 0, 0, 0, 0, 2],
    "06_上鎖的門": [0, 0, 0, 0, 0],
    "07_靠不了岸": [0, 0, 0, 0, 0],
    "08_普特奧利的新房子": [1, 1, 0, 2],
}


def condition_holds(cond: dict, values: dict) -> bool:
    actual = values.get(cond["var"], 0)
    expected = cond["value"]
    return {
        "==": actual == expected,
        "!=": actual != expected,
        ">=": actual >= expected,
        "<=": actual <= expected,
        ">": actual > expected,
        "<": actual < expected,
    }[cond["op"]]


def apply_values(node: dict, values: dict) -> None:
    for name, amount in node.get("add", {}).items():
        values[name] = values.get(name, 0) + amount
    values.update(node.get("set", {}))


def linearize(path: Path, route: list[int]) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    source_scenes = data["scenes"]
    values = {
        name: spec.get("initial", 0) for name, spec in data.get("variables", {}).items()
    }
    choice_cursor = 0
    output_scenes: dict[str, dict] = {}
    scene_id = data["start"]

    def flatten(nodes: list[dict]) -> tuple[list[dict], str | None]:
        nonlocal choice_cursor
        result: list[dict] = []
        jump: str | None = None
        for original in nodes:
            node = copy.deepcopy(original)
            kind = node.get("t")
            if kind in {"add", "set"}:
                apply_values(node, values)
                continue
            if kind == "if":
                branch = node.get("then", []) if condition_holds(node["cond"], values) else node.get("else", [])
                flattened, nested_jump = flatten(branch)
                result.extend(flattened)
                if nested_jump:
                    return result, nested_jump
                continue
            if kind == "choice":
                if choice_cursor >= len(route):
                    raise ValueError(f"{path}: route 缺少第 {choice_cursor + 1} 個選項")
                visible = [
                    option for option in node["options"]
                    if not option.get("cond") or condition_holds(option["cond"], values)
                ]
                selected_index = route[choice_cursor]
                choice_cursor += 1
                if selected_index >= len(visible):
                    raise ValueError(f"{path}: 第 {choice_cursor} 個選項索引 {selected_index} 不可見")
                selected = visible[selected_index]
                apply_values(selected, values)
                flattened, nested_jump = flatten(selected.get("then", []))
                result.extend(flattened)
                if nested_jump:
                    return result, nested_jump
                if selected.get("goto"):
                    return result, selected["goto"]
                for branch in selected.get("branch", []):
                    if branch.get("default") or condition_holds(branch["cond"], values):
                        return result, branch["goto"]
                continue
            node.pop("assumes", None)
            apply_values(node, values)
            result.append(node)
            if node.get("goto"):
                jump = node.pop("goto")
                return result, jump
        return result, jump

    ending_id: str | None = None
    while scene_id not in output_scenes:
        source = source_scenes[scene_id]
        scene = copy.deepcopy(source)
        scene["nodes"], jump = flatten(source.get("nodes", []))
        next_scene = jump or source.get("next")
        scene.pop("next", None)
        if source.get("isEnding"):
            ending_id = source.get("endingId")
        elif next_scene:
            scene["next"] = next_scene
        output_scenes[scene_id] = scene
        if source.get("isEnding") or not next_scene:
            break
        scene_id = next_scene

    if choice_cursor != len(route):
        raise ValueError(f"{path}: route 有 {len(route) - choice_cursor} 個多餘選項")
    if not ending_id:
        raise ValueError(f"{path}: 定稿路線沒有抵達結局")

    data["variables"] = {}
    data["scenes"] = output_scenes
    data["endings"] = {ending_id: data["endings"][ending_id]}
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for folder, route in ROUTES.items():
        linearize(STORIES / folder / "story.json", route)
        print(f"linearized {folder}")


if __name__ == "__main__":
    main()
