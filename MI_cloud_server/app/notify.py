"""Create notifications in MongoDB and push them live to connected apps (WebSocket)."""
import json
import logging
from datetime import datetime, timezone

from fastapi import WebSocket

from . import db as database

log = logging.getLogger("notify")


def iso(d):
    if d is None:
        return None
    if isinstance(d, datetime):
        if d.tzinfo is None:
            d = d.replace(tzinfo=timezone.utc)
        return d.isoformat()
    return d


def notif_out(n: dict) -> dict:
    return {
        "id": str(n["_id"]),
        "type": n["type"],
        "title": n["title"],
        "body": n["body"],
        "cow_id": n.get("cow_id"),
        "report_id": n.get("report_id"),
        "needs_vet": n.get("needs_vet", False),
        "created_at": iso(n["created_at"]),
        "read_at": iso(n.get("read_at")),
    }


class UserHub:
    """user_id -> open WebSockets (one person can have phone + Edge open)."""

    def __init__(self):
        self.sockets: dict[str, set[WebSocket]] = {}

    def add(self, user_id: str, ws: WebSocket):
        self.sockets.setdefault(user_id, set()).add(ws)

    def remove(self, user_id: str, ws: WebSocket):
        self.sockets.get(user_id, set()).discard(ws)

    async def send(self, user_id: str, message: dict):
        dead = []
        for ws in list(self.sockets.get(user_id, ())):
            try:
                await ws.send_text(json.dumps(message))
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.remove(user_id, ws)


hub = UserHub()


async def notify(user_ids: list[str], *, type: str, title: str, body: str,
                 cow_id: str | None = None, report_id: str | None = None,
                 needs_vet: bool = False) -> None:
    for uid in user_ids:
        doc = {
            "user_id": uid, "type": type, "title": title, "body": body,
            "cow_id": cow_id, "report_id": report_id, "needs_vet": needs_vet,
            "created_at": datetime.now(timezone.utc), "read_at": None,
        }
        res = await database.db.notifications.insert_one(doc)
        doc["_id"] = res.inserted_id
        try:
            await hub.send(uid, {"type": "notification", "notification": notif_out(doc)})
        except Exception:
            log.exception("live push failed (the notification is saved anyway)")
