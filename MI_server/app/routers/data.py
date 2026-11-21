"""Read-only measurements of the farm's cows (filled by the Raspberry Pi / ESP32)."""
from fastapi import APIRouter, Depends, Query

from ..db import get_db
from ..deps import Principal, auth
from ..errors import not_found
from ..serializers import clean
from .profiles import farm_cow

router = APIRouter(tags=["data"])
READER = Depends(auth("admin", "eleveur", farm=True))


def strip(doc: dict) -> dict:
    out = {k: v for k, v in doc.items() if k not in ("_id", "admin_id")}
    return clean(out)


@router.get("/cows")
async def cows_with_data(p: Principal = READER):
    cursor = get_db().cow_profiles.find({"admin_id": p.farm_admin["_id"]}).sort("cow_id", 1)
    return {"cows": [c["cow_id"] for c in await cursor.to_list()]}


@router.get("/latest/{cow_id}")
async def latest(cow_id: str, p: Principal = READER):
    cow = await farm_cow(p, cow_id)
    doc = await get_db().daily_summaries.find_one(
        {"cow_id": cow["cow_id"]}, sort=[("date", -1)]
    )
    if doc is None:
        raise not_found("no_data", "Aucune donnée")
    return strip(doc)


@router.get("/daily/{cow_id}")
async def daily(cow_id: str, limit: int = Query(30, ge=1, le=365), p: Principal = READER):
    cow = await farm_cow(p, cow_id)
    cursor = get_db().daily_summaries.find({"cow_id": cow["cow_id"]}).sort("date", -1).limit(limit)
    return [strip(d) for d in await cursor.to_list()]


@router.get("/realtime/{cow_id}")
async def realtime(cow_id: str, limit: int = Query(100, ge=1, le=1000), p: Principal = READER):
    cow = await farm_cow(p, cow_id)
    cursor = (
        get_db().realtime_readings.find({"cow_id": cow["cow_id"]}).sort("timestamp", -1).limit(limit)
    )
    return [strip(d) for d in await cursor.to_list()]


@router.get("/dispatch/{cow_id}")
async def dispatch(cow_id: str, limit: int = Query(30, ge=1, le=365), p: Principal = READER):
    cow = await farm_cow(p, cow_id)
    cursor = get_db().feed_dispatch.find({"cow_id": cow["cow_id"]}).sort("date", -1).limit(limit)
    return [strip(d) for d in await cursor.to_list()]


@router.get("/home/appetite")
async def home_appetite(p: Principal = READER):
    """Latest appetite class per cow: increasing | stable | decreasing | null."""
    db = get_db()
    result: dict = {}
    cursor = db.cow_profiles.find({"admin_id": p.farm_admin["_id"]}).sort("cow_id", 1)
    for cow in await cursor.to_list():
        d = await db.daily_summaries.find_one(
            {"cow_id": cow["cow_id"], "appetite_class": {"$ne": None}},
            sort=[("date", -1)],
        )
        result[cow["cow_id"]] = {
            "appetite": d.get("appetite_class") if d else None,
            "raw": d.get("appetite_raw") if d else None,
            "date": d.get("date") if d else None,
        }
    return {"appetite": clean(result)}
