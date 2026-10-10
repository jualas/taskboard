from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_DEV_JWT = "change-me-in-production-use-long-random-string"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "postgresql://taskboard:taskboard@localhost:5432/taskboard"
    jwt_secret: str = Field(default=_DEV_JWT)

    @field_validator("jwt_secret", mode="before")
    @classmethod
    def jwt_secret_trim_or_default(cls, v: object) -> object:
        if isinstance(v, str) and not v.strip():
            return _DEV_JWT
        return v
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 30

    # Registro abierto: solo en local. En una instancia publicada, false y altas manuales.
    allow_registration: bool = False
    cors_origins: str = "*"
    # Swagger/OpenAPI (/docs, /openapi.json): desactivado salvo que se pida.
    enable_docs: bool = False

    # Correos (separados por coma) que pueden usar carpetas del servidor y Cursor Agent.
    # Vacío = nadie: el asistente usa solo DeepSeek/Ollama sin acceso a disco.
    workspace_admin_emails: str = ""

    deepseek_api_key: str = ""
    deepseek_model: str = "deepseek-chat"
    deepseek_base_url: str = "https://api.deepseek.com"

    ollama_base_url: str = "http://127.0.0.1:11434"
    local_llm_model: str = "qwen2.5:3b-instruct-q4_K_M"
    # Plan de proyecto (muchas tareas): Ollama en CPU suele tardar varios minutos (ajusta por .env).
    ollama_timeout_plan_sec: float = 600.0
    ollama_timeout_sec: float = 180.0
    deepseek_timeout_plan_sec: float = 300.0
    deepseek_timeout_sec: float = 120.0

    # Rutas permitidas para workspace_path (separadas por coma). Deben montarse en el contenedor API.
    workspace_roots: str = (
        "/mnt/datos/docker,"
        "/mnt/datos/Proyectos,"
        "/mnt/datos/nextcloud/nextcloud-service/nextcloud-data/data/jualas/files/Proyectos,"
        "/home/jualas/datos/docker,"
        "/home/jualas/datos/Proyectos"
    )

    # Fase 2: snapshots periódicos y sugerencias automáticas
    workspace_snapshot_enabled: bool = True
    workspace_snapshot_interval_min: int = 30
    workspace_ai_suggestions: bool = True

    # Cursor CLI Agent (`agent --print`) en el mini PC — prioridad sobre DeepSeek/Ollama
    cursor_agent_enabled: bool = False
    cursor_agent_bin: str = "agent"
    cursor_agent_home: str = ""
    cursor_agent_default_workspace: str = (
        "/mnt/datos/Proyectos/taskboard"
    )
    cursor_agent_model: str = ""
    cursor_agent_mode: str = "ask"
    cursor_agent_timeout_sec: float = 300.0
    cursor_agent_timeout_plan_sec: float = 1200.0
    cursor_agent_approve_mcps: bool = True
    cursor_api_key: str = ""
    # Si false, no hace fallback a DeepSeek/Ollama cuando falla el CLI agent
    cursor_agent_fallback_llm: bool = False

    # Export TASKBOARD.md al workspace del proyecto (IDE / CLI fuera de la web)
    taskboard_md_filename: str = "TASKBOARD.md"
    taskboard_md_auto_export: bool = False
    taskboard_status_md_paths: str = "docs/STATUS.md,STATUS.md,docs/status.md"


settings = Settings()


def workspace_admin_emails() -> set[str]:
    return {e.strip().lower() for e in settings.workspace_admin_emails.split(",") if e.strip()}


def assert_secure_settings() -> None:
    """Falla al arrancar si el secreto JWT es el de desarrollo o demasiado corto."""
    secret = settings.jwt_secret or ""
    if secret == _DEV_JWT or len(secret) < 32:
        raise RuntimeError(
            "JWT_SECRET no configurado o demasiado corto (mínimo 32 caracteres). "
            "Genera uno con: openssl rand -base64 48"
        )
