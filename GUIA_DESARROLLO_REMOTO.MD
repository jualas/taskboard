# Guía de Desarrollo Remoto y Persistencia

Este documento describe la estrategia de persistencia del proyecto para facilitar el trabajo entre diferentes máquinas y entornos.

## 1. Enfoque de Persistencia

El proyecto está diseñado para ser flexible en cuanto a dónde guarda los datos:

1.  **Modo Local (Offline):** Utiliza `StorageService` con `SharedPreferences`. Es ideal para desarrollo rápido sin conexión a internet. Los datos se guardan en el almacenamiento del navegador o del dispositivo.
2.  **Modo Remoto (Supabase):** Utiliza `SupabaseDataSource`. Centraliza los datos en una base de datos PostgreSQL en la nube, permitiendo la sincronización entre dispositivos.

## 2. Configuración de la Fuente de Datos

> [!IMPORTANT]
> **Proyecto Separado:** Esta rama de desarrollo utiliza un esquema de datos distinto al proyecto original. **Es obligatorio crear un nuevo proyecto en Supabase** para evitar conflictos.

1.  **Variables de Entorno (`--dart-define`):**...

1.  **Variables de Entorno (`--dart-define`):** Si se pasan `SUPABASE_URL` y `SUPABASE_ANON_KEY` al comando `flutter run`, se usará Supabase obligatoriamente.
2.  **Archivo de Configuración (`assets/data/config.json`):** Si no hay variables de entorno, se busca en la sección `supabase` del archivo JSON. Si `isEnabled` es true y tiene credenciales, se activa Supabase.
3.  **Fallback Local:** Si no se encuentra ninguna configuración válida de Supabase, la app inicia en modo local usando `SharedPreferences`.

## 3. Traslado a Supabase (Migración)

Para mover el proyecto definitivamente a Supabase:

1.  **Preparar la BD:** Crea un nuevo proyecto en Supabase y aplica el script SQL ubicado en:
    `supabase/migrations/20260115190000_taskboard_personal.sql`
2.  **Configurar Credenciales:** 
    *   Edita el archivo `.env` en el frontend con tu `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
    *   O bien, actualiza `frontend/assets/data/config.json`.
3.  **Habilitar RLS:** Si el proyecto va a ser multiusuario con autenticación real, habilita RLS en las tablas de Supabase siguiendo las guías en `docs/02_BASE_DE_DATOS.md`.

## 4. Problemas Comunes de Persistencia

- **Datos No Sincronizados:** Si trabajas en máquinas distintas y usas el Modo Local, los cambios no se verán en la otra máquina. Usa **Supabase** para evitar esto.
- **URL Incorrecta:** Asegúrate de usar la URL que termina en `.supabase.co` y no la URL del Dashboard.
