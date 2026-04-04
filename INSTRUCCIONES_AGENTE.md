# INSTRUCCIONES AGENTE

Documento técnico de continuidad para agentes (estado operativo real y procedimientos).

## 1) Contexto del proyecto
- Proyecto: `taskboard` (repositorio de trabajo independiente en esta carpeta).
- Frontend: Flutter Web (`frontend/`).
- Backend datos/auth: API propia **FastAPI + Postgres** (`backend/`) o, en transición, Supabase autohospedado. Prioridad en `frontend/lib/main.dart`: TaskBoard API si está configurada, si no Supabase, si no almacenamiento local.
- Objetivo: mantener login y despliegue web estables tanto en LAN como por túnel Cloudflare.

## 2) Ubicaciones y despliegue actual
- Raíz del proyecto: `.../Proyectos/taskboard`.
- Frontend fuente: `frontend/`.
- Build generado: `frontend/build/web`.
- Publicación web activa: `/mnt/datos/docker/taskboard-web/public`.
- Stack web activo: `/mnt/datos/docker/taskboard-web/docker-compose.yml`.
- Contenedores activos de publicación:
  - `taskboard-web` (Caddy, puerto `8580`) — proxy **`/api-taskboard/*`** → `host.docker.internal:8000` (API FastAPI en el anfitrión; requiere `extra_hosts` en el compose).
  - `kanban-cloudflared` (túnel para `kanban.jualas.es`).
- **API + Postgres (producción):** `/mnt/datos/docker/taskboard-api/docker-compose.yml` — datos en `/mnt/datos/docker/volumes/taskboard-api-postgres/`.
- Stack Docker **en el repo** (Postgres + API + Nginx estáticos, dev): `frontend/docker/docker-compose.yml` — datos en `/mnt/datos/docker/volumes/taskboard-frontend-stack-postgres/`.
- Servicio retirado por duplicidad: `tfg-frontend-web` (Nginx, 8083).

## 3) Estado operativo validado
- Acceso LAN: `http://<IP_SERVIDOR>:8580` (OK).
- Acceso externo: `https://kanban.jualas.es` (OK).
- Login validado tras restauración de credenciales en Supabase.

## 4) Autenticación y configuración
- Configuración empaquetada en frontend:
  - `frontend/assets/data/config.json` — `taskboardApi` (API propia, `useSameOriginProxy` + `proxyPrefix` `/api-taskboard`) y/o `supabase`.
  - `frontend/.env` (apoyo de desarrollo)
- Flujo de inicialización (`frontend/lib/main.dart`, `_initBootstrap`):
  1. `--dart-define` `TASKBOARD_API_URL` / `TASKBOARD_API_SAME_ORIGIN_PROXY`
  2. `taskboardApi` en `config.json` (en web, `baseUrl` vacío + `useSameOriginProxy` usa el origen actual + prefijo)
  3. `--dart-define` `SUPABASE_URL` / `SUPABASE_ANON_KEY` o `supabase` en `config.json`
  4. fallback local (`SharedPreferences`)
- Producción estática: tras cada build, copiar también `public/assets/assets/data/config.json` si se cambia la config embebida.
- `AuthService.login()` (Supabase): acepta sesión válida aunque `user` llegue nulo en la respuesta del SDK. Login API propia: `ApiAuthService`.

## 4.1) API TaskBoard (FastAPI) en producción (`taskboard-web` + Caddy)
- Stack Docker: **`/mnt/datos/docker/taskboard-api/`** (`docker compose up -d --build`). Publica **`127.0.0.1:8000`**. Secretos en `/mnt/datos/docker/taskboard-api/.env` (plantilla `env.example`); código fuente del build: repo `taskboard/backend/` (variable opcional `TASKBOARD_BACKEND_SRC` en `.env` si el repo se mueve).
- Datos Postgres persistentes: **`/mnt/datos/docker/volumes/taskboard-api-postgres/`** (bind mount; backup de esta carpeta para DR).
- Migraciones: `.../taskboard/backend/migrations/001_fresh_install.sql` o `002_from_supabase.sql` según origen (ejecutar vía `docker compose exec -T postgres psql ...`, ver `taskboard-api/README.md`).
- Alternativa sin Docker: `uvicorn` con venv en `backend/`.
- Caddy (`/mnt/datos/docker/taskboard-web/Caddyfile`) enruta `/api-taskboard/` al API; el contenedor `taskboard-web` tiene `extra_hosts: host.docker.internal:host-gateway`.
- `config.json` debe incluir `taskboardApi.useSameOriginProxy: true` para que el cliente web use `https://kanban.jualas.es/api-taskboard/...` sin CORS.

## 5) Supabase (referencia)
- URL API: `https://api-supabase.jualas.es`.
- Stack Docker: `/mnt/datos/docker/supabase`.
- Secretos reales: `/mnt/datos/docker/supabase/.env` (no exponer en docs públicas).

## 5.1) Asistente IA (tareas, modelo local)
- Funcionalidad en app: formulario **Nueva tarea** → **Sugerir con IA** (`frontend/lib/screens/forms/task_form.dart`).
- Cliente: `frontend/lib/services/ai_assistant_service.dart` → `functions.invoke('ai-assistant')`.
- Backend: Edge Function `ai-assistant` en `/mnt/datos/docker/supabase/volumes/functions/ai-assistant/`; modelo vía **Ollama** en el host (`LOCAL_LLM_MODEL`, por defecto `qwen2.5:3b-instruct-q4_K_M`).
- Documentación de producto y arquitectura: **`docs/IA_ASISTENTE.md`**.
- Operación (servicio Ollama, Docker, Kong): **`MANUAL_DESARROLLADOR_SUPABASE.md`** sección 13.

## 6) Procedimiento build + publicación (obligatorio)
Ejecutar desde `frontend/`:

1. Build:
   - `docker run --rm -v "$PWD":/app -v "$PWD/.pub-cache-docker":/root/.pub-cache -w /app ghcr.io/cirruslabs/flutter:3.32.0 bash -lc "flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs && flutter build web --release"`
2. **Cache-bust del túnel (obligatorio si `kanban.jualas.es` no refleja lo mismo que `:8580`):**
   - Desde la raíz del repo `taskboard/`: `bash scripts/patch-web-index-cache-bust.sh frontend/build/web`
   - Añade `?v=<timestamp>` a **`flutter_bootstrap.js`** en `index.html` y a **`main.dart.js`** dentro de `flutter_bootstrap.js` (si no, el dominio puede seguir sirviendo un `main.dart.js` vieño desde caché del navegador).
   - Genera `deploy-stamp.txt` en el build: comprueba en `https://kanban.jualas.es/deploy-stamp.txt` que coincide con el de `http://IP:8580/deploy-stamp.txt`.
3. Publicar en ruta activa:
   - `tar -C "$PWD/build/web" -cf - . | tar --overwrite --no-same-owner -C /mnt/datos/docker/taskboard-web/public -xf -`
4. Reiniciar servicios web + túnel:
   - `docker compose --project-directory /mnt/datos/docker/taskboard-web -f /mnt/datos/docker/taskboard-web/docker-compose.yml up -d taskboard-web kanban-cloudflared`

## 7) Incidencias conocidas (y solución)
- Síntoma: login correcto en LAN pero error por túnel.
  - Causa: caché de Cloudflare sirviendo `main.dart.js` antiguo.
  - Solución aplicada: `scripts/patch-web-index-cache-bust.sh`, cabeceras `no-store` en Caddy (`taskboard-web/Caddyfile`) y comprobar en Cloudflare DNS que `kanban.jualas.es` apunte al **túnel** (no a un registro A/AAAA proxy antiguo a otro servidor).
- Síntoma: `Service Worker API unavailable / context NOT secure`.
  - Causa: acceso HTTP no seguro con intento de SW.
  - Solución: acceso recomendado por HTTPS en túnel y desactivación de SW en bootstrap de despliegue cuando sea necesario.

## 8) Trabajo por Samba y Git
- Esta carpeta se comparte por Samba; propietario Linux puede no coincidir (p. ej. `nobody:nogroup`).
- Es normal ver avisos de Git por “dubious ownership”.
- Recomendación por equipo (una vez):
  - `git config --global --add safe.directory "/mnt/datos/nextcloud/nextcloud-service/nextcloud-data/data/jualas/files/Proyectos/taskboard"`
- Si se trabaja desde Windows sobre share SMB, unificar EOL con `.gitattributes` para evitar diffs por CRLF/LF.

## 9) Seguridad
- No almacenar `service_role` en frontend.
- No publicar tokens o claves en documentación de usuario.
- Cambios de password de usuarios: panel Supabase o API Admin.

---
Para uso funcional de la aplicación, consultar `MANUAL_USUARIO.md`.
Para operación técnica de usuarios Supabase, consultar `MANUAL_DESARROLLADOR_SUPABASE.md`.
Para el asistente IA (arquitectura y contratos), consultar `docs/IA_ASISTENTE.md`.
