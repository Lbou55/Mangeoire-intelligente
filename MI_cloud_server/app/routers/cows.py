from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from pymongo.errors import DuplicateKeyError

from .. import db as database
from ..config import settings
from ..logic import LEVELS, level_from_ai
from ..notify import iso
from ..schemas import CowIn, CowUpdate, StatusIn
from ..security import current_user, service_only

router = APIRouter(tags=["cows"])
ORDER = {"danger": 0, "alerte": 1, "normal": 2}


def _events():
    return database.db[settings.mongo_collection]


async def _latest(tag: str) -> dict | None:
    return await _events().find_one(
        {"cow_id": tag},
        {"_id": 0},
        sort=[("date", -1)],
    )


def cow_out(c: dict, latest: dict | None = None) -> dict:
    return {
        "id": c.get("display_id", ""),
        "display_id": c.get("display_id", ""),
        "tag": c["_id"],
        "name": c.get("name", ""),
        "type": c.get("type", "laitiere"),
        "age_months": c.get("age_months"),
        "status": c.get("status", "normal"),
        "p_flagged": c.get("p_flagged"),
        "category": c.get("category"),
        "status_at": iso(c.get("status_at")),
        "archived": c.get("archived", False),
        "created_by": c.get("created_by_name", ""),
        "latest": latest,
    }


async def _get_cow(tag: str) -> dict:
    cow = await database.db.cows.find_one(
        {"_id": tag.strip().upper()}
    )
    if cow is None:
        raise HTTPException(404, "Vache introuvable")
    return cow


@router.get("/cows")
async def list_cows(
    q: str = "",
    status: str | None = None,
    archived: bool = False,
    _: dict = Depends(current_user),
):
    query: dict = {"archived": {"$ne": True}} if not archived else {}

    if status:
        if status not in LEVELS:
            raise HTTPException(400, "statut inconnu")
        query["status"] = status

    cows = await database.db.cows.find(query).to_list(length=1000)

    q = q.strip().lower()
    if q:
        cows = [
            c for c in cows
            if q in c.get("display_id", "").lower()
            or q in (c.get("name") or "").lower()
        ]

    cows.sort(
        key=lambda c: (
            ORDER.get(c.get("status", "normal"), 2),
            c.get("display_id", ""),
        )
    )

    return [
        cow_out(c, await _latest(c["_id"]))
        for c in cows
    ]


@router.post("/cows", status_code=201)
async def add_cow(body: CowIn, user: dict = Depends(current_user)):
    """Owner and farmers can add cows."""

    tag = body.tag.strip().upper()

    doc = {
        "_id": tag,
        "display_id": await database.next_cow_display_id(),
        "name": body.name.strip(),
        "type": body.type,
        "age_months": body.age_months,
        "status": "normal",
        "archived": False,
        "created_by": str(user["_id"]),
        "created_by_name": user["name"],
        "created_at": datetime.now(timezone.utc),
    }

    try:
        await database.db.cows.insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(409, "Ce tag RFID existe déjà")

    return cow_out(doc)


@router.get("/cows/{tag}")
async def get_cow(tag: str, _: dict = Depends(current_user)):
    cow = await _get_cow(tag)
    return cow_out(cow, await _latest(cow["_id"]))


@router.put("/cows/{tag}")
async def update_cow(
    tag: str,
    body: CowUpdate,
    _: dict = Depends(current_user),
):
    cow = await _get_cow(tag)
    changes = body.model_dump(exclude_none=True)

    if "name" in changes:
        changes["name"] = changes["name"].strip()

    if changes:
        await database.db.cows.update_one(
            {"_id": cow["_id"]},
            {"$set": changes},
        )
        cow.update(changes)

    return cow_out(cow, await _latest(cow["_id"]))


@router.get("/cows/{tag}/history")
async def history(
    tag: str,
    days: int = Query(7, ge=1, le=60),
    _: dict = Depends(current_user),
):
    cow = await _get_cow(tag)
    cur = (
        _events()
        .find({"cow_id": cow["_id"]}, {"_id": 0})
        .sort("date", -1)
        .limit(days)
    )
    rows = await cur.to_list(length=days)
    rows.reverse()
    return rows


@router.put("/cows/{tag}/status", dependencies=[Depends(service_only)])
async def set_status(tag: str, body: StatusIn):
    """Called by the Pi / Node-RED using X-Service-Key."""

    cow = await _get_cow(tag)

    if body.status is not None:
        level = body.status
    elif body.alert is not None:
        level = level_from_ai(
            body.alert,
            body.p_flagged,
            settings.danger_threshold,
        )
    else:
        raise HTTPException(400, "envoyez 'status' ou 'alert'")

    await database.db.cows.update_one(
        {"_id": cow["_id"]},
        {
            "$set": {
                "status": level,
                "p_flagged": body.p_flagged,
                "category": body.category,
                "status_at": datetime.now(timezone.utc),
            }
        },
    )

    return {
        "id": cow.get("display_id", ""),
        "status": level,
    }