from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    email: str
    password: str


class RegisterRequest(BaseModel):
    email: str
    password: str
    display_name: str | None = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class UserPublic(BaseModel):
    id: UUID
    email: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic


class ProjectCreate(BaseModel):
    title: str = ""
    description: str = ""
    status: str = "planning"


class ProjectPatch(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None


class ProjectOut(BaseModel):
    id: int
    title: str
    description: str
    status: str
    owner_id: UUID
    created_at: datetime
    updated_at: datetime
    current_user_role: str | None = None


class AppUserOut(BaseModel):
    user_id: str
    email: str


class MemberCreate(BaseModel):
    user_id: UUID
    role: str = "viewer"


class MemberPatch(BaseModel):
    role: str


class ProjectMemberOut(BaseModel):
    project_id: int
    user_id: str
    role: str
    created_at: datetime


class TaskIn(BaseModel):
    id: int
    project_id: int
    title: str = ""
    description: str = ""
    status: str = "pending"
    due_date: datetime | None = None
    kanban_position: float = 1.0
    estimated_hours: int | None = None
    complexity: str = "simple"
    tags: list[str] = Field(default_factory=list)
    subtasks: list[dict[str, Any]] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class AiSuggestBody(BaseModel):
    userMessage: str = Field(alias="userMessage")
    projectContext: dict[str, Any] | None = None

    model_config = {"populate_by_name": True}
