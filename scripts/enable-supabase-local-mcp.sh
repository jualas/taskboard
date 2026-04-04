#!/usr/bin/env bash
set -euo pipefail

KONG_YML="/mnt/datos/docker/supabase/volumes/api/kong.yml"
SUPABASE_DIR="/mnt/datos/docker/supabase"

if [[ ! -f "$KONG_YML" ]]; then
  echo "No encuentro kong.yml en: $KONG_YML" >&2
  exit 1
fi

BACKUP="${KONG_YML}.bak.$(date +%Y%m%d_%H%M%S)"
echo "Creando backup: $BACKUP"
cp "$KONG_YML" "$BACKUP"

python3 - "$KONG_YML" <<'PY'
import re
import sys

path = sys.argv[1]
lines = open(path, "r", encoding="utf-8").read().splitlines(True)

in_mcp_section = False
block_access = False

targets_to_uncomment = {
  "- name: cors",
  "- name: ip-restriction",
  "config:",
  "allow:",
  "- 127.0.0.1",
  "- ::1",
  "deny: []",
}

out = []
for line in lines:
  if "## MCP endpoint - local access" in line:
    in_mcp_section = True
    block_access = False
    out.append(line)
    continue
  if in_mcp_section and "## Protected Dashboard" in line:
    in_mcp_section = False
    block_access = False
    out.append(line)
    continue

  if in_mcp_section:
    if "# Block access to /mcp by default" in line:
      block_access = True
      out.append(line)
      continue
    if "# Enable local access" in line:
      block_access = False
      out.append(line)
      continue

    # 1) Comentar el request-termination que bloquea /mcp (danger zone)
    if block_access:
      if re.search(r'^\s*-\s*name:\s*request-termination\s*$', line) or \
         re.search(r'^\s*config:\s*$', line) or \
         re.search(r'^\s*status_code:\s*403\s*$', line) or \
         re.search(r'^\s*message:\s*"Access is forbidden\."\s*$', line):
        m = re.match(r'^(\s*)(.*)$', line)
        out.append(m.group(1) + "# " + m.group(2))
        continue

    # 2) Descomentar el bloque ip-restriction/cors preconfigurado (si está en comentarios)
    m = re.match(r'^(\s*)#(.*)$', line)
    if m:
      indent = m.group(1)
      rest = m.group(2).strip()
      # Normalizamos para que "- name: cors" y "config:" coincidan
      # Ej: "#- name: cors" => rest="- name: cors"
      if rest in targets_to_uncomment:
        out.append(indent + m.group(2).lstrip())
        continue

  out.append(line)

open(path, "w", encoding="utf-8").write("".join(out))
print("kong.yml actualizado correctamente.")
PY

echo "Reiniciando Kong..."
cd "$SUPABASE_DIR"
docker compose restart kong

echo "Listo. Prueba endpoint local: http://localhost:8008/mcp?read_only=true"

