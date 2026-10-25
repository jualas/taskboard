#!/usr/bin/env python3
"""Cobertura de líneas por capa a partir de frontend/coverage/lcov.info.

Uso: scripts/coverage_by_layer.py [ruta/lcov.info]
Agrupa lib/features/*/{domain,data,presentation} y lib/core, lib/shared.
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

LAYERS = ("domain", "data", "presentation")


def layer_of(path: str) -> str:
    m = re.search(r"lib/features/[^/]+/(domain|data|presentation)/", path)
    if m:
        return m.group(1)
    m = re.search(r"lib/(core|shared)/", path)
    return m.group(1) if m else "otros"


def main() -> int:
    lcov = Path(sys.argv[1] if len(sys.argv) > 1 else "frontend/coverage/lcov.info")
    if not lcov.is_file():
        print(f"No existe {lcov}; ejecuta antes flutter test --coverage")
        return 1
    found: dict[str, int] = defaultdict(int)
    hit: dict[str, int] = defaultdict(int)
    current = None
    for line in lcov.read_text().splitlines():
        if line.startswith("SF:"):
            current = layer_of(line[3:])
        elif line.startswith("LF:") and current:
            found[current] += int(line[3:])
        elif line.startswith("LH:") and current:
            hit[current] += int(line[3:])
    print("| Capa | Líneas | Cubiertas | Cobertura |")
    print("|---|---:|---:|---:|")
    for layer in (*LAYERS, "core", "shared", "otros"):
        if found.get(layer):
            pct = 100 * hit[layer] / found[layer]
            print(f"| {layer} | {found[layer]} | {hit[layer]} | {pct:.1f} % |")
    total_f, total_h = sum(found.values()), sum(hit.values())
    if total_f:
        print(f"| **total** | {total_f} | {total_h} | {100 * total_h / total_f:.1f} % |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
