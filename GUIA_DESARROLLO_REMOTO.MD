# Guía de desarrollo (Taskboard API)

## Modos de datos

1. **API Taskboard (recomendado):** `ApiDataSource` + JWT. Configuración en `assets/data/config.json` (`taskboardApi`) o `--dart-define=TASKBOARD_API_URL`.
2. **Modo local:** sin API configurada, `StorageService` + `LocalAuthService` (demostración, datos en el dispositivo).

## Backend

- Código: `backend/` (FastAPI + Postgres).
- Migraciones: `backend/migrations/001_fresh_install.sql`.
- Despliegue Docker típico: `/mnt/datos/docker/taskboard-api/` (ver `INSTRUCCIONES_AGENTE.md`).

## Flutter

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Build web: `flutter build web --release`.
