# 📧 Configuración del Servidor MCP para Resend

## 🎯 Descripción
Este servidor MCP permite enviar correos electrónicos directamente desde Cursor usando la API de Resend.com. Es perfecto para notificaciones automáticas, reportes de sistema, o cualquier comunicación por email desde tu aplicación Flutter + Supabase.

## 🚀 Características
- ✅ Envío de emails en texto plano y HTML
- ✅ Programación de envíos futuros
- ✅ Destinatarios en CC y BCC
- ✅ Configuración de direcciones de respuesta
- ✅ Remitente personalizable (requiere verificación de dominio)
- ✅ Listado de audiencias de Resend

## 📋 Prerrequisitos

### 1. Cuenta de Resend
- Crear cuenta gratuita en [Resend.com](https://resend.com/)
- Generar API Key desde [API Keys](https://resend.com/api-keys)

### 2. Verificación de Dominio (Opcional pero Recomendado)
- Para enviar emails desde tu propio dominio, verifica tu dominio en [Resend Domains](https://resend.com/domains)
- Esto evita que los emails vayan a spam

## ⚙️ Configuración

### Paso 1: Obtener API Key de Resend
1. Ve a [Resend.com](https://resend.com/) y crea una cuenta
2. Navega a [API Keys](https://resend.com/api-keys)
3. Crea una nueva API Key
4. Copia la clave generada

### Paso 2: Configurar Variables de Entorno
Edita el archivo `c:\Users\Jualas\.cursor\mcp.json` y reemplaza `YOUR_RESEND_API_KEY_HERE` con tu API key real:

```json
{
  "mcpServers": {
    "resend": {
      "command": "node",
      "args": [
        "C:\\dev\\proyecto_flutter_supabase\\mcp-resend\\build\\index.js"
      ],
      "env": {
        "RESEND_API_KEY": "re_1234567890abcdef_1234567890abcdef"
      }
    }
  }
}
```

### Paso 3: Configuración Opcional
Puedes añadir variables de entorno adicionales:

```json
{
  "mcpServers": {
    "resend": {
      "command": "node",
      "args": [
        "C:\\dev\\proyecto_flutter_supabase\\mcp-resend\\build\\index.js"
      ],
      "env": {
        "RESEND_API_KEY": "re_1234567890abcdef_1234567890abcdef",
        "SENDER_EMAIL_ADDRESS": "noreply@tudominio.com",
        "REPLY_TO_EMAIL_ADDRESS": "support@tudominio.com"
      }
    }
  }
}
```

## 🔄 Reiniciar Cursor
Después de modificar la configuración:
1. Guarda el archivo `mcp.json`
2. Reinicia Cursor completamente
3. Verifica que el servidor MCP esté activo en la configuración

## 📝 Uso en Cursor

### Comandos Disponibles
Una vez configurado, tendrás acceso a estos comandos en Cursor:

- **`send_email`**: Enviar un email
- **`list_audiences`**: Listar audiencias de Resend
- **`schedule_email`**: Programar envío de email

### Ejemplo de Uso
```
Envía un email a juan@ejemplo.com con el asunto "Notificación del Sistema" 
y el contenido "El sistema ha procesado correctamente tu solicitud."
```

### Parámetros del Email
- **to**: Dirección de destino (requerido)
- **subject**: Asunto del email (requerido)
- **content**: Contenido del email (requerido)
- **cc**: Copia (opcional)
- **bcc**: Copia oculta (opcional)
- **reply_to**: Dirección de respuesta (opcional)
- **from**: Remitente (opcional, usa el configurado por defecto)

## 🔧 Integración con tu Proyecto Flutter + Supabase

### Casos de Uso Recomendados
1. **Notificaciones de Proyectos**: Enviar emails cuando se aprueben/rechacen proyectos
2. **Recordatorios**: Notificar a estudiantes sobre fechas límite
3. **Reportes**: Enviar resúmenes semanales a tutores
4. **Alertas del Sistema**: Notificar sobre errores o problemas

### Ejemplo de Integración
```dart
// En tu servicio de notificaciones
class NotificationService {
  // Llamar a la función de Supabase que usa Resend
  Future<void> sendProjectApprovalEmail(String studentEmail, String projectTitle) async {
    await supabase.functions.invoke('send-email', body: {
      'to': studentEmail,
      'subject': 'Proyecto Aprobado - $projectTitle',
      'content': 'Tu proyecto ha sido aprobado por el tutor.'
    });
  }
}
```

## 🛠️ Solución de Problemas

### Error: "Invalid API Key"
- Verifica que tu API Key sea correcta
- Asegúrate de que la API Key tenga permisos de envío

### Error: "Domain not verified"
- Verifica tu dominio en Resend
- O usa el email por defecto de Resend (onboarding@resend.dev)

### Error: "Rate limit exceeded"
- Resend tiene límites de envío
- Plan gratuito: 3,000 emails/mes, 100 emails/día

### El servidor MCP no aparece en Cursor
1. Verifica la ruta del archivo `build/index.js`
2. Reinicia Cursor completamente
3. Revisa la consola de Cursor para errores

## 📚 Documentación Adicional
- [Resend Documentation](https://resend.com/docs)
- [MCP Documentation](https://docs.anthropic.com/en/docs/agents-and-tools/mcp)
- [Resend API Reference](https://resend.com/docs/api-reference)

## 🔒 Seguridad
- **NUNCA** commitees tu API Key real al repositorio
- Usa variables de entorno para credenciales sensibles
- Considera usar diferentes API Keys para desarrollo y producción
- Revisa regularmente los logs de envío en Resend

## 💡 Consejos
- Usa templates de email para consistencia
- Implementa rate limiting en tu aplicación
- Monitorea las métricas de entrega en Resend
- Considera usar webhooks para notificaciones de entrega
