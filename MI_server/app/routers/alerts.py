from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from ..db import get_db
from ..deps import Principal, auth
from ..errors import not_found
from ..hub import hub
from ..serializers import clean, now, to_oid
from .profiles import farm_cow

router = APIRouter(prefix="/alerts", tags=["alerts"])


def alert_json(a: dict) -> dict:
    out = {
        "id": str(a["_id"]),
        "source": a.get("source"),
        "type": a.get("type"),
        "severity": a.get("severity", "info"),
        "message": a.get("message", ""),
        "cow_id": a.get("cow_id"),
        "admin_id": str(a["admin_id"]) if a.get("admin_id") else None,
        "action": a.get("action"),
        "status": a.get("status", "unread"),
        "created_at": a.get("created_at"),
        "read_at": a.get("read_at"),
    }
    if a.get("appetite_class"):
        out["appetite_class"] = a["appetite_class"]
        out["appetite_pct"] = a.get("appetite_pct")
    return clean(out)


class AlertIn(BaseModel):
    message: str = Field(min_length=1, max_length=500)
    severity: Literal["info", "warning", "critical"] = "info"
    cow_id: str | None = Field(default=None, max_length=20)
    action: Literal["sell", "vet", "butcher"] | None = None


@router.post("", status_code=201)
async def create_alert(body: AlertIn, p: Principal = Depends(auth("admin", farm=True))):
    cow_id = None
    if body.cow_id:
        cow_id = (await farm_cow(p, body.cow_id))["cow_id"]
    doc = {
        "source": "admin",
        "type": "custom_message",
        "severity": body.severity,
        "message": body.message.strip(),
        "cow_id": cow_id,
        "admin_id": p.doc["_id"],
        "action": body.action,
        "status": "unread",
        "created_at": now(),
        "read_at": None,
    }
    res = await get_db().alerts.insert_one(doc)
    doc["_id"] = res.inserted_id
    out = alert_json(doc)
    await hub.broadcast(str(p.doc["_id"]), {"type": "alert", "alert": out})
    return out


@router.get("")
async def list_alerts(
    status: Literal["read", "unread"] | None = None,
    limit: int = Query(50, ge=1, le=200),
    p: Principal = Depends(auth("admin", "eleveur", farm=True)),
):
    query: dict = {"admin_id": p.farm_admin["_id"]}
    if status:
        query["status"] = status
    cursor = get_db().alerts.find(query).sort("created_at", -1).limit(limit)
    return [alert_json(a) for a in await cursor.to_list()]


@router.get("/unread-count")
async def unread_count(p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    n = await get_db().alerts.count_documents(
        {"admin_id": p.farm_admin["_id"], "status": "unread"}
    )
    return {"count": n}


@router.patch("/{alert_id}/read")
async def mark_read(alert_id: str, p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    res = await get_db().alerts.update_one(
        {"_id": to_oid(alert_id), "admin_id": p.farm_admin["_id"]},
        {"$set": {"status": "read", "read_at": now()}},
    )
    if res.matched_count == 0:
        raise not_found()
    return {"ok": True}
