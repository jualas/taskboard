# Scripts de Construcción

## 🪟 Windows Desktop

### Construir y Empaquetar Aplicación Windows

```powershell
# Desde el directorio frontend/
.\scripts\build-windows-release.ps1
```

Este script:
1. Limpia builds anteriores
2. Obtiene dependencias actualizadas
3. Construye la aplicación en modo Release
4. Crea un ZIP listo para distribución en `dist/frontend-windows-release.zip`

**Requisitos:**
- Flutter SDK instalado
- Visual Studio 2022 con C++ tools
- Windows 10/11

**Salida:**
- Ejecutable: `build\windows\x64\runner\Release\taskboard.exe`
- Paquete ZIP: `dist\frontend-windows-release.zip`

