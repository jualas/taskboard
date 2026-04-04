# 🐳 Docker - Aplicación Flutter Web

> **Producción actual (jualas):** el sitio público `kanban.jualas.es` no usa este compose. Se publica en **`/mnt/datos/docker/taskboard-web`** (Caddy `:8580`) + túnel **`kanban-cloudflared`**. El API pasa por **Kong en el stack Supabase** (`api-supabase.jualas.es`), no por este Nginx. Procedimiento completo: **`INSTRUCCIONES_AGENTE.md`** §6. El servicio **`tfg-frontend-web`** (puerto 8083) quedó retirado por duplicidad.

## 📋 Descripción

Esta configuración Docker está optimizada para servir una aplicación Flutter Web de manera eficiente. **NO incluye Flutter en el contenedor** - el build se hace localmente y solo se sirven los archivos estáticos.

## 🚀 Despliegue Rápido

### **Opción 1: Script Automatizado (Recomendado)**

```powershell
# Windows PowerShell
.\docker\scripts\docker-deploy.ps1 production

# Linux/Mac Bash
./docker/scripts/docker-deploy.sh production
```

### **Opción 2: Comandos Manuales**

```bash
# 1. Build local de Flutter
flutter build web --release

# 2. Desplegar con Docker
cd docker
docker-compose up -d frontend-web
```

## 🌐 Acceso a la Aplicación

### **Modo Producción**
- **URL**: http://localhost:8082
- **Puerto**: 8082
- **Optimizado**: Sí (build release)

## 📁 Estructura del Directorio

```
docker/
├── web/                    # Archivos Docker para el servidor web
│   └── Dockerfile         # Servidor Nginx (sin Flutter)
├── nginx/                 # Configuración de Nginx
│   └── nginx.conf         # Configuración del servidor web
├── scripts/               # Scripts de despliegue
│   ├── docker-deploy.sh   # Script Bash (Linux/Mac)
│   └── docker-deploy.ps1  # Script PowerShell (Windows)
├── docker-compose.yml     # Configuración principal
└── README.md              # Esta documentación
```

## 🔧 Comandos Útiles

### **Scripts de Despliegue**

```powershell
# Windows PowerShell
.\docker\scripts\docker-deploy.ps1 help
.\docker\scripts\docker-deploy.ps1 production
.\docker\scripts\docker-deploy.ps1 build
.\docker\scripts\docker-deploy.ps1 status
.\docker\scripts\docker-deploy.ps1 logs
.\docker\scripts\docker-deploy.ps1 stop
.\docker\scripts\docker-deploy.ps1 cleanup
```

```bash
# Linux/Mac Bash
./docker/scripts/docker-deploy.sh help
./docker/scripts/docker-deploy.sh production
./docker/scripts/docker-deploy.sh build
./docker/scripts/docker-deploy.sh status
./docker/scripts/docker-deploy.sh logs
./docker/scripts/docker-deploy.sh stop
./docker/scripts/docker-deploy.sh cleanup
```

### **Docker Compose Directo**

```bash
# Desde el directorio docker/
cd docker

# Ver estado
docker-compose ps

# Ver logs
docker-compose logs -f

# Detener
docker-compose down

# Limpiar
docker-compose down --volumes --remove-orphans
```

## 🌍 Acceso desde Otros Dispositivos

### **Configuración de Red**

1. **Obtener IP del servidor**:
   ```powershell
   # Windows
   ipconfig
   
   # Linux/Mac
   ifconfig
   ```

2. **Acceder desde otros dispositivos**:
   ```
   http://[IP_DEL_SERVIDOR]:8082
   ```

3. **Configurar firewall** (Windows):
   ```powershell
   # PowerShell como administrador
   New-NetFirewallRule -DisplayName "Flutter Web" -Direction Inbound -Protocol TCP -LocalPort 8082 -Action Allow
   ```

## 🔒 Configuración de Seguridad

### **Variables de Entorno**

Crear archivo `.env` en el directorio raíz del proyecto:

```env
# Configuración de Supabase
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Configuración de la aplicación
NODE_ENV=production
FLUTTER_WEB_DEBUG=false
```

## 📊 Monitoreo y Logs

### **Logs de Aplicación**

```bash
# Ver logs de todos los servicios
cd docker
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f frontend-web

# Ver logs de Nginx
docker-compose exec frontend-web tail -f /var/log/nginx/access.log
```

### **Health Checks**

Los contenedores incluyen health checks automáticos:
- **Intervalo**: 30 segundos
- **Timeout**: 10 segundos
- **Reintentos**: 3
- **Período de inicio**: 40 segundos

## 🚨 Solución de Problemas

### **Problemas Comunes**

1. **Puerto ya en uso**:
   ```yaml
   # Cambiar puerto en docker/docker-compose.yml
   ports:
     - "8083:80"  # Cambiar 8082 por 8083
   ```

2. **Error de permisos** (Linux/Mac):
   ```bash
   # Hacer ejecutable el script
   chmod +x docker/scripts/docker-deploy.sh
   ```

3. **Error de build**:
   ```bash
   # Limpiar y reconstruir
   cd docker
   docker-compose down --volumes
   docker-compose build --no-cache
   ```

4. **Archivos build no encontrados**:
   ```bash
   # Hacer build de Flutter primero
   flutter build web --release
   ```

### **Logs de Debug**

```bash
# Ver logs detallados
docker-compose logs --tail=100 -f

# Ver logs de build
docker-compose build --no-cache --progress=plain
```

## 🔄 Actualizaciones

### **Actualizar Aplicación**

```bash
# 1. Actualizar código
git pull origin main

# 2. Hacer build
flutter build web --release

# 3. Reiniciar contenedor
cd docker
docker-compose restart frontend-web
```

### **Actualizar Dependencias**

```bash
# 1. Actualizar pubspec.yaml
flutter pub upgrade

# 2. Hacer build
flutter build web --release

# 3. Reiniciar contenedor
cd docker
docker-compose restart frontend-web
```

## 📚 Recursos Adicionales

- **Docker**: https://docs.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **Flutter Web**: https://docs.flutter.dev/platform-integration/web
- **Nginx**: https://nginx.org/en/docs/

## 🎯 Checklist de Despliegue

- [ ] Docker instalado y funcionando
- [ ] Docker Compose instalado
- [ ] Flutter instalado y funcionando
- [ ] Scripts de despliegue ejecutables
- [ ] Variables de entorno configuradas
- [ ] Puertos disponibles (8080)
- [ ] Firewall configurado (si es necesario)
- [ ] Build de Flutter completado
- [ ] Aplicación accesible desde navegador
- [ ] Logs funcionando correctamente
- [ ] Health checks pasando
- [ ] Otros desarrolladores pueden acceder

---

**¡La aplicación está lista para ser compartida con tu equipo! 🚀**