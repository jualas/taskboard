# Instalador para Sistema TFG - Inno Setup

Este directorio contiene los archivos necesarios para generar un instalador `.exe` para la aplicación Windows usando Inno Setup.

## Requisitos Previos

1. **Inno Setup** (versión 6.0 o superior)
   - Descargar desde: https://jrsoftware.org/isdl.php
   - Instalar la versión completa (incluye el compilador de línea de comandos)

2. **Aplicación compilada**
   - Asegúrate de haber ejecutado `flutter build windows` antes de crear el instalador
   - Los archivos deben estar en `build\windows\x64\runner\Release`

## Uso

### Opción 1: Usando Inno Setup Compiler (GUI)

1. Abre Inno Setup Compiler
2. Abre el archivo `sistema_tfg_setup.iss`
3. Haz clic en "Build" > "Compile" (o presiona F9)
4. El instalador se generará en `build\installer\SistemaTFG_Installer_v1.0.0.exe`

### Opción 2: Usando línea de comandos

Desde el directorio `installer`, ejecuta:

```bash
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" sistema_tfg_setup.iss
```

O si tienes Inno Setup en otra ubicación, ajusta la ruta.

### Opción 3: Script automatizado

Ejecuta el script `build_installer.bat` que automatiza todo el proceso:

```bash
build_installer.bat
```

## Estructura del Instalador

El instalador incluye:
- ✅ Ejecutable principal (`sistema_tfg.exe`)
- ✅ Todas las DLLs necesarias
- ✅ Carpeta `data` completa con recursos y assets
- ✅ Acceso directo en el menú de inicio
- ✅ Opción de acceso directo en el escritorio
- ✅ Desinstalador completo

## Personalización

Para modificar el instalador, edita `sistema_tfg_setup.iss`:

- **Versión**: Cambia `#define MyAppVersion` en la línea 6
- **Nombre**: Cambia `#define MyAppName` en la línea 5
- **Icono**: El icono se toma de `windows\runner\resources\app_icon.ico`
- **Ruta de instalación**: Modifica `DefaultDirName` en la sección `[Setup]`

## Notas

- El instalador requiere permisos de administrador
- El instalador es de 64 bits (x64)
- El tamaño del instalador será aproximadamente 30-40 MB (comprimido)

