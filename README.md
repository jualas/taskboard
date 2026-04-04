# TaskBoard

Aplicación de **gestión de proyectos y tareas** (Kanban / lista) con cliente **Flutter Web**. Persistencia: **API propia** (FastAPI + Postgres, carpeta `backend/`) o, en transición, **Supabase** autohospedado.

## Documentación

| Documento | Audiencia | Contenido |
|-----------|-----------|------------|
| [`MANUAL_USUARIO.md`](MANUAL_USUARIO.md) | Usuario final | Acceso, proyectos, tareas, **asistente IA** |
| [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md) | Desarrollo / producto | Arquitectura IA, contratos API, límites, pruebas |
| [`MANUAL_DESARROLLADOR_SUPABASE.md`](MANUAL_DESARROLLADOR_SUPABASE.md) | Administración | Usuarios Supabase, **operación Ollama + Edge Functions** |
| [`INSTRUCCIONES_AGENTE.md`](INSTRUCCIONES_AGENTE.md) | Despliegue / continuidad | Build web, publicación, incidencias conocidas |

## Código principal

- Frontend: [`frontend/`](frontend/)
- API TaskBoard (FastAPI): código en [`backend/`](backend/) — despliegue Docker operativo: **`/mnt/datos/docker/taskboard-api/`** (datos en `/mnt/datos/docker/volumes/taskboard-api-postgres/`). Stack dev opcional: [`frontend/docker/docker-compose.yml`](frontend/docker/docker-compose.yml)
- Migraciones SQL de referencia (Supabase / histórico): [`supabase/migrations/`](supabase/migrations/)

## Asistente IA (resumen)

Sugerencia de tareas desde el formulario **Nueva tarea** → **Sugerir con IA**. Detalle técnico: [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md).
