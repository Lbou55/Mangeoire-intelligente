"""Cow profiles. Only the admin writes; admins and eleveurs of the farm read.

Mongo layout (as in Compass): _id = RFID tag, plus cow_id (COW001...), age_months,
birth_date, breed, type, weight_kg, admin_id, created_at.
"""
from datetime import date, datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from ..db import get_db
from ..deps import Principal, auth
from ..errors import conflict, not_found
from ..serializers import iso, months_between, now

router = APIRouter(prefix="/profiles", tags=["profiles"])

CowType = Literal["dairy", "beef", "dual"]


def norm(value: str) -> str:
    return value.strip().upper().replace(" ", "").replace(":", "")


def cow_json(doc: dict) -> dict:
    birth = doc.get("birth_date")
    age = doc.get("age_months")
    if isinstance(birth, datetime):
        age = months_between(birth)
        birth_s = birth.date().isoformat()
    else:
        birth_s = str(birth) if birth else None
    return {
        "cow_id": doc.get("cow_id"),
        "internal_id": doc.get("cow_id"),
        "nfc_uid": doc["_id"],
        "admin_id": str(doc["admin_id"]) if doc.get("admin_id") else None,
        "breed": doc.get("breed"),
        "type": doc.get("type"),
        "weight_kg": doc.get("weight_kg"),
        "birth_date": birth_s,
        "age_months": age,
        "created_at": iso(doc.get("created_at")),
    }


def _birth_dt(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, tzinfo=timezone.utc)


class CowIn(BaseModel):
    cow_id: str = Field(min_length=2, max_length=20)
    nfc_uid: str | None = Field(default=None, max_length=40)
    birth_date: date
    weight_kg: float = Field(gt=0, lt=2000)
    type: CowType
    breed: str = Field(min_length=2, max_length=40)


class CowUpdate(BaseModel):
    birth_date: date
    weight_kg: float = Field(gt=0, lt=2000)
    type: CowType
    breed: str = Field(min_length=2, max_length=40)
    nfc_uid: str | None = Field(default=None, max_length=40)
    clear_nfc: bool = False


async def farm_cow(p: Principal, cow_id: str) -> dict:
    """Cow of the caller's farm by cow_id (or tag); 404 otherwise."""
    key = norm(cow_id)
    doc = await get_db().cow_profiles.find_one(
        {"admin_id": p.farm_admin["_id"], "$or": [{"cow_id": key}, {"_id": key}]}
    )
    if doc is None:
        raise not_found("cow_not_found", "Vache introuvable")
    return doc


@router.get("")
async def list_profiles(p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    cursor = get_db().cow_profiles.find({"admin_id": p.farm_admin["_id"]}).sort("cow_id", 1)
    return [cow_json(c) for c in await cursor.to_list()]


@router.get("/by-nfc/{uid}")
async def by_nfc(uid: str, p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    doc = await get_db().cow_profiles.find_one(
        {"admin_id": p.farm_admin["_id"], "_id": norm(uid)}
    )
    if doc is None:
        raise not_found("tag_unknown", "Tag inconnu")
    return cow_json(doc)


@router.get("/{cow_id}")
async def get_profile(cow_id: str, p: Principal = Depends(auth("admin", "eleveur", farm=True))):
    return cow_json(await farm_cow(p, cow_id))


@router.post("", status_code=201)
async def create_profile(body: CowIn, p: Principal = Depends(auth("admin", farm=True))):
    db = get_db()
    cow_id = norm(body.cow_id)
    tag = norm(body.nfc_uid) if body.nfc_uid else cow_id
    if await db.cow_profiles.find_one({"$or": [{"cow_id": cow_id}, {"_id": tag}]}):
        raise conflict("cow_exists", "Cette vache ou ce tag existe déjà")
    birth = _birth_dt(body.birth_date)
    doc = {
        "_id": tag,
        "cow_id": cow_id,
        "age_months": months_between(birth),
        "birth_date": birth,
        "breed": body.breed.strip(),
        "type": body.type,
        "weight_kg": round(body.weight_kg, 1),
        "admin_id": p.doc["_id"],
        "created_at": now(),
    }
    await db.cow_profiles.insert_one(doc)
    return cow_json(doc)


@router.put("/{cow_id}")
async def update_profile(
    cow_id: str, body: CowUpdate, p: Principal = Depends(auth("admin", farm=True))
):
    db = get_db()
    cow = await farm_cow(p, cow_id)
    birth = _birth_dt(body.birth_date)
    fields = {
        "birth_date": birth,
        "age_months": months_between(birth),
        "weight_kg": round(body.weight_kg, 1),
        "type": body.type,
        "breed": body.breed.strip(),
    }

    new_tag = cow["_id"]
    if body.clear_nfc:
        new_tag = cow["cow_id"]
    elif body.nfc_uid:
        new_tag = norm(body.nfc_uid)

    if new_tag == cow["_id"]:
        await db.cow_profiles.update_one({"_id": cow["_id"]}, {"$set": fields})
        cow.update(fields)
        return cow_json(cow)

    # _id is immutable in Mongo: moving a cow to another tag = insert + delete
    if await db.cow_profiles.find_one({"_id": new_tag}):
        raise conflict("tag_taken", "Ce tag est déjà utilisé")
    moved = {**cow, **fields, "_id": new_tag}
    await db.cow_profiles.insert_one(moved)
    await db.cow_profiles.delete_one({"_id": cow["_id"]})
    return cow_json(moved)


@router.delete("/{cow_id}")
async def delete_profile(cow_id: str, p: Principal = Depends(auth("admin", farm=True))):
    cow = await farm_cow(p, cow_id)
    await get_db().cow_profiles.delete_one({"_id": cow["_id"]})
    return {"ok": True}
