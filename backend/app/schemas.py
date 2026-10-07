from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


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
    workspace_path: str = ""


class ProjectPatch(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None
    workspace_path: str | None = None


class ProjectOut(BaseModel):
    id: int
    title: str
    description: str
    status: str
    workspace_path: str = ""
    owner_id: UUID
    created_at: datetime
    updated_at: datetime
    current_user_role: str | None = None
    pending_workspace_suggestions: int = 0


class WorkspaceSnapshotOut(BaseModel):
    id: int
    project_id: int
    git_commit: str | None = None
    git_branch: str | None = None
    dirty_count: int = 0
    summary: str = ""
    created_at: datetime


class WorkspaceSuggestionOut(BaseModel):
    id: int
    project_id: int
    snapshot_id: int | None = None
    suggestion_type: str
    title: str
    body: str = ""
    payload: dict[str, Any] = Field(default_factory=dict)
    state: str = "pending"
    created_at: datetime


class WorkspacePathBody(BaseModel):
    path: str = ""


class WorkspaceInventoryEntry(BaseModel):
    path: str
    name: str
    root: str
    root_path: str = ""
    has_git: bool = False
    has_docker_compose: bool = False
    linked_project_id: int | None = None
    linked_project_title: str | None = None


class WorkspaceOrphanProject(BaseModel):
    project_id: int
    project_title: str
    workspace_path: str


class WorkspaceInventoryOut(BaseModel):
    entries: list[WorkspaceInventoryEntry] = Field(default_factory=list)
    orphan_projects: list[WorkspaceOrphanProject] = Field(default_factory=list)
    total: int = 0
    linked: int = 0
    unlinked: int = 0


class AiChatMessage(BaseModel):
    role: str
    content: str


class AiChatBody(BaseModel):
    projectContext: dict[str, Any] | None = None
    project_id: int | None = Field(default=None, alias="projectId")
    messages: list[AiChatMessage] = Field(default_factory=list)
    draftTasks: list[dict[str, Any]] = Field(default_factory=list)

    model_config = {"populate_by_name": True}


class AiAgentStreamBody(BaseModel):
    project_id: int | None = Field(default=None, alias="projectId")
    prompt: str = ""
    execute: bool = False
    continue_session: bool = Field(default=True, alias="continueSession")
    new_session: bool = Field(default=False, alias="newSession")
    project_context: dict[str, Any] | None = Field(default=None, alias="projectContext")

    model_config = {"populate_by_name": True}


class AgentSessionOut(BaseModel):
    project_id: int
    session_id: str
    workspace_path: str = ""
    updated_at: datetime


class AgentRunOut(BaseModel):
    id: int
    project_id: int
    session_id: str | None = None
    prompt: str
    execute_mode: bool = False
    result_preview: str = ""
    is_error: bool = False
    created_at: datetime


class TaskboardMdExportBody(BaseModel):
    filename: str = ""
    dry_run: bool = Field(default=False, alias="dryRun")

    model_config = {"populate_by_name": True}


class TaskboardMdOut(BaseModel):
    project_id: int
    workspace_path: str
    file_path: str
    filename: str
    content: str
    written: bool
    task_count: int
    git_commit: str | None = None
    git_branch: str | None = None


class IdePromptOut(BaseModel):
    project_id: int
    project_title: str
    workspace_path: str
    taskboard_md: str
    status_md_paths: list[str]
    file_references: list[str]
    focus_task_id: int | None = None
    focus_task_title: str | None = None
    prompt: str
    task_counts: dict[str, int]


class IdeSessionOut(BaseModel):
    export: TaskboardMdOut
    ide_prompt: IdePromptOut


class AiSuggestBody(BaseModel):
    userMessage: str = Field(alias="userMessage")
    projectContext: dict[str, Any] | None = None
    project_plan: bool = Field(
        default=False,
        alias="projectPlan",
        description="Backlog inicial con muchas tareas (plan de proyecto ágil).",
    )

    model_config = {"populate_by_name": True}


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


_COMPLEXITY_ALIASES = {
    "low": "simple", "small": "simple", "easy": "simple", "baja": "simple", "simple": "simple",
    "media": "medium", "medio": "medium", "moderate": "medium", "medium": "medium",
    "high": "complex", "large": "complex", "hard": "complex", "alta": "complex",
    "compleja": "complex", "complejo": "complex", "complex": "complex",
}


class TaskIn(BaseModel):
    id: int
    project_id: int
    title: str = ""
    description: str = ""
    status: str = "pending"
    due_date: datetime | None = None
    kanban_position: float = 1.0
    estimated_hours: int | None = None
    complexity: Literal["simple", "medium", "complex"] = "simple"
    tags: list[str] = Field(default_factory=list)
    subtasks: list[dict[str, Any]] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    @field_validator("complexity", mode="before")
    @classmethod
    def _normalize_complexity(cls, v: Any) -> Any:
        # Los agentes IA a veces envían sinónimos («media», «high»…); el cliente
        # solo admite estos tres valores y uno desconocido rompía el tablero.
        if isinstance(v, str):
            v = v.strip().lower()
            return _COMPLEXITY_ALIASES.get(v, v)
        return v

