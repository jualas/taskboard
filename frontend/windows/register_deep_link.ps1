# Script para registrar el protocolo tfgapp:// en Windows
# Debe ejecutarse como administrador

param(
    [string]$BuildType = "Debug"
)

Write-Host "🔧 Registrando protocolo tfgapp:// para deep links..." -ForegroundColor Cyan

# Obtener ruta del proyecto
$projectPath = Split-Path -Parent $PSScriptRoot
$exePath = Join-Path $projectPath "build\windows\x64\runner\$BuildType\frontend.exe"

Write-Host "📁 Ruta del ejecutable: $exePath" -ForegroundColor Yellow

# Verificar que el ejecutable existe
if (-not (Test-Path $exePath)) {
    Write-Host "⚠️  El ejecutable no existe. Compilando primero..." -ForegroundColor Yellow
    Set-Location $projectPath
    flutter build windows --$($BuildType.ToLower())
    
    if (-not (Test-Path $exePath)) {
        Write-Host "❌ Error: No se pudo compilar la aplicación" -ForegroundColor Red
        exit 1
    }
}

# Crear las entradas del registro
$protocol = "tfgapp"
$registryPath = "HKCU:\Software\Classes\$protocol"

try {
    # Verificar permisos (intentar usar HKCU en lugar de HKCR para evitar necesidad de admin)
    Write-Host "🔑 Creando entradas del registro..." -ForegroundColor Cyan
    
    # Crear la clave principal del protocolo
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name "(Default)" -Value "URL:TFG App Protocol"
    New-ItemProperty -Path $registryPath -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
    
    # DefaultIcon
    $iconPath = "$registryPath\DefaultIcon"
    New-Item -Path $iconPath -Force | Out-Null
    Set-ItemProperty -Path $iconPath -Name "(Default)" -Value "$exePath,1"
    
    # shell\open\command
    $commandPath = "$registryPath\shell\open\command"
    New-Item -Path $commandPath -Force | Out-Null
    Set-ItemProperty -Path $commandPath -Name "(Default)" -Value "`"$exePath`" `"%1`""
    
    Write-Host "✅ Protocolo tfgapp:// registrado exitosamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔗 Ahora puedes usar URLs como: tfgapp://reset-password?code=..." -ForegroundColor Green
    Write-Host ""
    Write-Host "🧪 Para probar, ejecuta en PowerShell:" -ForegroundColor Yellow
    Write-Host "   Start-Process 'tfgapp://test'" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error al registrar el protocolo: $_" -ForegroundColor Red
    Write-Host "💡 Intenta ejecutar este script como administrador" -ForegroundColor Yellow
    exit 1
}

