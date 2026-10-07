#!/usr/bin/env python3
"""Exporta TASKBOARD.md al workspace de un proyecto vía API."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "mcp-taskboard"))

from taskboard_client import TaskboardApiError, TaskboardClient  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="Exportar tareas TaskBoard a TASKBOARD.md")
    parser.add_argument("--project-id", type=int, required=True, help="ID del proyecto")
    parser.add_argument("--env-file", help="Ruta .env con API_BASE_URL y credenciales")
    parser.add_argument("--filename", default="", help="Nombre del archivo (default TASKBOARD.md)")
    parser.add_argument("--dry-run", action="store_true", help="Solo generar, no escribir")
    parser.add_argument("--json", action="store_true", help="Salida JSON")
    args = parser.parse_args()

    client = TaskboardClient.from_env(args.env_file)
    body: dict = {"dryRun": args.dry_run}
    if args.filename.strip():
        body["filename"] = args.filename.strip()

    try:
        data = client.request_json(
            "POST",
            f"/api/projects/{args.project_id}/taskboard-md",
            body=body,
        )
    except TaskboardApiError as e:
        print(json.dumps({"error": e.detail, "status": e.status}, ensure_ascii=False), file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        path = data.get("file_path") or data.get("filePath") or "?"
        written = data.get("written", False)
        count = data.get("task_count") or data.get("taskCount") or 0
        action = "escrito en" if written else "generado (dry-run)"
        print(f"TASKBOARD.md {action}: {path} ({count} tareas)")
        if args.dry_run and data.get("content"):
            print("\n--- preview ---\n")
            print(str(data["content"])[:2000])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
