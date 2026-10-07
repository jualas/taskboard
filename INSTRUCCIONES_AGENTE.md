# INSTRUCCIONES AGENTE

Documento técnico de continuidad para agentes (estado operativo real y procedimientos).

## 1) Contexto del proyecto
- Proyecto: `taskboard` (repositorio de trabajo independiente en esta carpeta).
- Frontend: Flutter Web (`frontend/`).
- Backend datos/auth: **API TaskBoard (FastAPI + Postgres)** (`backend/`). Si no hay API configurada, la app puede usar **almacenamiento local** (`StorageService`) solo como demostración.
- Objetivo: mantener login y despliegue web estables tanto en LAN como por túnel Cloudflare.

## 2) Ubicaciones y despliegue actual
- Raíz del proyecto: `.../Proyectos/taskboard`.
- Frontend fuente: `frontend/`.
- Build generado: `frontend/build/web`.
- Publicación web activa: `/mnt/datos/docker/taskboard-web/public`.
- Stack web activo: `/mnt/datos/docker/taskboard-web/docker-compose.yml`.
- Contenedores activos de publicación:
  - `taskboard-web` (Caddy, puerto `8580`) — proxy **`/api-taskboard/*`** hacia el API FastAPI (según `Caddyfile`).
  - `kanban-cloudflared` (túnel para `kanban.jualas.es`).
- **API + Postgres (producción):** `/mnt/datos/docker/taskboard-api/docker-compose.yml` — datos en `/mnt/datos/docker/volumes/taskboard-api-postgres/`.
- Stack Docker **en el repo** (Postgres + API + Nginx estáticos, dev): `frontend/docker/docker-compose.yml` — datos en `/mnt/datos/docker/volumes/taskboard-frontend-stack-postgres/`.

## 3) Estado operativo validado
- Acceso LAN: `http://<IP_SERVIDOR>:8580` (OK).
- Acceso externo: `https://kanban.jualas.es` (OK).
- Login contra **API Taskboard** (JWT).

## 4) Autenticación y configuración
- Configuración empaquetada en frontend:
  - `frontend/assets/data/config.json` — solo **`taskboardApi`** (`useSameOriginProxy` + `proxyPrefix` `/api-taskboard`, `baseUrl` vacío en web detrás del mismo origen).
- Flujo de inicialización (`frontend/lib/main.dart`, `_initBootstrap`):
  1. `--dart-define` `TASKBOARD_API_URL` / `TASKBOARD_API_SAME_ORIGIN_PROXY`
  2. `taskboardApi` en `config.json` (en web, `baseUrl` vacío + `useSameOriginProxy` usa el origen actual + prefijo)
  3. Si no hay API: fallback local (`SharedPreferences` + `LocalAuthService`)
- Producción estática: tras cada build, asegurar `config.json` embebido si cambia.
- Login: **`ApiAuthService`** (`/api/auth/login`, JWT en preferencias).

## 4.1) API TaskBoard (FastAPI) en producción (`taskboard-web` + Caddy)
- Stack Docker: **`/mnt/datos/docker/taskboard-api/`** (`docker compose up -d --build`). Secretos en `/mnt/datos/docker/taskboard-api/.env` (plantilla `env.example`); código del build: repo `taskboard/backend/` (variable opcional `TASKBOARD_BACKEND_SRC` en `.env` si el repo se mueve).
- Datos Postgres persistentes: **`/mnt/datos/docker/volumes/taskboard-api-postgres/`**.
- Migraciones: `backend/migrations/001_fresh_install.sql`, **`002_workspace_path.sql`**, **`003_workspace_snapshots.sql`**, **`004_agent_sessions.sql`**.
- Caddy (`/mnt/datos/docker/taskboard-web/Caddyfile`) enruta `/api-taskboard/` al API.
- `config.json` debe incluir `taskboardApi.useSameOriginProxy: true` para que el cliente web use el mismo host sin CORS.

### Workspace (Fase 4)
- Inventario automático de subcarpetas bajo **`WORKSPACE_ROOTS`** (`docker/`, `Proyectos/`).
- Endpoint: **`GET /api/projects/workspace-inventory`** — carpetas detectadas, vínculo con proyecto, huérfanos (ruta configurada pero carpeta ausente).
- UI: icono **Inventario workspace** en la barra de Mis Proyectos; acciones **Crear proyecto** y **Vincular** para carpetas sin proyecto.
- MCP: herramienta **`list_workspace_inventory`**.

### Workspace (Fase 3 — Cursor)
- **Motor IA preferido (mini PC):** CLI **`agent`** (`CURSOR_AGENT_ENABLED=true` en `.env` del API).
  - Prioridad: Cursor Agent → DeepSeek → Ollama.
  - Invocación headless: `agent --print --trust --workspace <carpeta>`.
  - Puente manual: **`scripts/cursor_taskboard_bridge.py --agent "..."`**.
- **Export TASKBOARD.md:** `POST /api/projects/{id}/taskboard-md`, botón en Kanban, MCP `export_taskboard_md`, script **`scripts/export_taskboard_md.py`**.
- **Prompt IDE (Cursor):** menú *Prompt IDE (Cursor)* / `POST /api/projects/{id}/ide-session` (exporta MD + plantilla personalizada); `GET .../ide-prompt` solo texto.
- Servidor MCP: **`mcp-taskboard/`** (herramientas CRUD + workspace vía API JWT).
- Documentación: **`docs/MCP_TASKBOARD.md`**, ejemplo `mcp-taskboard/mcp.json.example`.
- Endpoint: **`GET /api/projects/by-workspace-path?path=...`** (resolver proyecto desde cwd del repo).
- Script puente SDK: **`scripts/cursor_taskboard_bridge.py`** (`--path` / `--project-id`, opcional `--agent`).

### Workspace (Fase 2)
- Cron **interno** en `taskboard-api` (asyncio): cada `WORKSPACE_SNAPSHOT_INTERVAL_MIN` minutos (default 30).
- Tablas: `workspace_snapshots` (historial), `workspace_suggestions` (pendientes/aplicadas/descartadas).
- Heurísticas locales (commit nuevo, dirty tree, docker parado) + IA opcional en cambio de commit (`WORKSPACE_AI_SUGGESTIONS`).
- Endpoints: historial, sugerencias, `POST .../workspace-sync`, aplicar/descartar sugerencia.
- UI: menú **Sugerencias workspace** en lista de proyectos; badge con contador pendiente.
- **Abrir en Cursor**: menú del proyecto, barra Kanban/lista (icono terminal), diálogo Editar y panel de sugerencias (`cursor://file/...` + copiar ruta).

### Workspace (Fase 1)
- Cada proyecto puede vincular una **carpeta local** (`workspace_path`): stacks en `~/datos/docker`, código en `~/datos/Proyectos`.
- El contenedor **`taskboard-api`** debe montar esas raíces en **lectura/escritura** (`:rw`) para exportar `TASKBOARD.md` y para `docker compose ps`.
- Variable **`WORKSPACE_ROOTS`** en `.env` del API (lista separada por comas); debe coincidir con los montajes.
- Endpoints: `POST /api/projects/workspace-snapshot-preview`, `GET /api/projects/{id}/workspace-snapshot`.
- **Export Markdown:** `GET/POST /api/projects/{id}/taskboard-md` → escribe `TASKBOARD.md` en el workspace (variable `TASKBOARD_MD_FILENAME`; auto con `TASKBOARD_MD_AUTO_EXPORT=true`).
- El chat IA (`POST /api/ai/chat` con `projectId`) incluye snapshot git/docker en el contexto.
- UI: **Editar proyecto** → campo *Carpeta workspace* → *Verificar carpeta*.

## 5) Asistente IA
- **Backend único:** API FastAPI (`taskboard-api`); **no** hay Supabase ni Edge Functions en el flujo IA actual.
- Tareas: formulario **Nueva tarea** → **Sugerir con IA** (`task_form.dart`).
- Proyecto: en Kanban/lista → icono **Asistente IA del proyecto** (`project_ai_chat_panel.dart`): modos **Planificar** (chat backlog) y **Agent (CLI)** (SSE).
- Cliente: `ai_assistant_service.dart` → **`POST /api/ai/suggest`**, **`POST /api/ai/chat`**, **`POST /api/ai/agent-stream`** (JWT; chat con `projectId` si hay workspace).
- **Prioridad motor IA** (`.env` del API): Cursor Agent CLI (`CURSOR_AGENT_ENABLED`) → DeepSeek (`DEEPSEEK_API_KEY`) → Ollama (`OLLAMA_BASE_URL`). Ver `backend/app/routers/ai.py` → `_invoke_llm`.
- Modo **Agent (CLI)**: streaming terminal; opción **ejecutar** (editar repo); **reanudar sesión** (`agent --resume`) persistida por proyecto; historial de prompts en BD.
- Endpoints sesión/historial: **`GET/DELETE /api/projects/{id}/agent-session`**, **`GET /api/projects/{id}/agent-runs`**.
- Tablas: `project_agent_sessions`, `project_agent_runs` (migración **`004_agent_sessions.sql`**).
- Backend: `backend/app/routers/ai.py`, `backend/app/agent_sessions.py`, `backend/app/cursor_agent.py`.
- Variables IA: **`/mnt/datos/docker/taskboard-api/.env`** (plantilla `backend/.env.example`).
- Documentación: **`docs/IA_ASISTENTE.md`**, Ollama remoto: **`docs/INFORME_OLLAMA_REMOTO_TASKBOARD.md`**, MCP Cursor: **`docs/MCP_TASKBOARD.md`**.

## 6) Procedimiento build + publicación (obligatorio)
Ejecutar desde `frontend/`:

1. Build (ejemplo con imagen Flutter):
   - `docker run --rm -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable bash -lc "flutter pub get && flutter build web --release"`
2. **Cache-bust del túnel** (si el dominio no refleja el build):
   - Desde la raíz del repo: `bash scripts/patch-web-index-cache-bust.sh frontend/build/web`
3. Publicar en ruta activa (copiar `build/web` a `/mnt/datos/docker/taskboard-web/public`).
4. Reiniciar contenedores web/túnel si aplica.

## 7) Incidencias conocidas (y solución)
- Caché de `main.dart.js` antiguo: `patch-web-index-cache-bust.sh`, cabeceras `no-store` en Caddy, DNS del túnel correcto.
- `Service Worker` / contexto no seguro: usar HTTPS en producción.

## 8) Trabajo por Samba y Git
- Avisos de Git por “dubious ownership”: `git config --global --add safe.directory "<ruta del repo>"`.

## 9) Seguridad
- No publicar `JWT_SECRET` ni claves de API en documentación de usuario.
- Cambio de contraseña: endpoint/API del backend (`ApiAuthService.changePassword`).

---
Para uso funcional: `MANUAL_USUARIO.md`.  
Para IA: `docs/IA_ASISTENTE.md`.
