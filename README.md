# TaskBoard

Aplicación de **gestión de proyectos y tareas** (Kanban / lista) con cliente **Flutter Web**. Persistencia y autenticación: **API propia** (FastAPI + Postgres, carpeta `backend/`).

## Documentación

| Documento | Audiencia | Contenido |
|-----------|-----------|------------|
| [`MANUAL_USUARIO.md`](MANUAL_USUARIO.md) | Usuario final | Acceso, proyectos, tareas, **asistente IA** |
| [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md) | Desarrollo / producto | IA vía API Taskboard (Cursor Agent, DeepSeek, Ollama) |
| [`docs/INFORME_OLLAMA_REMOTO_TASKBOARD.md`](docs/INFORME_OLLAMA_REMOTO_TASKBOARD.md) | Operación / red | Conectar Ollama remoto al API |
| [`INSTRUCCIONES_AGENTE.md`](INSTRUCCIONES_AGENTE.md) | Despliegue / continuidad | Build web, publicación, workspace, incidencias |
| [`docs/INFORME_CONEXION_CURSOR_PORTATIL_TASKBOARD.md`](docs/INFORME_CONEXION_CURSOR_PORTATIL_TASKBOARD.md) | Desarrollo remoto (portátil) | SSH, Postgres, MCP, API: conectar Cursor a datos TaskBoard |
| [`docs/MCP_TASKBOARD.md`](docs/MCP_TASKBOARD.md) | Cursor / agentes | MCP TaskBoard (Fase 3): CRUD y workspace vía API |

## Código principal

- Frontend: [`frontend/`](frontend/)
- API TaskBoard (FastAPI): [`backend/`](backend/) — despliegue Docker típico: **`/mnt/datos/docker/taskboard-api/`**. Stack dev opcional: [`frontend/docker/docker-compose.yml`](frontend/docker/docker-compose.yml)

## Asistente IA (resumen)

La app llama al **API Taskboard** (`/api/ai/*`), no a Supabase:

- **Nueva tarea** → *Sugerir con IA* (una tarea a partir de un brief).
- **Kanban / lista** → *Asistente IA del proyecto*: modo **Planificar** (chat de backlog) o **Agent (CLI)** (Cursor Agent en la carpeta workspace).

Motores en el servidor (prioridad): **Cursor Agent CLI** → **DeepSeek** → **Ollama**. Configuración: `/mnt/datos/docker/taskboard-api/.env`.

Detalle: [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md). Integración Cursor IDE: [`docs/MCP_TASKBOARD.md`](docs/MCP_TASKBOARD.md).
