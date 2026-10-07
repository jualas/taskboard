@echo off
REM Script para construir el instalador de TaskBoard
REM Requiere Inno Setup instalado

echo ========================================
echo Construyendo instalador TaskBoard
echo ========================================
echo.

REM Verificar que Inno Setup esté instalado
set INNO_SETUP_PATH="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %INNO_SETUP_PATH% (
    set INNO_SETUP_PATH="C:\Program Files\Inno Setup 6\ISCC.exe"
    if not exist %INNO_SETUP_PATH% (
        echo ERROR: No se encontró Inno Setup
        echo Por favor, instala Inno Setup desde: https://jrsoftware.org/isdl.php
        pause
        exit /b 1
    )
)

REM Verificar que la aplicación esté compilada
if not exist "..\build\windows\x64\runner\Release\taskboard.exe" (
    echo ERROR: La aplicación no está compilada
    echo Ejecuta primero: flutter build windows
    pause
    exit /b 1
)

echo Compilando instalador...
echo.

REM Compilar el script de Inno Setup
%INNO_SETUP_PATH% "taskboard_setup.iss"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo ¡Instalador creado exitosamente!
    echo ========================================
    echo.
    echo El instalador se encuentra en: build\installer\
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR al crear el instalador
    echo ========================================
    echo.
)

pause

