"""El sync automático no toca proyectos completados ni archivados."""

import asyncio

from app import workspace_sync


class FakeConn:
    def __init__(self, projects):
        self.projects = projects
        self.sql = ""

    async def fetch(self, sql, *args):
        self.sql = sql
        # Emula el filtro SQL sobre la lista en memoria
        return [
            {"id": p["id"]}
            for p in self.projects
            if p["workspace_path"].strip() and p["status"] not in ("completed", "archived")
        ]


def test_sync_ignora_proyectos_cerrados(monkeypatch):
    synced = []

    async def fake_sync(conn, project_id):
        synced.append(project_id)
        return {"project_id": project_id}

    monkeypatch.setattr(workspace_sync, "sync_project_workspace", fake_sync)
    conn = FakeConn(
        [
            {"id": 1, "status": "development", "workspace_path": "/repo/a"},
            {"id": 2, "status": "completed", "workspace_path": "/repo/b"},
            {"id": 3, "status": "archived", "workspace_path": "/repo/c"},
            {"id": 4, "status": "planning", "workspace_path": "/repo/d"},
        ]
    )
    result = asyncio.run(workspace_sync.sync_all_projects_with_workspace(conn))

    assert "status not in ('completed', 'archived')" in conn.sql
    assert synced == [1, 4]
    assert result["projects_checked"] == 2
