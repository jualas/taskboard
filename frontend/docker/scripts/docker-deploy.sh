#!/bin/bash

# Script para desplegar la aplicación Flutter Web con Docker
# Ubicación: docker/scripts/docker-deploy.sh
# Uso: ./docker/scripts/docker-deploy.sh [production|development]

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con color
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que Docker esté instalado
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado. Por favor, instala Docker primero."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose no está instalado. Por favor, instala Docker Compose primero."
        exit 1
    fi

    print_success "Docker y Docker Compose están instalados"
}

# Función para limpiar contenedores y volúmenes
cleanup() {
    print_message "Limpiando contenedores y volúmenes anteriores..."
    cd "$(dirname "$0")/.."  # Ir al directorio docker/
    docker-compose down --volumes --remove-orphans
    docker system prune -f
    print_success "Limpieza completada"
}

# Función para construir y ejecutar en producción
deploy_production() {
    print_message "Desplegando aplicación en modo PRODUCCIÓN..."
    
    # Cambiar al directorio docker/
    cd "$(dirname "$0")/.."
    
    # Limpiar antes de construir
    cleanup
    
    # Construir imagen
    print_message "Construyendo imagen de producción..."
    docker-compose build --no-cache frontend-web
    
    # Ejecutar en modo producción
    print_message "Iniciando aplicación en modo producción..."
    docker-compose up -d frontend-web
    
    print_success "Aplicación desplegada en modo producción"
    print_message "Accede a: http://localhost:8080"
}

# Función para ejecutar en modo desarrollo
deploy_development() {
    print_message "Desplegando aplicación en modo DESARROLLO..."
    
    # Cambiar al directorio docker/
    cd "$(dirname "$0")/.."
    
    # Limpiar antes de construir
    cleanup
    
    # Construir imagen de desarrollo
    print_message "Construyendo imagen de desarrollo..."
    docker-compose --profile dev build --no-cache frontend-dev
    
    # Ejecutar en modo desarrollo
    print_message "Iniciando aplicación en modo desarrollo..."
    docker-compose --profile dev up -d frontend-dev
    
    print_success "Aplicación desplegada en modo desarrollo"
    print_message "Accede a: http://localhost:3000"
}

# Función para mostrar logs
show_logs() {
    print_message "Mostrando logs de la aplicación..."
    cd "$(dirname "$0")/.."
    docker-compose logs -f
}

# Función para mostrar estado
show_status() {
    print_message "Estado de los contenedores:"
    cd "$(dirname "$0")/.."
    docker-compose ps
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo "  production    Desplegar en modo producción (puerto 8080)"
    echo "  development   Desplegar en modo desarrollo (puerto 3000)"
    echo "  logs          Mostrar logs de la aplicación"
    echo "  status        Mostrar estado de los contenedores"
    echo "  stop          Detener la aplicación"
    echo "  cleanup       Limpiar contenedores y volúmenes"
    echo "  help          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 production"
    echo "  $0 development"
    echo "  $0 logs"
    echo ""
    echo "Nota: Este script debe ejecutarse desde el directorio raíz del proyecto"
}

# Función principal
main() {
    # Verificar Docker
    check_docker
    
    # Procesar argumentos
    case "${1:-help}" in
        "production")
            deploy_production
            ;;
        "development")
            deploy_development
            ;;
        "logs")
            show_logs
            ;;
        "status")
            show_status
            ;;
        "stop")
            print_message "Deteniendo aplicación..."
            cd "$(dirname "$0")/.."
            docker-compose down
            print_success "Aplicación detenida"
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Ejecutar función principal
main "$@"
