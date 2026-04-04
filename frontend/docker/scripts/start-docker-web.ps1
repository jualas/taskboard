# Script simplificado para iniciar el contenedor web
# Requiere Docker Desktop ejecutándose

Write-Host "🚀 INICIANDO CONTENEDOR WEB FLUTTER" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ Error: Ejecuta este script desde el directorio frontend/" -ForegroundColor Red
    exit 1
}

# Verificar que Docker Desktop esté ejecutándose
Write-Host "📋 Verificando Docker Desktop..." -ForegroundColor Yellow
try {
    docker version | Out-Null
    Write-Host "✅ Docker Desktop está ejecutándose" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Docker Desktop no está ejecutándose" -ForegroundColor Red
    Write-Host "Por favor, inicia Docker Desktop y vuelve a ejecutar este script" -ForegroundColor Yellow
    exit 1
}

# Verificar que la aplicación web esté construida
if (-not (Test-Path "build/web/index.html")) {
    Write-Host "📋 Construyendo aplicación Flutter Web..." -ForegroundColor Yellow
    flutter build web --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: No se pudo construir la aplicación web" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Aplicación web construida" -ForegroundColor Green
} else {
    Write-Host "✅ Aplicación web ya está construida" -ForegroundColor Green
}

# Detener contenedores existentes
Write-Host "📋 Limpiando contenedores existentes..." -ForegroundColor Yellow
docker-compose -f docker/docker-compose.yml down --volumes --remove-orphans 2>$null

# Construir y ejecutar contenedor
Write-Host "📋 Construyendo imagen Docker..." -ForegroundColor Yellow
docker-compose -f docker/docker-compose.yml build --no-cache
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: No se pudo construir la imagen Docker" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Iniciando contenedor..." -ForegroundColor Yellow
docker-compose -f docker/docker-compose.yml up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: No se pudo iniciar el contenedor" -ForegroundColor Red
    exit 1
}

# Esperar un momento
Start-Sleep -Seconds 3

# Verificar estado
Write-Host "📋 Verificando estado del contenedor..." -ForegroundColor Yellow
docker-compose -f docker/docker-compose.yml ps

# Verificar conectividad
Write-Host "📋 Verificando conectividad..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Aplicación web accesible en http://localhost:8082" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Aplicación web responde pero con código: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error: No se puede acceder a la aplicación web" -ForegroundColor Red
    Write-Host "Verifica los logs con: docker-compose -f docker/docker-compose.yml logs -f" -ForegroundColor Yellow
}

Write-Host "🎉 CONTENEDOR INICIADO" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "🌐 Aplicación web: http://localhost:8082" -ForegroundColor Cyan
Write-Host "🔧 Comandos útiles:" -ForegroundColor Cyan
Write-Host "  - Ver logs: docker-compose -f docker/docker-compose.yml logs -f" -ForegroundColor White
Write-Host "  - Detener: docker-compose -f docker/docker-compose.yml down" -ForegroundColor White
Write-Host "  - Estado: docker-compose -f docker/docker-compose.yml ps" -ForegroundColor White
