# MANUAL DE USUARIO - TASKBOARD

Guía rápida para usar la aplicación web TaskBoard.

## 1) Acceso a la aplicación

- **URL pública:** [https://kanban.jualas.es](https://kanban.jualas.es)
- **Red local (mini PC):** `http://<IP-LAN-SERVIDOR>:8580` (ajusta la IP si tu servidor es distinto)
- Si hay problemas de carga:
  - recarga con `Ctrl + Shift + R`
  - en caso extremo, abre en ventana privada/incógnito

## 2) Inicio de sesión

- Entrar con email y contraseña en la pantalla de login.
- Botón: **Entrar**.
- Si aparece error de autenticación:
  - revisa email/contraseña
  - confirma que la cuenta existe en TaskBoard (API + Postgres del servidor)

## 3) Pantalla principal: Mis Proyectos

Tras iniciar sesión se abre **Mis Proyectos**, donde puedes:

- Ver la lista de proyectos existentes.
- Refrescar datos con el icono de actualizar.
- Abrir el **Inventario workspace** (carpetas del servidor vinculables a proyectos).
- Cerrar sesión con el icono de salida.
- Crear un proyecto nuevo (**Nuevo Proyecto**).

## 4) Crear proyecto

1. Pulsa **Nuevo Proyecto**.
2. Completa:
   - **Título** (obligatorio)
   - **Descripción** (opcional)
3. Pulsa **Crear**.

Opcionalmente, después puedes **Editar** el proyecto para vincular una **carpeta workspace** (ruta en el mini PC donde está el código). Eso permite que la IA conozca el estado del repositorio y que Cursor abra el proyecto directamente.

## 5) Gestionar proyecto

En cada tarjeta de proyecto:

- Clic en la tarjeta: abre Kanban del proyecto.
- Menú de acciones:
  - **Ver Kanban**
  - **Ver Lista** (tareas del proyecto)
  - **Editar**
  - **Eliminar**
  - Con workspace vinculado: **Abrir en Cursor**, **Sugerencias workspace**, **Exportar TASKBOARD.md**, **Prompt IDE (Cursor)**

## 6) Kanban y tareas

Desde un proyecto:

- **Vista Kanban:** seguimiento visual por estado.
- **Vista Lista de tareas:** gestión detallada.
- Flujo habitual:
  1. crear tarea
  2. actualizar estado
  3. marcar completada

### 6.1) Sugerir tarea con IA

Al crear una tarea nueva (desde Kanban o vista lista):

1. Pulsa **Sugerir con IA**.
2. Describe **qué necesitas** (objetivo, alcance o criterios). Cuanto más concreto, mejor suele ser el borrador.
3. Espera a que termine la generación (puede tardar **varios segundos o varios minutos** según el motor IA del servidor).
4. Revisa los campos rellenados (título, descripción, complejidad, horas, etiquetas, checklist). **Corrige** lo que no encaje.
5. Pulsa **Crear** cuando esté listo.

La app indica el proveedor usado cuando está disponible (p. ej. *Cursor Agent*, *DeepSeek (nube)*, *Ollama (local)*).

### 6.2) Asistente IA del proyecto

En Kanban o lista de tareas, pulsa el icono **Asistente IA del proyecto** (barra superior):

- **Planificar:** conversación para ampliar o refinar el backlog. Si el proyecto tiene carpeta workspace, la IA puede tener en cuenta el estado del repositorio.
- **Agent (CLI):** ejecuta el agente de Cursor en la carpeta del proyecto (requiere workspace vinculado). Muestra la salida en tiempo real. Opciones:
  - **Continuar sesión** — retoma la conversación anterior con el agente.
  - **Nueva sesión** — empieza de cero.
  - Modo ejecución (editar archivos) solo si lo activas explícitamente en la UI.

Revisa el borrador de tareas propuesto y aplícalo al tablero cuando encaje con tu plan.

**Importante:** la IA solo **propone** contenido; la decisión final y la calidad del backlog siguen siendo tuyas. Si aparece un error de red o timeout, reintenta más tarde o trabaja a mano.

Documentación técnica del asistente: [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md).

## 7) Mensajes de error comunes

- **Credenciales incorrectas** o **Invalid authentication credentials**:
  - email o contraseña no válidos
  - backend de auth no accesible
- **No se pudo llamar a la función IA** / **Failed to fetch**:
  - el servidor IA puede estar ocupado; espera y reintenta
  - comprueba conexión a `kanban.jualas.es`
- **Cursor Agent: sesión no válida** (solo administrador):
  - el CLI `agent` del servidor necesita autenticación
- Errores de carga de recursos:
  - limpiar caché del navegador
  - hacer recarga forzada

## 8) Recomendaciones de uso

- Mantener actualizado el navegador.
- Evitar múltiples pestañas editando el mismo elemento a la vez.
- Cerrar sesión al terminar si el equipo es compartido.
- Vincular la **carpeta workspace** en proyectos de software para sacar partido al asistente y a Cursor.

## 9) Soporte funcional

Si un usuario no puede entrar:

1. Validar que existe en la base de datos de usuarios del API (contactar al administrador).
2. Verificar que la cuenta está activa.
3. Resetear contraseña desde administración si hace falta.

---

Documento orientado a usuario final.  
Para detalles técnicos y operativos, ver [`INSTRUCCIONES_AGENTE.md`](INSTRUCCIONES_AGENTE.md).  
Para arquitectura del asistente IA, ver [`docs/IA_ASISTENTE.md`](docs/IA_ASISTENTE.md).
