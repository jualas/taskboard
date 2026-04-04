from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .db import close_pool
from .routers import ai, auth, meta, projects, tasks, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await close_pool()


def _cors_origins() -> list[str]:
    raw = settings.cors_origins.strip()
    if raw == "*":
        return ["*"]
    return [o.strip() for o in raw.split(",") if o.strip()]


app = FastAPI(title="TaskBoard API", version="1.0.0", lifespan=lifespan)
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
