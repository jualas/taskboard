#!/usr/bin/env bash
# Instala/actualiza el servidor MCP TaskBoard en ~/.cursor/mcp.json
#
# Uso:
#   ./scripts/install-cursor-mcp-taskboard.sh           # mini PC (usa .env del API en /mnt/datos/docker)
#   ./scripts/install-cursor-mcp-taskboard.sh laptop  # portátil (usa ~/.config/taskboard/mcp.env)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_DIR="${REPO_ROOT}/mcp-taskboard"
RUN_SCRIPT="${MCP_DIR}/run-mcp-taskboard.sh"
CURSOR_MCP="${HOME}/.cursor/mcp.json"
MODE="${1:-local}"

if [[ ! -f "${MCP_DIR}/server.py" ]]; then
  echo "No se encuentra mcp-taskboard en ${MCP_DIR}" >&2
  exit 1
fi

chmod +x "${RUN_SCRIPT}"

# Venv + dependencias
if [[ ! -x "${MCP_DIR}/.venv/bin/python" ]]; then
  echo ">> Creando venv en mcp-taskboard..."
  python3 -m venv "${MCP_DIR}/.venv"
fi
echo ">> Instalando dependencias MCP..."
"${MCP_DIR}/.venv/bin/pip" install -q -r "${MCP_DIR}/requirements.txt"

# Credenciales según modo
if [[ "$MODE" == "laptop" ]]; then
  LAPTOP_ENV="${HOME}/.config/taskboard/mcp.env"
  mkdir -p "${HOME}/.config/taskboard"
  if [[ ! -f "$LAPTOP_ENV" ]]; then
    cp "${MCP_DIR}/mcp.env.laptop.example" "$LAPTOP_ENV"
    chmod 600 "$LAPTOP_ENV"
    echo ""
    echo ">> Creado ${LAPTOP_ENV}"
    echo "   Edítalo con tu email/clave TaskBoard y la IP del mini PC (API_BASE_URL)."
    echo "   Luego vuelve a ejecutar este script."
    exit 0
  fi
  if grep -q 'tu@correo\|tu_clave' "$LAPTOP_ENV" 2>/dev/null; then
    echo ">> Edita ${LAPTOP_ENV} (aún tiene valores de ejemplo)." >&2
    exit 1
  fi
  # API_BASE_URL del mcp.env (p. ej. http://<IP-LAN-SERVIDOR>:8101 o túnel SSH a 127.0.0.1:8101)
  LAPTOP_API_URL="$(grep -E '^API_BASE_URL=' "$LAPTOP_ENV" | tail -1 | cut -d= -f2-)"
  LAPTOP_API_URL="${LAPTOP_API_URL:-http://127.0.0.1:8101}"
  ENV_BLOCK=$(python3 - <<PY
import json
print(json.dumps({
  "TASKBOARD_ENV_FILE": "${LAPTOP_ENV}",
  "TASKBOARD_API_URL": "${LAPTOP_API_URL}"
}))
PY
)
else
  API_ENV="/mnt/datos/docker/taskboard-api/.env"
  if [[ ! -f "$API_ENV" ]]; then
    echo "No existe ${API_ENV}. Usa modo laptop o define TASKBOARD_ENV_FILE." >&2
    exit 1
  fi
  ENV_BLOCK=$(python3 - <<PY
import json
print(json.dumps({
  "TASKBOARD_ENV_FILE": "${API_ENV}",
  "TASKBOARD_API_URL": "http://127.0.0.1:8101"
}))
PY
)
fi

# Probar conexión
echo ">> Probando API TaskBoard..."
export TASKBOARD_ENV_FILE=$(python3 -c "import json; print(json.loads('''${ENV_BLOCK}''')['TASKBOARD_ENV_FILE'])")
"${MCP_DIR}/.venv/bin/python" -c "
import sys
sys.path.insert(0, '${MCP_DIR}')
from taskboard_client import TaskboardClient
c = TaskboardClient.from_env('${TASKBOARD_ENV_FILE}')
n = len(c.request_json('GET', '/api/projects'))
print(f'   OK — {n} proyecto(s) visibles')
"

# Fusionar mcp.json
mkdir -p "${HOME}/.cursor"
python3 - <<PY
import json
from pathlib import Path

cursor_mcp = Path("${CURSOR_MCP}")
run_script = "${RUN_SCRIPT}"
env = json.loads('''${ENV_BLOCK}''')

data = {"mcpServers": {}}
if cursor_mcp.is_file():
    data = json.loads(cursor_mcp.read_text(encoding="utf-8"))
    if "mcpServers" not in data:
        data["mcpServers"] = {}

data["mcpServers"]["taskboard"] = {
    "command": run_script,
    "env": env,
}

cursor_mcp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f">> Actualizado {cursor_mcp}")
print("   Servidor añadido: taskboard")
PY

echo ""
echo "Listo. Reinicia Cursor (o recarga MCP) para activar TaskBoard."
echo "Documentación: ${REPO_ROOT}/docs/MCP_TASKBOARD.md"
