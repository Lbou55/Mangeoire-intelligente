
from datetime import datetime, timezone

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException
from pymongo.errors import DuplicateKeyError

from .. import db as database
from ..schemas import FarmerIn, FarmerUpdate, PasswordResetIn, VetSettingsIn
from ..security import hash_password, owner_only, public_user, current_user

router = APIRouter(tags=["users"])


def _oid(value: str) -> ObjectId:
    try:
        return ObjectId(value)
    except InvalidId:
        raise HTTPException(404, "Utilisateur introuvable")


@router.get("/users")
async def list_users(_: dict = Depends(owner_only)):
    cur = database.db.users.find(
        {"active": {"$ne": False}}
    ).sort("created_at", 1)

    return [
        public_user(u)
        for u in await cur.to_list(length=200)
    ]


@router.post("/users", status_code=201)
async def create_farmer(
    body: FarmerIn,
    _: dict = Depends(owner_only),
):
    doc = {
        "name": body.name.strip(),
        "email": body.email.lower(),
        "role": "farmer",
        "active": True,
        "address": body.address.strip(),
        "password_hash": hash_password(body.password),
        "created_at": datetime.now(timezone.utc),
    }

    try:
        res = await database.db.users.insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(409, "Cette adresse e-mail est déjà utilisée")

    doc["_id"] = res.inserted_id

    return public_user(doc)


@router.put("/users/{user_id}")
async def update_farmer(
    user_id: str,
    body: FarmerUpdate,
    _: dict = Depends(owner_only),
):
    res = await database.db.users.update_one(
        {
            "_id": _oid(user_id),
            "role": "farmer",
            "active": {"$ne": False},
        },
        {
            "$set": {
                "address": body.address.strip(),
            }
        },
    )

    if res.matched_count == 0:
        raise HTTPException(404, "Agriculteur introuvable")

    return {"ok": True}


@router.put("/users/{user_id}/password")
async def reset_password(
    user_id: str,
    body: PasswordResetIn,
    _: dict = Depends(owner_only),
):
    res = await database.db.users.update_one(
        {
            "_id": _oid(user_id),
            "role": "farmer",
            "active": {"$ne": False},
        },
        {
            "$set": {
                "password_hash": hash_password(body.new_password),
            }
        },
    )

    if res.matched_count == 0:
        raise HTTPException(404, "Agriculteur introuvable")

    return {"ok": True}


@router.delete("/users/{user_id}")
async def deactivate_farmer(
    user_id: str,
    owner: dict = Depends(owner_only),
):
    oid = _oid(user_id)

    if oid == owner["_id"]:
        raise HTTPException(
            400,
            "Vous ne pouvez pas supprimer votre propre compte",
        )

    res = await database.db.users.update_one(
        {
            "_id": oid,
            "role": "farmer",
        },
        {
            "$set": {
                "active": False,
            }
        },
    )

    if res.matched_count == 0:
        raise HTTPException(404, "Agriculteur introuvable")

    return {"ok": True}


# ---- farm settings (vet phone number) ----

@router.get("/settings")
async def get_settings(user: dict = Depends(current_user)):
    doc = await database.db.settings.find_one({"_id": "farm"}) or {}

    return {
        "vet_phone": doc.get("vet_phone", "")
        if user["role"] == "owner"
        else ""
    }


@router.put("/settings/vet")
async def set_vet_phone(
    body: VetSettingsIn,
    _: dict = Depends(owner_only),
):
    await database.db.settings.update_one(
        {"_id": "farm"},
        {
            "$set": {
                "vet_phone": body.vet_phone.strip(),
            }
        },
        upsert=True,
    )

    return {"ok": True}
