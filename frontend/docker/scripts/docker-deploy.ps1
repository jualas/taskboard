# Script PowerShell para desplegar la aplicación Flutter Web con Docker
# Ubicación: docker/scripts/docker-deploy.ps1
# Uso: .\docker\scripts\docker-deploy.ps1 [production|development]

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

# Función para imprimir mensajes con color
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Verificar que Docker esté instalado
function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker no está instalado. Por favor, instala Docker primero."
        exit 1
    }

    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Error "Docker Compose no está instalado. Por favor, instala Docker Compose primero."
        exit 1
    }

    Write-Success "Docker y Docker Compose están instalados"
}

# Verificar que Flutter esté instalado
function Test-Flutter {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Error "Flutter no está instalado. Por favor, instala Flutter primero."
        exit 1
    }

    Write-Success "Flutter está instalado"
}

# Función para hacer build de la aplicación
function Build-Flutter {
    Write-Info "Haciendo build de la aplicación Flutter..."
    
    # Verificar que existe el directorio build/web
    if (-not (Test-Path "build/web")) {
        Write-Info "Directorio build/web no existe, creando build..."
        flutter build web --release
    } else {
        Write-Info "Directorio build/web existe, verificando si necesita actualización..."
        $lastModified = (Get-ChildItem "lib" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
        $buildModified = (Get-ChildItem "build/web" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
        
        if ($lastModified -gt $buildModified) {
            Write-Info "Código fuente más reciente que build, reconstruyendo..."
            flutter build web --release
        } else {
            Write-Info "Build actualizado, no es necesario reconstruir"
        }
    }
    
    Write-Success "Build de Flutter completado"
}

# Función para limpiar contenedores y volúmenes
function Clear-Docker {
    Write-Info "Limpiando contenedores y volúmenes anteriores..."
    $dockerDir = Join-Path $PSScriptRoot ".."
    Set-Location $dockerDir
    docker-compose down --volumes --remove-orphans
    docker system prune -f
    Write-Success "Limpieza completada"
}

# Función para construir y ejecutar en producción
function Deploy-Production {
    Write-Info "Desplegando aplicación en modo PRODUCCIÓN..."
    
    # Verificar dependencias
    Test-Docker
    Test-Flutter
    
    # Hacer build de Flutter
    Build-Flutter
    
    # Cambiar al directorio docker/
    $dockerDir = Join-Path $PSScriptRoot ".."
    Set-Location $dockerDir
    
    # Limpiar antes de construir
    Clear-Docker
    
    # Construir imagen (solo servidor web)
    Write-Info "Construyendo imagen del servidor web..."
    docker-compose build --no-cache frontend-web
    
    # Ejecutar en modo producción
    Write-Info "Iniciando aplicación en modo producción..."
    docker-compose up -d frontend-web
    
    Write-Success "Aplicación desplegada en modo producción"
    Write-Info "Accede a: http://localhost:8080"
}

# Función para mostrar logs
function Show-Logs {
    Write-Info "Mostrando logs de la aplicación..."
    $dockerDir = Join-Path $PSScriptRoot ".."
    Set-Location $dockerDir
    docker-compose logs -f
}

# Función para mostrar estado
function Show-Status {
    Write-Info "Estado de los contenedores:"
    $dockerDir = Join-Path $PSScriptRoot ".."
    Set-Location $dockerDir
    docker-compose ps
}

# Función para mostrar ayuda
function Show-Help {
    Write-Host "Uso: .\docker\scripts\docker-deploy.ps1 [comando]"
    Write-Host ""
    Write-Host "Comandos disponibles:"
    Write-Host "  production    Desplegar en modo producción (puerto 8080)"
    Write-Host "  logs          Mostrar logs de la aplicación"
    Write-Host "  status        Mostrar estado de los contenedores"
    Write-Host "  stop          Detener la aplicación"
    Write-Host "  cleanup       Limpiar contenedores y volúmenes"
    Write-Host "  build         Solo hacer build de Flutter"
    Write-Host "  help          Mostrar esta ayuda"
    Write-Host ""
    Write-Host "Ejemplos:"
    Write-Host "  .\docker\scripts\docker-deploy.ps1 production"
    Write-Host "  .\docker\scripts\docker-deploy.ps1 build"
    Write-Host "  .\docker\scripts\docker-deploy.ps1 logs"
    Write-Host ""
    Write-Host "Nota: Este script debe ejecutarse desde el directorio raíz del proyecto"
}

# Función principal
function Main {
    # Procesar argumentos
    switch ($Command.ToLower()) {
        "production" {
            Deploy-Production
        }
        "logs" {
            Show-Logs
        }
        "status" {
            Show-Status
        }
        "stop" {
            Write-Info "Deteniendo aplicación..."
            $dockerDir = Join-Path $PSScriptRoot ".."
            Set-Location $dockerDir
            docker-compose down
            Write-Success "Aplicación detenida"
        }
        "cleanup" {
            Clear-Docker
        }
        "build" {
            Test-Flutter
            Build-Flutter
        }
        default {
            Show-Help
        }
    }
}

# Ejecutar función principal
Main