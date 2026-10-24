---
name: flutter-clean-architecture
description: >-
  Aplica la Clean Architecture del cliente Flutter de TaskBoard (frontend/lib) al
  desarrollar: dónde va cada pieza (domain, data, presentation), un caso de uso por
  fichero, Result/Failure, DI con get_it, tests mínimos, migración del código heredado
  y criterio de cierre de las entregas CA-x. Usar siempre que se cree, modifique,
  revise o refactorice código en frontend/, al añadir una pantalla, BLoC, caso de uso
  o llamada al API, o cuando se pida "revisar la arquitectura", "migrar a features" o
  avanzar una tarea CA-0…CA-6 / CA-R.
---

# Clean Architecture en el frontend de TaskBoard

Fuente de verdad: `docs/architecture/clean-architecture.md` (ADR). Resumen siempre cargado: `.cursor/rules/clean-architecture.mdc`. Este skill es el **procedimiento**: qué hacer antes, durante y después de tocar `frontend/`. Plantillas de código en [reference.md](reference.md).

## 1. Antes de editar

1. Identificar la feature (`tasks`, `projects`, `auth`, `ai_assistant`) y la entrega CA-x a la que pertenece el cambio (tabla del ADR y tareas CA-* del proyecto 10 en TaskBoard).
2. Usar `features/tasks/` como referencia de estructura y estilo.
3. Si el fichero a tocar está en código heredado (`lib/screens`, `lib/widgets`, `lib/blocs`, `lib/services`, `lib/models`):
   - Feature ya migrada (`tasks`, `projects`): moverlo a `features/<f>/presentation/` en el mismo cambio (`git mv`, para conservar historial).
   - Feature pendiente (`auth`, `ai_assistant`): cambio mínimo en el sitio y anotarlo como deuda de su CA-x. **Nunca** crear ficheros nuevos ahí.

## 2. Dónde va cada cosa

| Necesito… | Va en | Prohibido |
|---|---|---|
| Regla de negocio (orden kanban, validación, permisos, conversión de respuesta IA → tareas) | entidad o caso de uso (`domain/`) | repositorio, BLoC, widget |
| Llamada HTTP / almacenamiento | data source (`data/datasources/`) | domain, presentation |
| JSON ↔ objeto | `*Model` + mapper en `data/models/` | entidades con `fromJson` |
| Traducir excepciones | `*RepositoryImpl` con `mapExceptionToFailure` → `Result<T>` | lanzar excepciones hacia arriba |
| Acción de UI | un `UseCase<T, P>` por fichero, verbo + entidad | ficheros con varios casos de uso; casos de uso "por si acaso" |
| Estado de pantalla | BLoC/Cubit que recibe casos de uso por constructor | `sl<…>()` o `new Servicio()` en widgets |
| Registro | `core/di/injection.dart`: `registerLazySingleton` (data sources, repos, casos de uso), `registerFactory` (BLoCs) | construir BLoCs a mano con `sl<UseCase>()` fuera de DI |

Dependencias: `presentation → domain ← data`. `domain` es Dart puro (sin `package:flutter`, `http`, `dio`, `json_annotation`, `shared_preferences`, ni `data/` o `presentation/`). Solo `core/di/injection.dart` conoce todas las capas.

## 3. Checklist del cambio

- [ ] Ningún import de `data/`, `services/` o `models/` (heredado) desde `presentation/`.
- [ ] Ningún import de Flutter/HTTP/JSON ni de otras capas desde `domain/`.
- [ ] Casos de uso nuevos: un fichero cada uno, exportados en el barrel de la feature si existe.
- [ ] Repositorio devuelve `Result<T>`; los errores llegan como `Failure`.
- [ ] Servicios (`AiAssistantService`, etc.) solo a través de repositorio + caso de uso registrados en DI.
- [ ] Tests añadidos o actualizados (ver §4).
- [ ] Sin código nuevo en carpetas heredadas.

## 4. Tests mínimos por feature

En `frontend/test/unit/` (y `test/architecture/`):

- Casos de uso con **mocktail** sobre el repositorio abstracto (éxito y fallo).
- `*RepositoryImpl` con data source simulado (éxito y traducción de excepciones a `Failure`).
- Mappers DTO ↔ entidad.
- BLoC con **bloc_test**.
- `test/architecture/dependency_rule_test.dart` no se desactiva ni se le añaden excepciones sin explicarlo en el ADR.

## 5. Verificación

Desde la raíz del repo:

```bash
scripts/flutter-check.sh            # analyze + test
scripts/flutter-check.sh --vs-main  # además compara avisos con origin/main
```

Usa `flutter` local si existe; si no, la imagen `ghcr.io/cirruslabs/flutter:stable` y devuelve la propiedad de los ficheros al usuario. Criterio: **tests en verde** y **ningún aviso de `flutter analyze` nuevo respecto a `main`** (comparación por tipo de aviso, sin números de línea). La base es `origin/main` recién descargado (no el `main` local, que puede estar desactualizado); `--base <ref>` permite otra y `--no-test` omite los tests. El CI ejecuta el mismo script en cada PR contra su rama base.

## 6. Entregas CA-x

0. Empezar cada entrega en una **rama nueva desde `origin/main` actualizado** (`git fetch origin main:main && git switch -c refactor/clean-arch-<n>-<feature> main`). No seguir trabajando en una rama ya fusionada.
1. Commits pequeños en la rama de la entrega (`refactor(<f>): … (CA-x)`, `test(<f>): … (CA-x)`; también `ci:`/`fix:` llevan `(CA-x)` si son parte de la entrega).
2. `scripts/flutter-check.sh --vs-main` sin avisos nuevos y tests en verde.
3. Prueba manual de las pantallas afectadas (`flutter run -d chrome` o build web).
4. PR con tabla requisito → evidencia (fichero/test que lo demuestra).
5. En TaskBoard (proyecto 10): marcar subtareas hechas de CA-x y de CA-R; la tarea pasa a `completed` solo con el PR fusionado.
6. Si cambió una decisión: actualizar ADR y después `.cursor/rules/clean-architecture.mdc` (si discrepan, manda el ADR).

## 7. Deuda conocida (revisar y actualizar al cerrar cada CA-x)

Estado de `main` a 2026-10-24 (tras los PR #17 y #22, CA-0…CA-4 fusionadas):

- `ProjectsRemoteDataSource` y `TasksRemoteDataSource` siguen adaptando los modelos de `lib/models/` a través de `TaskboardDataSource`. El borrado de `models/task.dart` (de CA-2) y de los modelos de projects (de CA-3) se trasladó a CA-6.
- `AiAssistantService` usado directamente desde `features/projects/presentation/screens/projects_list_screen.dart`, `features/tasks/presentation/screens/task_form.dart` y `lib/widgets/project_ai_chat_panel.dart` → CA-5.
- Borrado final de `lib/blocs`, `lib/models`, `lib/services` → CA-6.

Al resolver un punto, quitarlo de esta lista en el mismo commit.
