# Claude Code desde TaskBoard (modo Agent del panel IA)

El panel IA de un proyecto (pestaña **Claude Code**) lanza Claude Code (`claude -p`) en el contenedor `taskboard-api`, sobre la carpeta workspace vinculada al proyecto. Sirve para cualquier repo vinculado, no solo para TaskBoard. Sustituye al CLI de Cursor Agent.

## Modos

| Modo | Casilla «Modo desarrollo» | Qué puede hacer |
|---|---|---|
| Seguimiento | desactivada | Leer el repo (solo dentro del workspace), `git status/log/diff/show/branch`, y crear o actualizar tareas del proyecto con el MCP de TaskBoard. |
| Desarrollo | activada | Lo anterior y además editar ficheros del workspace, `git add/commit/switch/checkout -b/restore/stash`, tests y linters (`pytest`, `ruff`, `npm test`, `flutter test`, …). |

Siempre prohibido: `git push`, `git reset --hard`, `git clean`, `git config`, `curl`, `wget`, WebFetch, WebSearch, borrar tareas, crear o modificar proyectos. Cualquier otra herramienta o comando se deniega sin preguntar (`--permission-mode dontAsk` con lista cerrada en `backend/app/claude_code.py`).

Cada ejecución queda en el historial del panel; las herramientas usadas se registran en el log del API (`agent-stream tool`), sin su resultado. La sesión se reanuda por proyecto («continuar sesión»).

## Seguridad

- Solo usuarios de `WORKSPACE_ADMIN_EMAILS`.
- El MCP de TaskBoard usa un JWT del propio usuario que caduca en `CLAUDE_CODE_TOKEN_MINUTES` (60 por defecto): el agente solo ve los proyectos que ve esa persona. La configuración MCP va en un fichero temporal 0600 que se borra al terminar.
- El proceso recibe un entorno mínimo (PATH, HOME, token de Claude Code, identidad git): no hereda `JWT_SECRET`, `DATABASE_URL` ni `DEEPSEEK_API_KEY`.
- Tope por ejecución: `CLAUDE_CODE_MAX_TURNS` pasos, `CLAUDE_CODE_MAX_BUDGET_USD` dólares y `CLAUDE_CODE_TIMEOUT_SEC` segundos; si el cliente corta el stream, el proceso se mata.
- En modo desarrollo, ejecutar los tests del repo es ejecutar su código dentro del contenedor (con el token de Claude Code en su entorno y acceso a los montajes del API). Usa ese modo solo en repos propios.
- El contenido del repo llega a Anthropic. No vincules como workspace carpetas con datos personales (por ejemplo, expedientes de empleo).
- Los commits llevan la identidad `CLAUDE_CODE_GIT_NAME` / `CLAUDE_CODE_GIT_EMAIL`; el push lo hace una persona tras revisar.

## Despliegue (mini PC)

1. Token: `claude setup-token` en el host y `CLAUDE_CODE_OAUTH_TOKEN=…` en `/mnt/datos/docker/taskboard-api/.env`, junto a `CLAUDE_CODE_ENABLED=true` y `CLAUDE_CODE_HOME=/home/agente`.
2. En el `docker-compose.yml` del API, en lugar de los montajes de Cursor:

   ```yaml
   volumes:
     # Binario de Claude Code (se resuelve el enlace al crear el contenedor: recrear tras actualizar claude)
     - /home/jualas/.local/bin/claude:/usr/local/bin/claude:ro
     # HOME propio del agente (sesiones para --resume), sin la configuración del usuario
     - /home/jualas/.local/share/agentes-ia/home-taskboard:/home/agente
     # Servidor MCP de TaskBoard (solo lectura)
     - /mnt/datos/Proyectos/taskboard/mcp-taskboard:/opt/mcp-taskboard:ro
   ```

3. `docker compose up -d --build taskboard-api` y vaciar las sesiones guardadas de Cursor, que no sirven para Claude Code: `delete from project_agent_sessions;`.
4. Prueba: en un proyecto con workspace, pestaña Claude Code, «¿Qué tareas del tablero no cuadran con el último git log?».
