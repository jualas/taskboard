# Instrucciones para agentes (Cursor, Claude Code, Codex, Copilot…)

Punto de entrada común para cualquier agente de IA que trabaje en este repo. Las herramientas que no leen este fichero tienen su propio enlace: `CLAUDE.md` (Claude Code), `.cursor/rules/` (Cursor).

## Contexto

- Contexto operativo, despliegue y procedimientos: [`INSTRUCCIONES_AGENTE.md`](INSTRUCCIONES_AGENTE.md).
- Backend: FastAPI + Postgres (`backend/`). Frontend: Flutter Web (`frontend/`).

## Frontend Flutter: Clean Architecture (obligatoria)

Antes de crear, modificar o revisar código en `frontend/`, leer y seguir:

1. **Skill [`flutter-clean-architecture`](.cursor/skills/flutter-clean-architecture/SKILL.md)**: procedimiento, dónde va cada pieza, checklist, tests mínimos, deuda conocida y cierre de entregas CA-x. Plantillas en su `reference.md`.
2. **Regla [`.cursor/rules/clean-architecture.mdc`](.cursor/rules/clean-architecture.mdc)**: resumen de la regla de dependencias `presentation → domain ← data`.
3. **ADR [`docs/architecture/clean-architecture.md`](docs/architecture/clean-architecture.md)**: decisiones; si algo discrepa, manda el ADR.

Verificación antes de dar un cambio por terminado (usa Docker si no hay `flutter` local):

```bash
.cursor/skills/flutter-clean-architecture/scripts/check.sh --vs-main
```

Debe terminar con tests en verde y sin avisos de `flutter analyze` nuevos respecto a `main`.

## Reglas y skills genéricas

Las reglas y skills genéricas (código, seguridad, planificación, IA) vienen del hub privado Skills-Rules y se instalan en local en `.cursor/` y `.claude/skills/`; no se versionan aquí. Sin ellas, aplicar como mínimo: cambios acotados, sin secretos en el repo y tests/linters del proyecto en verde.
