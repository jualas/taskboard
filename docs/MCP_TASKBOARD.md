# MCP TaskBoard — integración Cursor

Servidor [Model Context Protocol](https://modelcontextprotocol.io) que expone la **API TaskBoard (FastAPI)** como herramientas para agentes en Cursor. Complementa el MCP Postgres (solo lectura SQL) con **CRUD alineado a la app**, contexto de **workspace** y flujos IDE.

**Prerrequisito:** la app TaskBoard usa el mismo API (`/mnt/datos/docker/taskboard-api/` en producción). No hay integración MCP con Supabase.

## Qué permite

| Herramienta MCP | Uso |
|-----------------|-----|
| `list_projects` | Ver proyectos accesibles |
| `get_project` | Detalle de un proyecto |
| `resolve_project_by_path` | Encontrar proyecto por carpeta workspace (cwd del repo) |
| `list_tasks` | Backlog / kanban de un proyecto |
| `create_task` | Crear tarea |
| `update_task_status` | Mover tarea en el flujo (`pending`, `in_progress`, `completed`) |
| `get_workspace_snapshot` | Git + docker del workspace |
| `list_workspace_suggestions` | Sugerencias automáticas (Fase 2) |
| `sync_workspace` | Forzar sync snapshot |
| `apply_workspace_suggestion` | Aplicar sugerencia |
| `export_taskboard_md` | Escribir `TASKBOARD.md` en el workspace (tareas + estados) |
| `get_ide_development_prompt` | Plantilla de prompt Cursor rellenada por proyecto |
| `prepare_ide_session` | Export + prompt en un paso (flujo IDE recomendado) |
| `list_workspace_inventory` | Carpetas en `WORKSPACE_ROOTS` sin/vinculadas (Fase 4) |

Implementación: [`mcp-taskboard/server.py`](../mcp-taskboard/server.py).

## Instalación

### Automática (recomendada)

**En el mini PC** (Cursor con acceso a `/mnt/datos/docker/taskboard-api/.env`):

```bash
cd /ruta/al/repo/taskboard
./scripts/install-cursor-mcp-taskboard.sh
```

**En el portátil** (misma LAN que el mini PC):

```bash
cd /ruta/al/repo/taskboard   # clone o copia del repo
./scripts/install-cursor-mcp-taskboard.sh laptop
# Edita ~/.config/taskboard/mcp.env (email, clave, IP del mini PC)
./scripts/install-cursor-mcp-taskboard.sh laptop   # segunda vez tras editar
```

Reinicia Cursor. El servidor aparece como **`taskboard`** en MCP.

El script crea el venv, instala dependencias, prueba login contra el API y fusiona la entrada en `~/.cursor/mcp.json`.

### Manual

```bash
cd mcp-taskboard
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
chmod +x run-mcp-taskboard.sh
```

Copia [`mcp-taskboard/mcp.json.example`](../mcp-taskboard/mcp.json.example) a `~/.cursor/mcp.json` (fusionando con servidores existentes).

**Variables de entorno del servidor MCP**

| Variable | Uso |
|----------|-----|
| `TASKBOARD_ENV_FILE` | Ruta al `.env` del API (email/clave JWT o credenciales dedicadas) |
| `TASKBOARD_API_URL` | Base URL del API (`http://127.0.0.1:8101` en mini PC; IP LAN o túnel en portátil) |

En portátil, plantilla: [`mcp-taskboard/mcp.env.laptop.example`](../mcp-taskboard/mcp.env.laptop.example).

## Flujo bidireccional recomendado

1. En TaskBoard: **Editar proyecto** → vincular **Carpeta workspace** (p. ej. `/mnt/datos/docker/oposiciones`).
2. En Cursor: abrir esa misma carpeta como proyecto.
3. El agente puede llamar `resolve_project_by_path` con el cwd o path absoluto.
4. Leer tareas + snapshot + sugerencias; crear/actualizar tareas tras commits o revisiones de código.
5. **Exportar espejo Markdown:** botón **Exportar TASKBOARD.md** en la web, MCP `export_taskboard_md` o:

```bash
python3 scripts/export_taskboard_md.py --project-id 1
```

Genera `TASKBOARD.md` en la raíz del workspace (tareas por estado, IDs, checklist). Útil para Cursor IDE o el CLI `agent` fuera del chat web.

## Relación con la IA en la app web

La **app Flutter** no usa este MCP directamente. El chat web llama al API:

- `POST /api/ai/suggest` — sugerir tarea
- `POST /api/ai/chat` — planificar backlog
- `POST /api/ai/agent-stream` — Cursor Agent CLI en el servidor

El **MCP TaskBoard** es para **Cursor en tu máquina** (portátil o mini PC): sincronizar tablero ↔ repo mientras desarrollas. Ver [`docs/IA_ASISTENTE.md`](IA_ASISTENTE.md) para la arquitectura IA del servidor.

## Script puente (Cursor Agent CLI)

Desde la raíz del repo (usa el comando **`agent`** instalado en el mini PC):

```bash
# Solo contexto TaskBoard (sin agente)
python3 scripts/cursor_taskboard_bridge.py --path /mnt/datos/docker/oposiciones

# Ejecutar Cursor Agent en el workspace del proyecto
python3 scripts/cursor_taskboard_bridge.py --path /mnt/datos/docker/oposiciones \
  --agent "Lista tareas pendientes relacionadas con los cambios git sin commitear"
```

Variables opcionales: `CURSOR_AGENT_BIN`, `CURSOR_AGENT_MODE` (default `ask`), `CURSOR_AGENT_HOME`.

## Portátil fuera de la LAN

Si no estás en la misma red, abre túnel SSH y apunta el `.env` del portátil a localhost:

```bash
ssh -N -L 8101:127.0.0.1:8101 usuario@<IP-LAN-SERVIDOR>
```

En `~/.config/taskboard/mcp.env`:

```env
API_BASE_URL=http://127.0.0.1:8101
API_AUTH_EMAIL=...
API_AUTH_PASSWORD=...
```

Documento ampliado: [`INFORME_CONEXION_CURSOR_PORTATIL_TASKBOARD.md`](INFORME_CONEXION_CURSOR_PORTATIL_TASKBOARD.md) § F.

## Seguridad

- No commitear `mcp.json` ni `mcp.env` con contraseñas.
- Preferir usuario con permisos mínimos en TaskBoard.
- El MCP usa la misma autenticación JWT que la app web (`POST /auth/login`).

## Referencias

- API: [`backend/README.md`](../backend/README.md), OpenAPI en `:8101/docs`
- Portátil / túnel: [`INFORME_CONEXION_CURSOR_PORTATIL_TASKBOARD.md`](INFORME_CONEXION_CURSOR_PORTATIL_TASKBOARD.md)
- Workspace: [`INSTRUCCIONES_AGENTE.md`](../INSTRUCCIONES_AGENTE.md) § Workspace
- Asistente IA (servidor): [`IA_ASISTENTE.md`](IA_ASISTENTE.md)
