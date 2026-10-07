# TaskBoard API (FastAPI + Postgres)

Backend de persistencia, autenticación JWT y sugerencias IA para TaskBoard.

## Requisitos

- Python 3.11+
- PostgreSQL 14+

## Despliegue en el mini PC (recomendado)

El stack **Docker de producción** vive fuera del repo, alineado con el resto de servicios:

- **Compose y `.env`:** `/mnt/datos/docker/taskboard-api/`
- **Datos Postgres:** `/mnt/datos/docker/volumes/taskboard-api-postgres/`

Instrucciones detalladas: **`/mnt/datos/docker/taskboard-api/README.md`**.

Resumen:

```bash
cd /mnt/datos/docker/taskboard-api
cp env.example .env
# JWT_SECRET, DEEPSEEK_API_KEY, …
docker compose up -d --build
```

La imagen se construye desde esta carpeta del repo (`backend/`); si movés el repo, definí `TASKBOARD_BACKEND_SRC` en `.env` junto al compose.

## Instalación local (sin Docker)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Editar .env: DATABASE_URL, JWT_SECRET
```

Crear base y esquema (con Postgres accesible y `DATABASE_URL` en `.env`):

```bash
psql "$DATABASE_URL" -f migrations/001_fresh_install.sql
```

Crear primer usuario (si `ALLOW_REGISTRATION=true`):

```bash
curl -X POST http://127.0.0.1:8000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"tu@correo","password":"secreto"}'
```

Arrancar:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

OpenAPI: `http://127.0.0.1:8000/docs`

## Migrar datos desde un Postgres antiguo (opcional)

1. `pg_dump` / restaurar datos en la instancia nueva si aplica.
2. Ajustar esquema y FK al modelo actual (`001_fresh_install.sql` como referencia) según tu dump.
3. Asignar contraseñas bcrypt a usuarios que lo necesiten:

```bash
export DATABASE_URL=...
python scripts/set_password.py tu@correo nueva_clave
```

## Stack opcional en el repo (desarrollo)

`frontend/docker/docker-compose.yml`: Postgres + API + Nginx con datos en  
`/mnt/datos/docker/volumes/taskboard-frontend-stack-postgres/` (no usar a la vez que el Postgres de `taskboard-api` salvo que uses otro directorio).

## Flutter

Configurar `TASKBOARD_API_URL` o `config.json` → `taskboardApi.baseUrl` (sin barra final).

Producción con Caddy (`taskboard-web`): `taskboardApi.useSameOriginProxy: true`, `proxyPrefix: "/api-taskboard"`, `baseUrl` vacío.
