"""Cliente HTTP mínimo para la API TaskBoard (MCP / scripts)."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


class TaskboardApiError(Exception):
    def __init__(self, status: int, detail: str) -> None:
        super().__init__(detail)
        self.status = status
        self.detail = detail


class TaskboardClient:
    def __init__(
        self,
        base_url: str,
        *,
        token: str | None = None,
        email: str | None = None,
        password: str | None = None,
        timeout: float = 60.0,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._token = (token or "").strip() or None
        self._email = (email or "").strip() or None
        self._password = password or ""

    @classmethod
    def from_env(cls, env_file: str | None = None) -> TaskboardClient:
        env_path = env_file or os.environ.get("TASKBOARD_ENV_FILE")
        if env_path:
            _load_env_file(Path(env_path))
        base = os.environ.get("TASKBOARD_API_URL") or os.environ.get("API_BASE_URL") or "http://127.0.0.1:8101"
        token = os.environ.get("TASKBOARD_API_TOKEN") or os.environ.get("API_BEARER_TOKEN")
        email = os.environ.get("TASKBOARD_EMAIL") or os.environ.get("API_AUTH_EMAIL")
        password = os.environ.get("TASKBOARD_PASSWORD") or os.environ.get("API_AUTH_PASSWORD")
        return cls(base, token=token, email=email, password=password)

    def _ensure_token(self) -> str:
        if self._token:
            return self._token
        if not self._email or not self._password:
            raise TaskboardApiError(
                401,
                "Falta autenticación: TASKBOARD_API_TOKEN o TASKBOARD_EMAIL+TASKBOARD_PASSWORD",
            )
        status, body = self._raw_request(
            "POST",
            "/auth/login",
            body=json.dumps({"email": self._email, "password": self._password}),
            auth=False,
        )
        if status >= 400:
            raise TaskboardApiError(status, body)
        data = json.loads(body)
        token = data.get("access_token")
        if not token:
            raise TaskboardApiError(401, "Login sin access_token")
        self._token = str(token)
        return self._token

    def _raw_request(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, str] | None = None,
        body: str | None = None,
        auth: bool = True,
    ) -> tuple[int, str]:
        url = f"{self.base_url}/{path.lstrip('/')}"
        if query:
            url = f"{url}?{urlencode(query)}"
        headers = {"Accept": "application/json"}
        if auth:
            headers["Authorization"] = f"Bearer {self._ensure_token()}"
        if body is not None:
            headers["Content-Type"] = "application/json"
        req = Request(url, data=body.encode("utf-8") if body is not None else None, headers=headers, method=method.upper())
        try:
            with urlopen(req, timeout=self.timeout) as resp:
                return resp.status, resp.read().decode("utf-8", errors="replace")
        except HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            return e.code, err_body
        except URLError as e:
            raise TaskboardApiError(0, f"No se pudo conectar con {url}: {e}") from e

    def request_json(
        self,
        method: str,
        path: str,
        *,
        query: dict[str, str] | None = None,
        body: dict[str, Any] | None = None,
    ) -> Any:
        payload = json.dumps(body) if body is not None else None
        status, text = self._raw_request(method, path, query=query, body=payload)
        if status >= 400:
            detail = text
            try:
                parsed = json.loads(text)
                if isinstance(parsed, dict) and parsed.get("detail"):
                    detail = str(parsed["detail"])
            except json.JSONDecodeError:
                pass
            raise TaskboardApiError(status, detail)
        if not text.strip():
            return None
        return json.loads(text)


def _load_env_file(path: Path) -> None:
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key and key not in os.environ:
            os.environ[key] = value.strip()
