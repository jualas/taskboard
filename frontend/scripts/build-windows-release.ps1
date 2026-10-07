# Script para construir y empaquetar aplicación Windows
# Uso: .\scripts\build-windows-release.ps1

Write-Host "🚀 CONSTRUYENDO APLICACIÓN WINDOWS" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ Error: Ejecuta este script desde el directorio frontend/" -ForegroundColor Red
    exit 1
}

# Verificar que Flutter está disponible
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Flutter detectado: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Flutter no está disponible en el PATH" -ForegroundColor Red
    exit 1
}

# Paso 1: Limpiar
Write-Host "`n📋 Paso 1: Limpiando builds anteriores..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Advertencia: flutter clean tuvo problemas" -ForegroundColor Yellow
}

# Paso 2: Obtener dependencias
Write-Host "`n📋 Paso 2: Obteniendo dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: No se pudieron obtener las dependencias" -ForegroundColor Red
    exit 1
}

# Paso 3: Construir aplicación
Write-Host "`n📋 Paso 3: Construyendo aplicación Windows (Release)..." -ForegroundColor Yellow
Write-Host "   Esto puede tardar varios minutos..." -ForegroundColor Gray
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error: La construcción falló" -ForegroundColor Red
    exit 1
}

# Verificar que el build fue exitoso
$exePath = "build\windows\x64\runner\Release\taskboard.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "`n❌ Error: No se encontró el ejecutable en $exePath" -ForegroundColor Red
    Write-Host "   Verifica que la construcción se completó correctamente" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n✅ Build completado exitosamente" -ForegroundColor Green
Write-Host "   Ejecutable: $exePath" -ForegroundColor Cyan

# Paso 4: Obtener información del ejecutable
$exeInfo = Get-Item $exePath
Write-Host "`n📊 Información del ejecutable:" -ForegroundColor Yellow
Write-Host "   Tamaño: $([math]::Round($exeInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "   Fecha: $($exeInfo.LastWriteTime)" -ForegroundColor Cyan

# Paso 5: Crear ZIP para distribución
Write-Host "`n📋 Paso 4: Creando paquete ZIP para distribución..." -ForegroundColor Yellow

$zipPath = "dist\frontend-windows-release.zip"
$releaseDir = "build\windows\x64\runner\Release"

# Crear directorio dist si no existe
if (-not (Test-Path "dist")) {
    New-Item -ItemType Directory -Path "dist" | Out-Null
    Write-Host "   Directorio 'dist' creado" -ForegroundColor Gray
}

# Eliminar ZIP anterior si existe
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "   ZIP anterior eliminado" -ForegroundColor Gray
}

# Verificar que el directorio Release existe
if (-not (Test-Path $releaseDir)) {
    Write-Host "`n❌ Error: No se encontró el directorio Release: $releaseDir" -ForegroundColor Red
    exit 1
}

# Comprimir carpeta Release
Write-Host "   Comprimiendo archivos..." -ForegroundColor Gray
Compress-Archive -Path "$releaseDir\*" -DestinationPath $zipPath -Force

if (Test-Path $zipPath) {
    $zipInfo = Get-Item $zipPath
    Write-Host "`n✅ Paquete ZIP creado exitosamente" -ForegroundColor Green
    Write-Host "   Archivo: $zipPath" -ForegroundColor Cyan
    Write-Host "   Tamaño: $([math]::Round($zipInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    
    # Mostrar contenido del ZIP
    Write-Host "`n📦 Contenido del paquete:" -ForegroundColor Yellow
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $zipPath).Path)
    $zip.Entries | Select-Object -First 10 | ForEach-Object {
        Write-Host "   - $($_.Name)" -ForegroundColor Gray
    }
    $zip.Dispose()
} else {
    Write-Host "`n⚠️  Advertencia: No se pudo crear el ZIP" -ForegroundColor Yellow
}

Write-Host "`n✅ PROCESO COMPLETADO" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "`n📝 Próximos pasos:" -ForegroundColor Yellow
Write-Host "   1. Probar el ejecutable: .\$exePath" -ForegroundColor Cyan
Write-Host "   2. Distribuir el ZIP: $zipPath" -ForegroundColor Cyan
Write-Host "   3. O crear un instalador con Inno Setup" -ForegroundColor Cyan
Write-Host "`n💡 Para probar la aplicación:" -ForegroundColor Yellow
Write-Host "   cd build\windows\x64\runner\Release" -ForegroundColor Gray
Write-Host "   .\taskboard.exe" -ForegroundColor Gray
Write-Host ""

