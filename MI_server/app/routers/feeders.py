from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Header, Request
from pydantic import BaseModel, Field

from ..config import get_settings
from ..db import get_db
from ..deps import Principal, auth
from ..errors import bad_request, conflict, not_found, unauthorized
from ..hub import hub
from ..serializers import iso, now

router = APIRouter(prefix="/feeders", tags=["feeders"])


def feeder_status(pct: float) -> str:
    if pct >= 50:
        return "ok"
    if pct >= 20:
        return "low"
    return "critical"


def feeder_json(doc: dict) -> dict:
    capacity = float(doc.get("capacity_g") or 0)
    current = float(doc.get("current_quantity_g") or 0)
    pct = round(max(0.0, min(100.0, (current / capacity * 100) if capacity > 0 else 0.0)), 1)

    stored_online = doc.get("online") is True
    last_seen = doc.get("last_seen_at")
    online = False
    if stored_online and isinstance(last_seen, datetime):
        if last_seen.tzinfo is None:
            last_seen = last_seen.replace(tzinfo=timezone.utc)
        online = (now() - last_seen.astimezone(timezone.utc)).total_seconds() <= 300

    return {
        "id": doc["_id"],
        "farm_id": doc.get("farm_id"),
        "admin_id": str(doc["admin_id"]) if doc.get("admin_id") else None,
        "name": doc.get("name", ""),
        "capacity_g": int(capacity),
        "current_quantity_g": int(current),
        "level_pct": pct,
        "last_refill_at": iso(doc.get("last_refill_at")),
        "online": online,
        "last_seen_at": iso(last_seen),
        "status": feeder_status(pct),
    }


async def farm_feeder(p: Principal, feeder_id: str) -> dict:
    doc = await get_db().feeders.find_one(
        {"_id": feeder_id, "admin_id": p.farm_admin["_id"]}
    )
    if doc is None:
        raise not_found("feeder_not_found", "Mangeoire introuvable")
    return doc


class FeederIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    capacity_g: float = Field(gt=0)
    current_quantity_g: float = Field(default=0, ge=0)
    id: str | None = Field(default=None, max_length=100)


class FeederUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    capacity_g: float | None = Field(default=None, gt=0)


class FeederRefill(BaseModel):
    quantity_g: float | None = Field(default=None, gt=0)


class FeederIngest(BaseModel):
    feeder_id: str = Field(min_length=1, max_length=100)
    current_quantity_g: float = Field(ge=0)
    online: bool | None = None


@router.get("")
async def list_feeders(p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    cursor = get_db().feeders.find({"admin_id": p.farm_admin["_id"]}).sort("name", 1)
    return [feeder_json(doc) for doc in await cursor.to_list()]


@router.get("/{feeder_id}")
async def get_feeder(
    feeder_id: str, p: Principal = Depends(auth("admin", "eleveur", farm=True))
):
    return feeder_json(await farm_feeder(p, feeder_id))


@router.post("", status_code=201)
async def create_feeder(body: FeederIn, p: Principal = Depends(auth("admin", farm=True))):
    db = get_db()
    feeder_id = body.id.strip() if body.id else None
    if feeder_id and await db.feeders.find_one({"_id": feeder_id}):
        raise conflict("feeder_exists", "Cette mangeoire existe déjà")

    if feeder_id is None:
        docs = await db.feeders.find({}, {"_id": 1}).to_list(length=None)
        max_n = 0
        for doc in docs:
            raw = str(doc["_id"])
            if raw.startswith("feeder-"):
                try:
                    max_n = max(max_n, int(raw.split("-", 1)[1]))
                except (ValueError, IndexError):
                    pass
        feeder_id = f"feeder-{max_n + 1:03d}"

    capacity = round(body.capacity_g)
    current = round(body.current_quantity_g)
    if current > capacity:
        raise bad_request("invalid_quantity", "La quantité ne peut pas dépasser la capacité")

    doc = {
        "_id": feeder_id,
        "farm_id": "farm-001",
        "admin_id": p.doc["_id"],
        "name": body.name.strip(),
        "capacity_g": capacity,
        "current_quantity_g": current,
        "last_refill_at": None,
        "online": False,
        "last_seen_at": None,
    }
    await db.feeders.insert_one(doc)
    return feeder_json(doc)


@router.put("/{feeder_id}")
async def update_feeder(
    feeder_id: str,
    body: FeederUpdate,
    p: Principal = Depends(auth("admin", farm=True)),
):
    db = get_db()
    feeder = await farm_feeder(p, feeder_id)
    capacity = round(body.capacity_g) if body.capacity_g is not None else feeder["capacity_g"]
    current = feeder.get("current_quantity_g", 0)
    if current > capacity:
        raise bad_request("invalid_quantity", "La quantité ne peut pas dépasser la capacité")
    fields = {"capacity_g": capacity}
    if body.name is not None:
        fields["name"] = body.name.strip()
    await db.feeders.update_one({"_id": feeder_id}, {"$set": fields})
    feeder.update(fields)
    return feeder_json(feeder)


@router.delete("/{feeder_id}")
async def delete_feeder(
    feeder_id: str, p: Principal = Depends(auth("admin", farm=True))
):
    feeder = await farm_feeder(p, feeder_id)
    await get_db().feeders.delete_one({"_id": feeder["_id"]})
    return {"ok": True}


@router.post("/{feeder_id}/refill")
async def refill_feeder(
    feeder_id: str,
    body: FeederRefill,
    p: Principal = Depends(auth("admin", farm=True)),
):
    feeder = await farm_feeder(p, feeder_id)
    capacity = int(feeder["capacity_g"])
    if body.quantity_g is None:
        current = capacity
    else:
        current = min(capacity, int(feeder.get("current_quantity_g", 0) + round(body.quantity_g)))
    refill_at = now()
    await get_db().feeders.update_one(
        {"_id": feeder_id},
        {"$set": {"current_quantity_g": current, "last_refill_at": refill_at}},
    )
    feeder.update({"current_quantity_g": current, "last_refill_at": refill_at})
    return feeder_json(feeder)


ingest_router = APIRouter(tags=["ingest"])


@ingest_router.post("/ingest/feeder")
async def ingest_feeder(
    body: FeederIngest,
    request: Request,
    x_ingest_key: str | None = Header(default=None),
):
    key = get_settings().ingest_key
    if not key or x_ingest_key != key:
        raise unauthorized("invalid_ingest_key", "Clé d'ingestion invalide")

    db = get_db()
    feeder = await db.feeders.find_one({"_id": body.feeder_id})
    if feeder is None:
        raise not_found("feeder_not_found", "Mangeoire introuvable")

    capacity = int(feeder["capacity_g"])
    current = min(capacity, max(0, round(body.current_quantity_g)))
    old_pct = round(max(0.0, min(100.0, int(feeder.get("current_quantity_g", 0)) / capacity * 100)), 1)
    new_pct = round(max(0.0, min(100.0, current / capacity * 100)), 1)
    timestamp = now()

    await db.feeders.update_one(
        {"_id": body.feeder_id},
        {"$set": {
            "current_quantity_g": current,
            "online": body.online if body.online is not None else True,
            "last_seen_at": timestamp,
        }},
    )
    feeder.update({
        "current_quantity_g": current,
        "online": body.online if body.online is not None else True,
        "last_seen_at": timestamp,
    })
    out = feeder_json(feeder)
    await hub.broadcast(str(feeder["admin_id"]), {"type": "feeder", "feeder": out})

    if old_pct >= 20 and new_pct < 20:
        alert = {
            "source": "hardware",
            "type": "custom_message",
            "severity": "warning",
            "message": f"Niveau bas de la mangeoire {feeder.get('name', '')} ({int(new_pct)} %)",
            "cow_id": None,
            "admin_id": feeder["admin_id"],
            "action": None,
            "status": "unread",
            "created_at": timestamp,
            "read_at": None,
            "feeder_id": feeder["_id"],
        }
        res = await db.alerts.insert_one(alert)
        alert["_id"] = res.inserted_id
        from ..routers.alerts import alert_json  # noqa: PLC0415
        await hub.broadcast(str(feeder["admin_id"]), {
            "type": "alert",
            "alert": alert_json(alert),
        })

    return out
