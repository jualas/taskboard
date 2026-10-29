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

    # Correos (separados por coma) que pueden usar carpetas del servidor y Claude Code.
    # Vacío = nadie: el asistente usa solo DeepSeek/Ollama sin acceso a disco.
    workspace_admin_emails: str = ""

    # Motor de «Sugerir con IA» y del chat: auto (orden agent → deepseek → ollama), deepseek,
    # ollama o agent. El modo Agent del panel (/api/ai/agent-stream) no depende de este valor.
    ai_engine: str = "auto"

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
    # Tope de tokens de salida por llamada (coste acotado).
    deepseek_max_tokens: int = 4096
    deepseek_max_tokens_plan: int = 8192

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

    # Claude Code (`claude -p`) en el mini PC: modo Agent del panel (seguimiento y desarrollo
    # sobre el repo del proyecto) y motor «agent» de AI_ENGINE. Solo administradores de workspace.
    claude_code_enabled: bool = False
    claude_code_bin: str = "claude"
    # HOME propio y persistente (sesiones para --resume), sin la configuración del usuario.
    claude_code_home: str = ""
    # Token de `claude setup-token`; solo en el .env del API.
    claude_code_oauth_token: str = ""
    claude_code_model: str = ""
    claude_code_default_workspace: str = "/mnt/datos/Proyectos/taskboard"
    claude_code_timeout_sec: float = 1800.0
    claude_code_max_turns: int = 60
    # Gasto máximo por ejecución (0 = sin tope).
    claude_code_max_budget_usd: float = 3.0
    # MCP de TaskBoard dentro del contenedor, contra el propio API y con un JWT corto del usuario.
    claude_code_mcp_server: str = "/opt/mcp-taskboard/server.py"
    claude_code_mcp_api_url: str = "http://127.0.0.1:8000"
    claude_code_token_minutes: int = 60
    claude_code_git_name: str = "Claude Code (TaskBoard)"
    claude_code_git_email: str = "claude-code@taskboard.invalid"
    # Si true, cuando el motor «agent» falla en suggest/chat se usa DeepSeek u Ollama.
    agent_fallback_llm: bool = False

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
