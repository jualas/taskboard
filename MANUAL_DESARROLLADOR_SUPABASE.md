# MANUAL DESARROLLADOR - GESTION DE USUARIOS SUPABASE

Guia operativa para administradores/desarrolladores de `taskboard` en entorno Supabase autohospedado.

## 1) Alcance

- Alta de usuarios.
- Reseteo de contrasena.
- Confirmacion de email.
- Bloqueo/desbloqueo de acceso.
- Verificaciones de diagnostico.

## 2) Requisitos previos

- Acceso shell al servidor donde corre el stack de Supabase.
- Ruta del stack: `/mnt/datos/docker/supabase`
- API local publicada por Kong: `http://127.0.0.1:8008`
- Contenedor de BD: `supabase-db`
- Variable sensible necesaria: `SERVICE_ROLE_KEY` (en `.env` del stack)

## 3) Cargar entorno de forma segura

Ejecutar antes de comandos `curl` de administracion:

```bash
set -a
source /mnt/datos/docker/supabase/.env
set +a
```

Comprobacion minima:

```bash
echo "${SERVICE_ROLE_KEY:0:16}..."
```

## 4) Listar y localizar usuarios

### Buscar por email exacto

```bash
docker exec supabase-db psql -U postgres -d postgres -c \
"select id,email,email_confirmed_at,created_at,last_sign_in_at,banned_until from auth.users where email='USUARIO@DOMINIO.COM';"
```

### Listar ultimos usuarios creados

```bash
docker exec supabase-db psql -U postgres -d postgres -c \
"select id,email,created_at from auth.users order by created_at desc limit 20;"
```

## 5) Crear usuario (alta administrativa)

Usar API Admin de GoTrue:

```bash
source /mnt/datos/docker/supabase/.env && curl -sS -X POST "http://127.0.0.1:8008/auth/v1/admin/users" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{"email":"USUARIO@DOMINIO.COM","password":"ClaveTemporalSegura123!","email_confirm":true,"user_metadata":{"display_name":"Nombre Apellido"}}'
```

Notas:

- `email_confirm: true` evita bloqueo por falta de verificacion.
- Si el usuario ya existe, la API devolvera error de conflicto.

## 6) Resetear contrasena de usuario existente

### Paso 1: obtener UUID del usuario

```bash
docker exec supabase-db psql -U postgres -d postgres -c \
"select id,email from auth.users where email='USUARIO@DOMINIO.COM';"
```

### Paso 2: actualizar password via Admin API

```bash
source /mnt/datos/docker/supabase/.env && curl -sS -X PUT "http://127.0.0.1:8008/auth/v1/admin/users/UUID_AQUI" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{"password":"NUEVA_CLAVE_SEGURA","email_confirm":true}'
```

Notas:
- Sustituir `UUID_AQUI` por el ID real del usuario.
- Sustituir `NUEVA_CLAVE_SEGURA` por la nueva contrasena.
- Este formato evita el error `No API key found in request` al cargar `.env` en la misma ejecucion.

## 7) Confirmar email de usuario (si no puede iniciar sesion)

Si un usuario no confirmado no puede entrar, forzar confirmacion:

```bash
source /mnt/datos/docker/supabase/.env && curl -sS -X PUT "http://127.0.0.1:8008/auth/v1/admin/users/UUID_AQUI" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{"email_confirm":true}'
```

## 8) Bloquear o desbloquear usuario

### Bloquear hasta fecha futura

```bash
source /mnt/datos/docker/supabase/.env && curl -sS -X PUT "http://127.0.0.1:8008/auth/v1/admin/users/UUID_AQUI" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{"ban_duration":"876000h"}'
```

### Desbloquear

```bash
source /mnt/datos/docker/supabase/.env && curl -sS -X PUT "http://127.0.0.1:8008/auth/v1/admin/users/UUID_AQUI" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{"ban_duration":"none"}'
```

## 9) Eliminar usuario (solo si es imprescindible)

Operacion destructiva:

```bash
source /mnt/datos/docker/supabase/.env && curl -sS -X DELETE "http://127.0.0.1:8008/auth/v1/admin/users/UUID_AQUI" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY"
```

## 10) Diagnostico rapido cuando falla Studio

### Verificar contenedores base de auth

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}' | rg 'supabase-(auth|kong|db|studio)'
```

### Comprobar que Kong responde

```bash
curl -i http://127.0.0.1:8008/auth/v1/health
```

### Ver logs de autenticacion

```bash
docker logs --tail 200 supabase-auth
docker logs --tail 200 supabase-kong
```

Si en los logs de Kong aparece **error parsing declarative config** en `kong.yml`, la API entera queda caída (login, REST, funciones). En plugins **cors**, el origen comodín debe ser **`'*'`** (comillas simples en YAML), no `-"*"` con comillas dobles, para que el parseo no falle.

**CORS y acceso por IP LAN (`http://192.168.x.x:8580`):** si en `kong.yml` la lista `origins` mezcla URLs concretas (p. ej. `https://kanban.jualas.es`) con `'*'`, Kong puede **omitir** `Access-Control-Allow-Origin` en el preflight para orígenes que no coincidan exactamente. El navegador muestra `ClientException: Failed to fetch` en `/rest/v1/projects` aunque los datos **sigan en Postgres**. Solución aplicada en el repo: **`origins` únicamente `'*'`** (con `credentials: false`). Tras editar: `docker restart supabase-kong`.

### TaskBoard: error al crear proyecto (RLS `42501` / PostgREST `403`)

Mensaje tipico: `new row violates row-level security policy for table "projects"`.

Causas corregidas en el repo TaskBoard:

1. **`owner_id` nulo** en el INSERT: la politica exige `owner_id = auth.uid()`. Solucion: trigger `trg_projects_before_insert_set_owner` (migracion `20260321100000_projects_rls_insert_fix.sql`) y cliente Flutter que normaliza `owner_id`.
2. **ID de proyecto duplicado**: `getNextProjectId()` solo ve proyectos visibles por RLS; si en la tabla ya hay otros IDs, puede devolver un `id` ocupado y el `upsert` falla. Solucion: funcion RPC `next_project_id()` (misma migracion) y uso desde `SupabaseDataSource.getNextProjectId()`.
3. **JWT de usuario no enviado** (p. ej. sesion caducada o pantalla abierta sin sesion real): el cliente de Supabase usa la **anon key** como `Authorization` si no hay `access_token`, y entonces `auth.uid()` es null → misma violacion RLS. Solucion en app: `_ensureJwtForRls()` antes de las llamadas REST, `refreshSession()` si el token expiro, y `GoRouter.refreshListenable` ligado a `onAuthStateChange` para redirigir a login al cerrar sesion.
4. **RPC `next_project_id` ejecutable como anon**: si la funcion tuviera `GRANT` a `PUBLIC`, se podria obtener un id sin usuario mientras el INSERT sigue bloqueado. Aplicar tambien `20260321110000_next_project_id_revoke_public.sql`.
5. **Fallback del cliente con RLS (corregido en app)**: si `getNextProjectId()` hacia `max(id)` solo sobre filas visibles, un usuario **sin proyectos propios** obtenia `1` aunque ya existiera el id 1 de otro usuario; el **upsert** pasaba a **UPDATE** de esa fila y fallaba RLS con el mismo mensaje que un INSERT. Solucion: obligar al RPC `next_project_id()` (sin fallback) y usar **INSERT** dedicado al crear (`createProject`), no upsert.

Aplicar migracion en la BD (desde el servidor):

```bash
docker exec -i supabase-db psql -U postgres -d postgres < /ruta/al/repo/taskboard/supabase/migrations/20260321100000_projects_rls_insert_fix.sql
docker exec -i supabase-db psql -U postgres -d postgres < /ruta/al/repo/taskboard/supabase/migrations/20260321110000_next_project_id_revoke_public.sql
docker exec -i supabase-db psql -U postgres -d postgres < /ruta/al/repo/taskboard/supabase/migrations/20260322120000_create_project_rpc.sql
```

La app crea proyectos llamando a la RPC **`create_project`** (insert con `SECURITY DEFINER`); sin esta migracion el cliente fallara al invocarla.

Tras cambios en el cliente, volver a **build web** y publicar (ver `INSTRUCCIONES_AGENTE.md`).

## 11) Buenas practicas de seguridad

- No exponer `SERVICE_ROLE_KEY` en frontend ni repositorio.
- No guardar contrasenas reales en documentos compartidos.
- Usar contrasenas temporales y forzar cambio al primer acceso (procedimiento interno).
- Mantener este manual en entorno privado.

## 12) Checklist operativo recomendado

1. Verificar email/usuario en `auth.users`.
2. Ejecutar accion admin (alta/reset/confirmar).
3. Validar login desde la app.
4. Registrar fecha, usuario afectado y operador en bitacora interna.

## 13) IA para Edge Function `ai-assistant` (DeepSeek u Ollama)

**Visión de producto y contrato JSON:** [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md).

### 13.0) DeepSeek en la nube (prioridad si hay clave)

Si en el `.env` del stack Supabase defines **`DEEPSEEK_API_KEY`**, la funcion `ai-assistant` llama a **`https://api.deepseek.com/v1/chat/completions`** con modelo **`DEEPSEEK_MODEL`** (por defecto `deepseek-chat`). Asi **no** se usa la CPU local para inferencia.

Variables en `docker-compose.yml` (servicio `functions`): `DEEPSEEK_API_KEY`, `DEEPSEEK_MODEL`, `DEEPSEEK_BASE_URL`.

Tras editar `.env`: recrea o reinicia **`supabase-edge-functions`**.

Para volver al modelo local: **quita** `DEEPSEEK_API_KEY` del `.env` (o dejala vacia) y reinicia el contenedor.

### 13.1) IA local (Ollama + Qwen) — sin DeepSeek

Configuracion aplicada en el mini PC para usar un modelo local sin salir a terceros **cuando no hay `DEEPSEEK_API_KEY`**.

#### Servicio persistente Ollama (usuario `jualas`)

- Binario local: `/home/jualas/.local/bin/ollama`
- Unidad systemd usuario: `/home/jualas/.config/systemd/user/ollama.service`
- Modelo recomendado (rendimiento CPU): `qwen2.5:3b-instruct-q4_K_M` (más rápido que `q6_K` con calidad similar para tareas)
- Opcional más pesado: `qwen2.5:3b-instruct-q6_K`
- API local: `http://127.0.0.1:11434`

Comandos de control:

```bash
systemctl --user daemon-reload
systemctl --user status ollama.service --no-pager
systemctl --user restart ollama.service
ollama list
```

El servicio fija `OLLAMA_NUM_THREAD=4` (ajustar en `~/.config/systemd/user/ollama.service` si cambia el hardware).

Persistencia tras reboot:

- `linger` del usuario activado (`loginctl show-user jualas` -> `Linger=yes`).
- Esto permite que `systemd --user` inicie `ollama.service` aunque no haya sesion interactiva abierta.

### Conectividad desde Supabase Edge Functions

Se habilito `host.docker.internal` en el servicio `functions` del stack Supabase:

- Archivo: `/mnt/datos/docker/supabase/docker-compose.yml`
- Bloque anadido:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

Endpoint a usar desde la funcion backend:

- `http://host.docker.internal:11434/v1/chat/completions` (OpenAI-compatible)
- Alternativa equivalente por gateway de red Docker: `http://192.168.96.1:11434`

Prueba rapida desde host:

```bash
curl -sS http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen2.5:3b-instruct-q4_K_M","messages":[{"role":"user","content":"Responde solo con OK"}],"temperature":0}'
```

---

Manual orientado a operacion tecnica.  
Para uso funcional de la aplicacion, ver `MANUAL_USUARIO.md`.