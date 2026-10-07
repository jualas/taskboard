# 👨‍💼 Guía de Uso - Administrador

**Sistema de Seguimiento de Proyectos TFCGS**  
**Versión:** 1.0  
**Fecha:** Noviembre 2025

---

## 🎯 Tu Rol como Administrador

Como **administrador**, tienes el control completo del sistema y eres responsable de:
- **Gestionar usuarios** (CRUD completo: crear, leer, actualizar, eliminar)
- **Supervisar el funcionamiento** general del sistema
- **Configurar parámetros** globales
- **Resolver problemas** técnicos y administrativos
- **Mantener la integridad** de los datos
- **Generar reportes** y estadísticas
- **Administrar permisos** y roles

---

## 📋 Lógica de Negocio: Flujo de Trabajo del Administrador

### **Fase 1: Gestión de Usuarios** 👥

```
1. Inicio de ciclo académico
   ↓
2. Importar/Crear usuarios masivamente
   ↓
3. Asignar roles (estudiante, tutor, admin)
   ↓
4. Vincular estudiantes con tutores
   ↓
5. Activar cuentas y enviar credenciales
   ↓
6. Monitorear actividad de usuarios
```

**Tipos de usuarios que gestionas:**
- 🔵 **Estudiantes**: Usuarios que desarrollan proyectos
- 🟢 **Tutores**: Supervisores de proyectos
- 🔴 **Administradores**: Gestores del sistema

---

### **Fase 2: Supervisión del Sistema** 📊

```
1. Monitoreo diario
   ↓
2. Verificar métricas clave
   ↓
3. Identificar problemas o cuellos de botella
   ↓
4. Intervenir cuando sea necesario
   ↓
5. Generar reportes periódicos
```

**Métricas clave a monitorear:**
- 📈 Número de usuarios activos
- 📝 Anteproyectos en cada estado
- ✅ Proyectos activos
- 📊 Tareas completadas vs pendientes
- ⚠️ Alertas y problemas técnicos

---

### **Fase 3: Configuración del Sistema** ⚙️

```
1. Definir parámetros globales
   ↓
2. Configurar notificaciones
   ↓
3. Establecer políticas de acceso
   ↓
4. Personalizar flujos de trabajo
   ↓
5. Mantener actualizada la configuración
```

---

### **Fase 4: Soporte y Resolución de Problemas** 🔧

```
1. Recibir reporte de problema
   ↓
2. Diagnosticar causa raíz
   ↓
3. Aplicar solución
   ↓
4. Verificar resolución
   ↓
5. Documentar para prevenir recurrencia
```

---

## 🗺️ Navegación: Menú Principal

### **🏠 Dashboard (Panel Principal)**
Tu centro de control administrativo.

**Vista general incluye:**
- 📊 **Estadísticas del sistema**
  - Total de usuarios (por rol)
  - Proyectos activos
  - Anteproyectos pendientes
  - Tareas en el sistema
  
- 📈 **Métricas de actividad**
  - Usuarios activos hoy/esta semana
  - Tasa de aprobación de anteproyectos
  - Promedio de tiempo de revisión
  - Porcentaje de tareas completadas
  
- 🔔 **Alertas del sistema**
  - Problemas técnicos
  - Usuarios bloqueados
  - Errores de sincronización
  - Capacidad del sistema

**¿Cuándo usarlo?**  
Al inicio de cada sesión para tener el pulso del sistema.

---

### **👥 Gestión de Usuarios**
El corazón de tus funciones administrativas.

#### **Visualización de Usuarios**

**Vista de lista:**
- Todos los usuarios del sistema
- Filtros por rol, estado, fecha de creación
- Búsqueda por nombre, email, NRE
- Ordenamiento por múltiples campos

**Información visible:**
- Email y nombre completo
- Rol asignado
- Estado (activo, inactivo, bloqueado)
- Fecha de registro
- Última actividad
- Proyectos asociados (para estudiantes)
- Estudiantes supervisados (para tutores)

---

#### **Crear Usuario**

**Proceso de creación:**
1. Clic en "Crear Usuario"
2. Seleccionar tipo de usuario (Estudiante/Tutor/Admin)
3. Completar formulario:
   - **Email**: Debe pertenecer al dominio institucional configurado (ej: @jualas.es)
   - **Contraseña inicial**: Generada o personalizada
   - **Nombre completo**: Obligatorio
   - **Rol**: Selección automática según tipo
   - **Campos específicos por rol**:
     - *Estudiante*: NRE, especialidad, año académico, tutor asignado
     - *Tutor*: Departamento, especialización
     - *Admin*: Permisos especiales

4. Enviar credenciales por email (opcional)
5. Confirmar creación

**⚠️ Limitación de dominio:**
- El sistema está configurado para aceptar únicamente emails del dominio institucional
- Los usuarios no pueden registrarse con emails de otros dominios
- Esta limitación se aplica tanto en el registro manual como en la importación masiva
- Si necesitas añadir un nuevo dominio permitido, debe implementarse en el backend Taskboard (validación en registro / política de despliegue)

**Mejores prácticas:**
- ✅ Verifica que el email sea institucional
- ✅ Usa convenciones de nomenclatura consistentes
- ✅ Asigna tutor en el momento de crear estudiante
- ✅ Envía email de bienvenida con instrucciones
- ✅ Documenta la creación (motivo, autorización)

---

#### **Editar Usuario**

**¿Qué puedes editar?**
- Información personal (nombre, email)
- Estado de la cuenta (activo/inactivo)
- Rol (con precaución)
- Contraseña (reset)
- Asignaciones (tutor para estudiantes)
- Permisos específicos

**Acciones disponibles:**
- ✏️ **Editar información**
- 🔒 **Resetear contraseña**
- 🚫 **Desactivar cuenta**
- 🗑️ **Eliminar usuario** (con confirmación)
- 📧 **Reenviar email de verificación**
- 🔄 **Cambiar rol** (requiere confirmación)

**⚠️ Precauciones al editar:**
- Cambiar el email puede afectar el acceso del usuario
- Cambiar de rol altera permisos completamente
- Eliminar usuario es irreversible (considera desactivar en su lugar)
- Resetear contraseña desconecta al usuario inmediatamente

---

#### **Importación Masiva de Usuarios**

**Formato CSV requerido:**

Para estudiantes:
```csv
email,full_name,nre,specialty,academic_year,tutor_email
juan.perez@jualas.es,Juan Pérez García,12345678A,DAM,2024-2025,tutor.garcia@jualas.es
```

Para tutores:
```csv
email,full_name,department,specialization
tutor.lopez@jualas.es,María López Sánchez,Informática,Desarrollo Web
```

**Proceso:**
1. Preparar archivo CSV con el formato correcto
2. Ir a "Gestión de Usuarios" → "Importar CSV"
3. Seleccionar tipo de usuario (Estudiante/Tutor)
4. Subir archivo
5. Validación automática del formato
6. Revisar preview de datos a importar
7. Confirmar importación
8. Sistema procesa y muestra resultado:
   - ✅ Usuarios creados exitosamente
   - ⚠️ Usuarios con advertencias
   - ❌ Usuarios que fallaron (con motivo)

**Validaciones automáticas:**
- Formato de email válido
- Email pertenece al dominio institucional configurado
- Email único (no duplicado)
- Campos obligatorios completos
- Formato de NRE correcto
- Tutor asignado existe en el sistema

**⚠️ Nota sobre dominio:**
- Todos los emails en el CSV deben pertenecer al dominio institucional permitido
- Los emails de otros dominios serán rechazados durante la importación
- Verifica que todos los emails en tu CSV cumplan con esta restricción antes de importar

---

### **⚖️ Flujo de Aprobación (Admin)**
Vista global de todas las aprobaciones en el sistema.

**Diferencia con el flujo de tutor:**
Como admin, ves **TODOS** los anteproyectos y tareas, no solo los de estudiantes asignados.

**¿Cuándo intervenir?**
- Anteproyecto lleva mucho tiempo sin revisar
- Disputa entre tutor y estudiante
- Solicitudes especiales o excepciones
- Verificación de calidad del proceso

**Acciones disponibles:**
- Ver detalles completos
- Asignar/Reasignar a otro tutor
- Aprobar forzosamente (en casos excepcionales)
- Rechazar con justificación
- Agregar comentarios administrativos

---

### **⚙️ Configuración del Sistema**
Personalización y configuración global.

#### **Parámetros Generales**
- Nombre de la institución
- Año académico actual
- Periodo de evaluación
- Zona horaria
- Idioma predeterminado
- Logo institucional

#### **Gestión de Servicios Externos**

**API Taskboard (backend):**
- PostgreSQL y contenedor/servicio del API (FastAPI)
- Autenticación JWT y usuarios en `app_users`
- Variables de entorno y secretos (`JWT_SECRET`, `DATABASE_URL`, etc.)
- Salud del servicio (`/health`, logs de Docker)

**ResendMail (si aplica):**
- Configuración de credenciales API
- Gestión de templates de email
- Monitoreo del estado del servicio de envío
- Configuración de remitente y dominio de email
- Verificación de límites de envío
- Revisión de logs de envío

**⚠️ Importante:**
- El administrador es responsable de mantener ambos servicios operativos
- Cualquier problema con el API Taskboard o ResendMail afectará el funcionamiento del sistema
- Configura alertas para monitorear el estado de estos servicios

#### **Configuración de Notificaciones**
- **Sistema de notificaciones:**
  - **API Taskboard**: Base de datos y autenticación (JWT)
  - **ResendMail**: Gestión del servicio de envío de emails
  - Configuración de credenciales API de ResendMail
  - Templates de emails personalizados
  - Frecuencia y tipos de notificaciones por email
  - Monitoreo del estado del servicio de emails
  
- **Notificaciones en app:**
  - Tipos habilitados/deshabilitados
  - Prioridades
  - Sonido y badges

**Importante:** El administrador es responsable de mantener operativos el backend Taskboard y, si se usa correo transaccional, ResendMail.

#### **Políticas de Seguridad**
- Complejidad de contraseñas
- Tiempo de sesión
- Intentos de login permitidos
- Autenticación de dos factores (2FA)
- Políticas de backup
- **Limitación de dominio para registro**: Debe aplicarse en el backend (validación de email al registrar) o en la política de despliegue
  - Esta configuración previene registros no autorizados
  - Solo usuarios con emails del dominio permitido pueden ser creados
  - Ajustes concretos: ver `backend/README.md` y variables de entorno del API

#### **Flujos de Trabajo**
- Estados personalizados de tareas
- Transiciones permitidas
- Aprobaciones requeridas
- Plazos predeterminados

---

### **🔔 Notificaciones**
Como admin, recibes notificaciones críticas del sistema.

**Tipos de notificaciones administrativas:**
- ⚠️ **Errores del sistema**: Fallos técnicos
- 🆘 **Escalación**: Problemas sin resolver
- 📊 **Reportes automáticos**: Resúmenes periódicos
- 🔐 **Seguridad**: Intentos de acceso sospechosos
- 💾 **Backup**: Estado de respaldos
- 📈 **Capacidad**: Límites de recursos

**Configuración recomendada:**
- Email inmediato para errores críticos
- Resumen diario de actividad general
- Alertas de seguridad en tiempo real

---

## 💡 Mejores Prácticas

### **✅ Gestión de Usuarios**

#### **Creación de Usuarios**

1. **Planifica antes del ciclo académico**
   - Prepara lista de usuarios con anticipación
   - Valida información con secretaría académica
   - Coordina con tutores las asignaciones

2. **Usa importación masiva**
   - Más eficiente para grupos grandes
   - Menos errores que entrada manual
   - Mantén plantilla CSV actualizada

3. **Nomenclatura consistente**
   - Establece convención para emails
   - Usa formato estándar para nombres
   - Documenta convenciones

4. **Seguridad desde el inicio**
   - Genera contraseñas seguras
   - Fuerza cambio de contraseña en primer login
   - Habilita 2FA para admins y tutores

---

#### **Mantenimiento de Usuarios**

1. **Auditoría regular**
   - Revisa usuarios inactivos mensualmente
   - Verifica asignaciones tutor-estudiante
   - Identifica cuentas duplicadas

2. **Ciclo de vida de cuentas**
   - Desactiva (no elimines) cuentas al final del ciclo
   - Mantén histórico para referencias futuras
   - Archiva datos de usuarios antiguos

3. **Gestión de permisos**
   - Principio de mínimo privilegio
   - Revisa permisos de admin periódicamente
   - Documenta cambios de permisos

---

### **✅ Supervisión del Sistema**

1. **Monitoreo proactivo**
   - Revisa dashboard diariamente
   - Configura alertas automáticas
   - Identifica tendencias antes que problemas

2. **Métricas clave**
   ```
   Diarias:
   - Usuarios activos
   - Nuevos anteproyectos
   - Tareas completadas
   - Errores del sistema
   
   Semanales:
   - Tasa de aprobación de anteproyectos
   - Tiempo promedio de revisión
   - Estudiantes sin actividad
   - Carga de trabajo por tutor
   
   Mensuales:
   - Proyectos completados
   - Tasa de éxito general
   - Satisfacción de usuarios
   - Estadísticas de uso
   ```

3. **Reportes**
   - Genera reportes periódicos
   - Comparte con coordinación académica
   - Identifica áreas de mejora
   - Documenta cambios y mejoras

---

### **✅ Configuración y Mantenimiento**

1. **Backups regulares**
   - Configura backups automáticos diarios
   - Verifica integridad de backups semanalmente
   - Prueba restauración mensualmente
   - Mantén backups off-site

2. **Actualizaciones**
   - Planifica actualizaciones fuera de horario pico
   - Prueba en entorno de staging primero
   - Comunica actualizaciones a usuarios
   - Mantén documentación actualizada

3. **Seguridad**
   - Revisa logs de seguridad regularmente
   - Actualiza políticas de contraseñas
   - Audita accesos administrativos
   - Mantén software actualizado

---

### **⚠️ Errores Comunes a Evitar**

❌ **NO hagas:**
- Eliminar usuarios sin verificar dependencias
- Cambiar roles sin comunicar al usuario
- Compartir credenciales administrativas
- Ignorar alertas del sistema
- Modificar datos en producción sin backup
- Dar permisos de admin a usuarios regulares
- Dejar configuraciones predeterminadas de seguridad

✅ **SÍ haz:**
- Desactivar en lugar de eliminar cuando sea posible
- Notificar cambios de rol con anticipación
- Mantener credenciales seguras y rotarlas
- Investigar todas las alertas
- Siempre respaldar antes de cambios grandes
- Conceder solo permisos necesarios
- Personalizar configuración de seguridad

---

## 🔧 Resolución de Problemas Comunes

### **Problema 1: Usuario no puede iniciar sesión**

**Posibles causas:**
- Contraseña olvidada
- Cuenta desactivada
- Email no verificado
- Demasiados intentos fallidos (cuenta bloqueada)

**Solución paso a paso:**
1. Verificar estado de la cuenta en Gestión de Usuarios
2. Si está desactivada: reactivar cuenta
3. Si está bloqueada: desbloquear y notificar al usuario
4. Resetear contraseña y enviar nueva credencial
5. Verificar que el email esté confirmado
6. Probar inicio de sesión en tu navegador con esas credenciales
7. Si persiste: revisar logs del sistema

---

### **Problema 2: Anteproyecto sin revisar por mucho tiempo**

**Análisis:**
- ¿El tutor está activo en el sistema?
- ¿El tutor tiene demasiada carga?
- ¿Hay problemas técnicos?

**Solución:**
1. Contactar al tutor asignado
2. Si no responde: reasignar a otro tutor
3. Notificar al estudiante sobre el cambio
4. Documentar la reasignación
5. Seguimiento para asegurar revisión

---

### **Problema 3: Importación CSV fallida**

**Errores comunes:**
- Formato de columnas incorrecto
- Emails duplicados
- Campos obligatorios vacíos
- Codificación de archivo incorrecta (no UTF-8)
- Tutor asignado no existe

**Solución:**
1. Descargar plantilla CSV actualizada
2. Verificar codificación del archivo (UTF-8)
3. Revisar que todas las columnas requeridas estén presentes
4. Validar que los emails de tutores existan en el sistema
5. Eliminar filas con emails duplicados
6. Reintentar importación
7. Revisar log de errores para detalles específicos

---

### **Problema 4: Sistema lento o con errores**

**Diagnóstico:**
1. Verificar métricas de servidor (CPU, RAM, disco)
2. Revisar logs de errores
3. Verificar conexión a base de datos
4. Comprobar servicios externos (API Taskboard, correo)

**Soluciones:**
- Si es carga alta: escalar recursos
- Si es error de BD: revisar queries lentas
- Si es servicio externo: contactar soporte
- Si persiste: contactar soporte técnico con logs

---

## 📊 Reportes y Estadísticas

### **Reportes Recomendados**

#### **Reporte Diario (Automatizado)**
```
Actividad del Sistema - [Fecha]

Usuarios:
- Activos hoy: [número]
- Nuevos registros: [número]
- Inactivos >7 días: [número]

Anteproyectos:
- Nuevos: [número]
- Aprobados hoy: [número]
- Pendientes de revisión: [número]
- Tiempo promedio de revisión: [tiempo]

Tareas:
- Completadas hoy: [número]
- Vencidas: [número]
- En revisión: [número]

Alertas:
- Errores del sistema: [número]
- Bloqueos de cuenta: [número]
```

---

#### **Reporte Semanal**
```
Resumen Semanal - Semana [número]

Métricas Generales:
- Tasa de aprobación de anteproyectos: [porcentaje]
- Promedio de tareas por estudiante: [número]
- Estudiantes sin actividad: [lista]

Por Tutor:
- [Nombre Tutor]:
  - Estudiantes asignados: [número]
  - Anteproyectos revisados: [número]
  - Tiempo promedio de revisión: [tiempo]
  - Tareas asignadas: [número]

Proyectos:
- Activos: [número]
- En riesgo (retraso): [número]
- Próximos a completar: [número]
```

---

#### **Reporte Mensual (Para Coordinación)**
```
Informe Mensual - [Mes/Año]

Resumen Ejecutivo:
- Total de proyectos activos: [número]
- Tasa de éxito: [porcentaje]
- Proyectos completados: [número]

Estadísticas de Usuarios:
- Estudiantes: [número] ([+/-] vs mes anterior)
- Tutores: [número]
- Tasa de actividad: [porcentaje]

Desempeño del Sistema:
- Uptime: [porcentaje]
- Tiempo promedio de respuesta: [ms]
- Errores reportados: [número]
- Incidentes resueltos: [número]

Recomendaciones:
- [Lista de mejoras sugeridas basadas en datos]
```

---

## 🎯 Casos de Uso Administrativos

### **Caso 1: Inicio de Ciclo Académico**

**Checklist:**
1. [ ] Actualizar año académico en configuración
2. [ ] Importar lista de nuevos estudiantes
3. [ ] Importar lista de tutores (si hay nuevos)
4. [ ] Asignar estudiantes a tutores
5. [ ] Verificar que todos los usuarios tengan acceso
6. [ ] Enviar email de bienvenida con instrucciones
7. [ ] Programar sesión de capacitación
8. [ ] Configurar fechas de hitos importantes
9. [ ] Activar notificaciones
10. [ ] Verificar backups automáticos

---

### **Caso 2: Reasignación de Tutor**

**Situación:** Un tutor se ausenta o cambia de rol

**Proceso:**
1. Identificar estudiantes afectados
2. Seleccionar nuevo tutor (verificar carga de trabajo)
3. Notificar a todas las partes:
   - Tutor original (si es posible)
   - Nuevo tutor
   - Estudiantes afectados
4. Actualizar asignaciones en el sistema
5. Transferir contexto (reunión entre tutores si es posible)
6. Verificar que el nuevo tutor tenga acceso a todo
7. Seguimiento en las primeras semanas
8. Documentar el cambio y motivos

---

### **Caso 3: Usuario Reporta Problema Técnico**

**Flujo de soporte:**
1. Recibir reporte (email, ticket, mensaje)
2. Registrar en sistema de tickets
3. Reproducir el problema:
   - ¿Puedes replicarlo?
   - ¿Afecta a otros usuarios?
   - ¿Desde cuándo ocurre?
4. Clasificar severidad:
   - **Crítica**: Sistema no funciona
   - **Alta**: Funcionalidad importante afectada
   - **Media**: Inconveniente pero hay workaround
   - **Baja**: Mejora o problema cosmético
5. Solucionar:
   - Crítica/Alta: Inmediato
   - Media: Dentro de 48 horas
   - Baja: Próxima ventana de mantenimiento
6. Verificar solución con el usuario
7. Documentar problema y solución
8. Cerrar ticket

---

## 🔐 Seguridad y Cumplimiento

### **Buenas Prácticas de Seguridad**

1. **Acceso Administrativo**
   - Usa cuenta administrativa solo para tareas admin
   - Mantén cuenta personal separada para uso regular
   - Nunca compartas credenciales administrativas
   - Cierra sesión cuando no estés activo

2. **Gestión de Contraseñas**
   - Usa contraseña fuerte y única para admin
   - Habilita autenticación de dos factores (2FA)
   - Cambia contraseña cada 90 días
   - No anotes contraseñas en lugares inseguros

3. **Auditoría**
   - Revisa logs de acceso administrativo mensualmente
   - Documenta todos los cambios importantes
   - Mantén registro de decisiones críticas
   - Genera reportes de auditoría trimestrales

4. **Protección de Datos**
   - Respeta LOPD/GDPR en gestión de datos personales
   - No exportes datos sin autorización
   - Encripta backups
   - Elimina datos de forma segura

---

### **Cumplimiento Legal**

**LOPD/GDPR - Datos Personales:**
- Solo recopila datos necesarios
- Informa a usuarios sobre uso de sus datos
- Permite acceso y rectificación de datos personales
- Elimina datos cuando ya no sean necesarios
- Protege datos con medidas técnicas apropiadas

**Derechos de Usuarios:**
- Derecho a acceso: Ver sus datos
- Derecho a rectificación: Corregir datos incorrectos
- Derecho a supresión: "Derecho al olvido"
- Derecho a portabilidad: Exportar sus datos

---

## 📚 Recursos para Administradores

### **Documentación Técnica**
- [Guía de Despliegue VPS Debian](../despliegue/guia_despliegue_vps_debian.md)
- [Arquitectura del Sistema de Autenticación](../arquitectura/login.md)
- [Registro de Usuarios por Roles](../arquitectura/registro_usuarios_por_roles.md)

### **Herramientas Útiles**
- **PostgreSQL / panel de BD**: Gestión directa de la base de datos del API
- **Logs del Sistema**: Diagnóstico de problemas
- **Google Analytics**: (Si está configurado) Métricas de uso

### **Comandos Útiles**
```bash
# Ver logs del servidor
sudo journalctl -u nombre-servicio -f

# Verificar espacio en disco
df -h

# Ver procesos activos
top

# Backup manual de BD
# (comando específico según tu despliegue de PostgreSQL, p. ej. pg_dump)
```

---

## ✨ Conclusión

Como administrador, eres el guardián del sistema. Tu rol va más allá de la gestión técnica: aseguras que estudiantes y tutores puedan enfocarse en lo importante (aprendizaje y enseñanza) sin preocuparse por problemas técnicos.

### **Principios Clave:**
1. **Proactividad**: Prevén problemas antes de que ocurran
2. **Disponibilidad**: Sé accesible cuando te necesiten
3. **Documentación**: Registra todo para referencia futura
4. **Seguridad**: Protege el sistema y los datos de usuarios
5. **Mejora continua**: Busca siempre optimizar procesos

### **Tu Impacto:**
Un sistema bien administrado es invisible. Si usuarios no piensan en problemas técnicos, estás haciendo un excelente trabajo.

**¡Éxito en tu labor administrativa!** 🎯

---

**Última actualización:** Noviembre 2025  
**Versión de la aplicación:** Flutter + API Taskboard  
**Soporte Técnico:** [Contacto de soporte de nivel superior si aplica]

