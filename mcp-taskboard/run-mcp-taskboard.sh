#!/usr/bin/env bash
# Lanza el servidor MCP TaskBoard (stdio). Carga credenciales desde TASKBOARD_ENV_FILE.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="${SCRIPT_DIR}/.venv/bin/python"
SERVER="${SCRIPT_DIR}/server.py"

if [[ ! -x "$VENV_PY" ]]; then
  echo "Falta venv en mcp-taskboard. Ejecuta: cd \"$SCRIPT_DIR\" && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
  exit 1
fi

# TASKBOARD_ENV_FILE puede venir del mcp.json o por defecto (mini PC)
if [[ -z "${TASKBOARD_ENV_FILE:-}" ]]; then
  if [[ -f /mnt/datos/docker/taskboard-api/.env ]]; then
    export TASKBOARD_ENV_FILE="/mnt/datos/docker/taskboard-api/.env"
  elif [[ -f "${HOME}/.config/taskboard/mcp.env" ]]; then
    export TASKBOARD_ENV_FILE="${HOME}/.config/taskboard/mcp.env"
  fi
fi

if [[ -z "${TASKBOARD_API_URL:-}" && -f "${TASKBOARD_ENV_FILE:-}" ]]; then
  # taskboard_client lee API_BASE_URL del .env
  :
fi

exec "$VENV_PY" "$SERVER"
