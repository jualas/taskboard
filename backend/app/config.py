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

    allow_registration: bool = True
    cors_origins: str = "*"

    deepseek_api_key: str = ""
    deepseek_model: str = "deepseek-chat"
    deepseek_base_url: str = "https://api.deepseek.com"

    ollama_base_url: str = "http://127.0.0.1:11434"
    local_llm_model: str = "qwen2.5:3b-instruct-q4_K_M"


settings = Settings()
