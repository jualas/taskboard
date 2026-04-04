# MANUAL DE USUARIO - TASKBOARD

Guia rapida para usar la aplicacion web TaskBoard.

## 1) Acceso a la aplicacion

- URL local actual: `http://localhost:8083`
- `URL red local: http://<IP-LAN-SERVIDOR>:8083`
- `URL Pública: kanban.jualas.es`
- Si hay problemas de carga:
  - recargar con `Ctrl + Shift + R`
  - en caso extremo, abrir en ventana privada/incognito

## 2) Inicio de sesion

- Entrar con email y contrasena en la pantalla de login.
- Boton: `Entrar`.
- Si aparece error de autenticacion:
  - revisar email/contrasena
  - confirmar que la cuenta existe y esta activa en Supabase (`Authentication > Users`)

## 3) Pantalla principal: Mis Proyectos

Tras iniciar sesion se abre `Mis Proyectos`, donde puedes:

- Ver la lista de proyectos existentes.
- Refrescar datos con el icono de actualizar.
- Cerrar sesion con el icono de salida.
- Crear un proyecto nuevo (`Nuevo Proyecto`).

## 4) Crear proyecto

1. Pulsar `Nuevo Proyecto`.
2. Completar:
  - Titulo (obligatorio)
  - Descripcion (opcional)
3. Pulsar `Crear`.

## 5) Gestionar proyecto

En cada tarjeta de proyecto:

- Clic en la tarjeta: abre Kanban del proyecto.
- Menu de acciones:
  - `Ver Kanban`
  - `Ver Lista` (tareas del proyecto)
  - `Editar`
  - `Eliminar`

## 6) Kanban y tareas

Desde un proyecto:

- Vista Kanban: seguimiento visual por estado.
- Vista Lista de tareas: gestion detallada.
- Flujo habitual:
  1. crear tarea
  2. actualizar estado
  3. marcar completada

### 6.1) Sugerir tarea con IA

Al crear una tarea nueva (desde Kanban o vista lista):

1. Pulsa **Sugerir con IA**.
2. Describe en el cuadro de texto **qué necesitas** (objetivo, alcance o criterios). Puedes ser breve; cuanto más concreto, mejor suele ser el borrador.
3. Espera a que termine la generación (en equipos sin GPU puede tardar **varios segundos o más**).
4. Revisa los campos rellenados (título, descripción, complejidad, horas, etiquetas, checklist). **Corrige** lo que no encaje con tu proyecto.
5. Pulsa **Crear** cuando esté listo.

**Importante:** la IA solo **propone** contenido; la decisión final y la calidad del backlog siguen siendo tuyas. Si aparece un error de red o timeout, reintenta más tarde o crea la tarea a mano.

Documentación técnica del asistente: `docs/IA_ASISTENTE.md`.

## 7) Mensajes de error comunes

- `Credenciales incorrectas` o `Invalid authentication credentials`:
  - email o contrasena no validos
  - backend de auth no accesible
- Errores de carga de recursos:
  - limpiar cache del navegador
  - hacer recarga forzada

## 8) Recomendaciones de uso

- Mantener actualizado el navegador.
- Evitar multiples pestañas editando el mismo elemento a la vez.
- Cerrar sesion al terminar si el equipo es compartido.

## 9) Soporte funcional

Si un usuario no puede entrar:

1. validar que existe en `Authentication > Users`
2. verificar estado de cuenta y confirmacion
3. resetear contrasena desde administracion si hace falta

---

Documento orientado a usuario final.  
Para detalles tecnicos y operativos, ver `INSTRUCCIONES_AGENTE.md`.  
Para arquitectura del asistente IA, ver `docs/IA_ASISTENTE.md`.