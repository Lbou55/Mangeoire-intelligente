"""WebSocket hub: pushes live events to connected apps.

Each connection is tagged with the admin it belongs to (an admin, or the
eleveurs of that admin), so a farm only receives its own events.
"""
from fastapi import WebSocket


class Hub:
    def __init__(self) -> None:
        self.clients: dict[WebSocket, str] = {}

    def add(self, ws: WebSocket, admin_id: str) -> None:
        self.clients[ws] = admin_id

    def remove(self, ws: WebSocket) -> None:
        self.clients.pop(ws, None)

    async def broadcast(self, admin_id: str | None, message: dict) -> None:
        for ws, owner in list(self.clients.items()):
            if admin_id is not None and owner != admin_id:
                continue
            try:
                await ws.send_json(message)
            except Exception:  # noqa: BLE001
                self.remove(ws)


hub = Hub()
