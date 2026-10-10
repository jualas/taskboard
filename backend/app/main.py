from contextlib import asynccontextmanager
import asyncio
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import assert_secure_settings, settings
from .db import close_pool
from .routers import ai, auth, meta, projects, tasks, users
from .workspace_sync import workspace_sync_loop

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    assert_secure_settings()
    stop_event = asyncio.Event()
    sync_task: asyncio.Task | None = None
    if settings.workspace_snapshot_enabled:
        sync_task = asyncio.create_task(workspace_sync_loop(stop_event))
    yield
    stop_event.set()
    if sync_task is not None:
        sync_task.cancel()
        try:
            await sync_task
        except asyncio.CancelledError:
            pass
    await close_pool()


def _cors_origins() -> list[str]:
    raw = settings.cors_origins.strip()
    if raw == "*":
        return ["*"]
    return [o.strip() for o in raw.split(",") if o.strip()]


app = FastAPI(
    title="TaskBoard API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.enable_docs else None,
    redoc_url="/redoc" if settings.enable_docs else None,
    openapi_url="/openapi.json" if settings.enable_docs else None,
)
_origins = _cors_origins()
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials="*" not in _origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(projects.router)
app.include_router(meta.router)
app.include_router(users.router)
app.include_router(tasks.router)
app.include_router(ai.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
