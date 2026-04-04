# MCP para Supabase (BD + Config local)

Este proyecto incluye configuración MCP para:

- **Consultar/operar la base de datos de Supabase** usando el **MCP oficial** (modo *read-only* y modo *read-write*).
- **Leer la configuración local** del proyecto Supabase en Docker (migraciones, funciones, SQL de `dev/`, etc.) usando un MCP de **filesystem**.

## 1) Archivos a usar

- Config MCP del proyecto: `taskboard/.cursor/mcp.json`
- Guía (este documento): `taskboard/MCP_SUPABASE.md`

Cursor carga `mcp.json` desde el directorio `.cursor/` del proyecto (y lo mezcla con `~/.cursor/mcp.json` si existe).

Nota: en tu máquina ya existe `~/.cursor/mcp.json` con un servidor `supabase` apuntando a `https://api-supabase.jualas.es/mcp?features=database`. Para evitar duplicados, en Cursor conecta usando ese servidor `supabase` y deja deshabilitados los demás (`supabase-remote-ro/rw`, etc.) salvo cuando los necesites.

## 2) Endpoints configurados

En `taskboard/.cursor/mcp.json` hay:

- `supabase-remote-ro`: `https://api-supabase.jualas.es/mcp?read_only=true`
- `supabase-remote-rw`: `https://api-supabase.jualas.es/mcp?read_only=false`
- `supabase-local-mcp`: `http://localhost:8008/mcp?read_only=true` (requiere habilitar acceso local en Kong)
- `supabase-local-mcp-rw`: `http://localhost:8008/mcp?read_only=false` (requiere habilitar acceso local en Kong)

Además:

- `supabase-local-files`: lectura de `/mnt/datos/docker/supabase/dev` y `/mnt/datos/docker/supabase/volumes` (sin exponer `.env`)

## 3) Login/Autorización

Al reiniciar Cursor, el MCP de Supabase debería pedir autorización (login web) para tu organización/proyecto.

Si prefieres limitar más herramientas, ajusta el parámetro `features=...` en las URLs.

## 4) Acceso a la configuración local (Docker)

El servidor `supabase-local-files` expone únicamente estos paths (intencionalmente **sin** incluir el `.env` de la raíz):

- `/mnt/datos/docker/supabase/dev`
- `/mnt/datos/docker/supabase/volumes`

Con eso normalmente puedes revisar:

- migraciones y SQL
- Edge Functions en el árbol de `volumes/`
- configuración generada por el entorno local

Si necesitas también `docker-compose.yml` / archivos de la raíz, dímelo y te propongo una variante que minimice el riesgo de exponer secretos.

## 5) MCP contra BD local Docker (migraciones/SQL)

Para ejecutar SQL/migraciones contra tu **Supabase local** desde Cursor:

- Usa `supabase-local-mcp` para modo read-only.
- Usa `supabase-local-mcp-rw` para migraciones/DDL (read_only=false).

Importante: en el `kong.yml` del stack local, el endpoint `/mcp` viene **bloqueado por defecto** por un plugin `request-termination`. Para habilitar acceso local:

1. Opción rápida: ejecuta el script:
   - `taskboard/scripts/enable-supabase-local-mcp.sh`
2. Alternativa manual: Edita `/mnt/datos/docker/supabase/volumes/api/kong.yml`
2. Busca la sección:
   - comentario `MCP endpoint - local access`
3. Comenta la regla `request-termination` que devuelve `403` para `/mcp`
4. (Opcional pero recomendado) habilita `ip-restriction` y deja `127.0.0.1` / `::1` permitidos
5. Reinicia Kong desde:
   - `/mnt/datos/docker/supabase`
   - comando: `docker compose restart kong`

El endpoint resultante (host en la máquina donde corre Cursor) queda en:

- `http://localhost:8008/mcp`

`8008` corresponde a `KONG_HTTP_PORT=8008` en `/mnt/datos/docker/supabase/.env`.

## 6) Seguridad recomendada

- Usa primero `supabase-remote-ro` y `supabase-local-mcp` en modo read-only.
- Mantén activada la aprobación de ejecución en Cursor para llamadas a herramientas.
- Evita usar `supabase-remote-rw` contra datos sensibles.

