# Informe: conexión desde el portátil (Cursor) a TaskBoard

**Audiencia:** agente o desarrollador en el **portátil** de la misma red que el **mini PC** donde corre TaskBoard.  
**Objetivo:** elegir e implementar la vía más adecuada para **consultar** (y, si hace falta, **modificar**) proyectos y tareas alineados con la aplicación.

---

## 1. Contexto del sistema

| Componente | Rol |
|------------|-----|
| **PostgreSQL** | Fuente de verdad: usuarios, proyectos, miembros, tareas, snapshots workspace, sesiones agent. |
| **API FastAPI** (`backend/`) | Reglas de negocio, JWT, permisos, **IA** (suggest/chat/agent-stream), workspace. |
| **Flutter Web** | Cliente; habla con el API vía **mismo origen** (`/api-taskboard/`) o URL directa en LAN. |

**Despliegue típico en el mini PC**

- Compose API: `/mnt/datos/docker/taskboard-api/`  
- Compose web: `/mnt/datos/docker/taskboard-web/`  
- Contenedores habituales: `taskboard-postgres`, `taskboard-api`, `taskboard-web` (Caddy)  
- API expuesta al host: **`http://<IP_MINIPC>:8101`** (puerto **8101→8000** en el compose estándar).  
- Web pública: **`https://kanban.jualas.es`** o LAN **`http://<IP_MINIPC>:8580`** con prefijo **`/api-taskboard/`** hacia el API.  
- Datos Postgres (volumen): `/mnt/datos/docker/volumes/taskboard-api-postgres/`  

Sustituir `<IP_MINIPC>` por la IP LAN real (ej. `<IP-LAN-SERVIDOR>`).

**Nota:** TaskBoard **ya no usa Supabase** para datos ni IA. Toda integración externa debe ir contra el **API FastAPI**.

---

## 2. Modelo de datos (consultas SQL)

Definido en `backend/migrations/001_fresh_install.sql` (+ migraciones workspace y agent).

| Tabla | Uso |
|-------|-----|
| `app_users` | Usuarios (`id` UUID, `email`, `password_hash`, …). |
| `projects` | Proyectos (`id`, `title`, `description`, `status`, `owner_id`, `workspace_path`, …). |
| `project_members` | Miembros y roles (`owner` / `editor` / `viewer`). |
| `tasks` | Tareas (`id`, `project_id`, `title`, `description`, `status`, `complexity`, `tags` JSONB, `subtasks` JSONB, fechas, …). |
| `workspace_snapshots` | Historial de snapshots git/docker (Fase 2). |
| `project_agent_sessions` | Sesión Cursor Agent por proyecto (Fase 3). |

**Credenciales por defecto del compose de ejemplo** (cambiar en producción):

- Usuario DB: `taskboard`  
- Contraseña DB: `taskboard`  
- Base: `taskboard`  
- Puerto **interno** Postgres: `5432` (solo dentro de Docker hasta que se mapee al host).

**Consultas de lectura útiles**

```sql
-- Proyectos
SELECT id, title, status, workspace_path, owner_id, created_at, updated_at
FROM projects
ORDER BY id;

-- Tareas por proyecto
SELECT t.id, t.project_id, t.title, t.status, t.complexity, t.tags, t.created_at
FROM tasks t
ORDER BY t.project_id, t.id;

-- Proyecto + número de tareas
SELECT p.id, p.title, COUNT(t.id) AS num_tareas
FROM projects p
LEFT JOIN tasks t ON t.project_id = p.id
GROUP BY p.id, p.title
ORDER BY p.id;
```

**Advertencia:** escrituras SQL directas pueden romper invariantes que el API mantiene. Para CRUD “oficial”, preferir el **API** o el **MCP TaskBoard** (apartado F).

---

## 3. Opciones de conexión (elegir según necesidad)

### A. Solo lectura + seguridad + simplicidad → **Túnel SSH + PostgreSQL**

**Cuándo:** Explorar datos, generar informes, ayudar al desarrollo sin exponer el puerto 5432 a la LAN.

**En el mini PC**

1. Servicio SSH (`sshd`) activo y usuario con acceso.  
2. Postgres accesible en **localhost del mini PC**. Si el contenedor no publica puerto, en `docker-compose.yml` del servicio `postgres` añadir solo loopback:

   ```yaml
   ports:
     - '127.0.0.1:5432:5432'
   ```

   Luego `docker compose up -d`.

**En el portátil**

```bash
ssh -N -L 5433:127.0.0.1:5432 USUARIO@<IP_MINIPC>
```

- Cursor / DBeaver / `psql` se conectan a **`127.0.0.1:5433`** (el `5433` evita conflicto con Postgres local en el portátil).

**Cadena URI (ejemplo)**

```text
postgresql://taskboard:CONTRASEÑA@127.0.0.1:5433/taskboard
```

**Extensiones Cursor:** PostgreSQL, SQLTools + driver Postgres, etc.

---

### B. Usuario de base de datos **solo lectura** (recomendado para el día a día)

**Cuándo:** Mismo que A, pero limitar daño si filtran credenciales del portátil.

**En el mini PC** (una vez, como superusuario en Postgres):

```sql
CREATE ROLE taskboard_readonly WITH LOGIN PASSWORD 'GENERAR_CLAVE_FUERTE';

GRANT CONNECT ON DATABASE taskboard TO taskboard_readonly;
GRANT USAGE ON SCHEMA public TO taskboard_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO taskboard_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO taskboard_readonly;
```

Usar `taskboard_readonly` en Cursor/túnel. Reservar el usuario `taskboard` para escrituras puntuales de administración.

---

### C. MCP Postgres en Cursor (agente leyendo la BD)

**Cuándo:** Querer que el asistente ejecute **consultas de solo lectura** desde el portátil.

**Servidor:** `@modelcontextprotocol/server-postgres` (solo lectura).

**Requisito:** El portátil debe alcanzar Postgres igual que en A (típicamente **túnel SSH** → `127.0.0.1:5433`).

**Ejemplo `~/.cursor/mcp.json`** (ajustar URI; no commitear contraseñas):

```json
{
  "mcpServers": {
    "taskboard-postgres": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres",
        "postgresql://taskboard_readonly:CLAVE@127.0.0.1:5433/taskboard"
      ]
    }
  }
}
```

**Limitación:** este MCP **no** sustituye al API para CRUD alineado con la app; es inspección/consulta SQL.

---

### D. Postgres en LAN (sin SSH)

**Cuándo:** Solo si no podéis usar SSH y aceptáis más riesgo.

- Publicar `5432` en el mini PC **solo hacia IPs de confianza** (firewall).  
- **Cambiar** `POSTGRES_PASSWORD` a una clave fuerte.  
- Valorar VPN (WireGuard) y mantener Postgres solo en la interfaz VPN.

No recomendado con la contraseña por defecto del ejemplo en toda la LAN.

---

### E. API REST (CRUD coherente con TaskBoard)

**Cuándo:** Crear/editar/borrar proyectos y tareas como hace la aplicación, o invocar IA desde scripts.

**Base URL**

- Directo al contenedor API: `http://<IP_MINIPC>:8101`  
- Vía Caddy (mismo origen que la web): `https://kanban.jualas.es/api-taskboard` o `http://<IP_MINIPC>:8580/api-taskboard`

**Autenticación**

- `POST /auth/login` con JSON `{"email":"...","password":"..."}` → `access_token` (JWT).  
- Cabecera en siguientes peticiones: `Authorization: Bearer <token>`.

**Rutas principales** (prefijos desde `backend/app/routers/`)

| Área | Prefijo |
|------|---------|
| Login / registro / cambio clave | `/auth/...` |
| Proyectos (+ workspace, ide-session, agent-session) | `/api/projects/...` |
| Tareas | `/api/tasks/...` |
| Usuarios | `/api/users/...` |
| Meta (IDs, etc.) | `/api/meta/...` |
| **IA** (suggest, chat, agent-stream SSE) | `/api/ai/...` |

**Documentación interactiva:** `http://<IP_MINIPC>:8101/docs`

**Ejemplo mínimo (portátil)**

```bash
TOKEN=$(curl -sS -X POST "http://<IP_MINIPC>:8101/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"TU_EMAIL","password":"TU_CLAVE"}' | jq -r .access_token)

curl -sS "http://<IP_MINIPC>:8101/api/projects" \
  -H "Authorization: Bearer $TOKEN"
```

Detrás del proxy Caddy, las rutas llevan el prefijo `/api-taskboard` (p. ej. `http://<IP>:8580/api-taskboard/auth/login`).

---

### F. MCP TaskBoard en Cursor (recomendado para agentes)

**Cuándo:** Querer que el agente en Cursor **lea y escriba** tareas/proyectos con las mismas reglas que la app, resuelva el proyecto por carpeta workspace, exporte `TASKBOARD.md` o consulte snapshots.

**Documentación completa:** [`MCP_TASKBOARD.md`](MCP_TASKBOARD.md)

**Instalación rápida en el portátil**

```bash
cd /ruta/al/repo/taskboard
./scripts/install-cursor-mcp-taskboard.sh laptop
# Editar ~/.config/taskboard/mcp.env (email, clave, IP del mini PC)
./scripts/install-cursor-mcp-taskboard.sh laptop
```

Reiniciar Cursor. El servidor aparece como **`taskboard`** en MCP.

**Fuera de la LAN:** túnel SSH al puerto del API:

```bash
ssh -N -L 8101:127.0.0.1:8101 usuario@<IP_MINIPC>
```

En `~/.config/taskboard/mcp.env`:

```env
API_BASE_URL=http://127.0.0.1:8101
API_AUTH_EMAIL=...
API_AUTH_PASSWORD=...
```

**Ventaja frente a MCP Postgres:** CRUD con permisos JWT, estados kanban válidos, workspace e inventario de carpetas.

---

## 4. CORS

En **producción web** (`kanban.jualas.es`), Flutter usa **mismo origen** vía Caddy (`config.json` → `useSameOriginProxy: true`); no hay peticiones cross-origin habituales.

Si llamáis al API desde **otro origen** (otro puerto, extensión, script local), puede hacer falta que `CORS_ORIGINS` en el `.env` del API incluya ese origen.

---

## 5. Checklist de seguridad (mini PC + portátil)

- [ ] Preferir **SSH + localhost** a abrir Postgres a toda la LAN.  
- [ ] Usuario **`taskboard_readonly`** para lecturas SQL habituales.  
- [ ] Contraseñas fuertes; no commitear `mcp.json` ni `mcp.env` con secretos.  
- [ ] Firewall: limitar quién llega al **8101** o **8580** si el mini PC es alcanzable desde redes no confiables.  
- [ ] Para el agente: CRUD sensible vía **API** o **MCP TaskBoard**, no SQL arbitrario de escritura.

---

## 6. Tareas sugeridas para el agente en el portátil (orden lógico)

1. Confirmar **IP del mini PC** y acceso a `:8101` o `:8580`.  
2. Probar **login** con `curl` y listar proyectos vía API.  
3. Instalar **MCP TaskBoard** (`install-cursor-mcp-taskboard.sh laptop`) y probar `list_projects`.  
4. (Opcional) Configurar **túnel SSH** y conexión **psql** o MCP Postgres a `127.0.0.1:5433`.  
5. (Opcional) Crear **`taskboard_readonly`** en el servidor y reconectar MCP Postgres.  
6. Abrir en Cursor la **misma carpeta workspace** vinculada en TaskBoard y usar `resolve_project_by_path`.

---

## 7. Referencias en el repo

| Recurso | Ruta |
|---------|------|
| Esquema SQL | `backend/migrations/001_fresh_install.sql` |
| API / despliegue | `backend/README.md` |
| Asistente IA | `docs/IA_ASISTENTE.md` |
| MCP TaskBoard | `docs/MCP_TASKBOARD.md` |
| Instrucciones despliegue | `INSTRUCCIONES_AGENTE.md` |
| MCP Postgres (oficial) | npm `@modelcontextprotocol/server-postgres` |

---

*Documento para uso interno del equipo TaskBoard. Actualizar IPs, puertos y rutas de proxy si el despliegue difiere.*
