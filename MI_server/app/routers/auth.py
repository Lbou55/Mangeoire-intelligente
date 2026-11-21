from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from ..db import get_db
from ..deps import Principal, auth, subscription_active
from ..errors import ApiError, bad_request, forbidden, subscription_expired, unauthorized
from ..security import (
    hash_password,
    keyed_hash,
    make_token,
    verify_password,
)
from ..serializers import iso, now
from .invites import extract_code

router = APIRouter(prefix="/auth", tags=["auth"])

ELEVEUR_TOKEN_DAYS = 365  # no password: the phone unlocks it with the fingerprint


def user_json(role: str, doc: dict) -> dict:
    out = {
        "id": str(doc["_id"]),
        "role": role,
        "name": doc.get("name", ""),
        "email": doc.get("email"),
        "phone": doc.get("phone"),
    }
    if role == "admin":
        out["must_change_password"] = bool(doc.get("must_change_password"))
        out["subscription_expires_at"] = iso(doc.get("subscription_expires_at"))
        out["subscription_active"] = subscription_active(doc)
        out["status"] = doc.get("status")
    if role == "superadmin":
        out["must_change_password"] = bool(doc.get("must_change_password"))
    if role == "eleveur":
        out["admin_id"] = str(doc.get("admin_id"))
    return out


class LoginIn(BaseModel):
    email: str = Field(min_length=3, max_length=120)
    password: str = Field(min_length=1, max_length=200)


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class RegisterIn(BaseModel):
    invite_code: str = Field(min_length=4, max_length=64)
    name: str = Field(min_length=2, max_length=60)


@router.post("/login")
async def login(body: LoginIn):
    db = get_db()
    email = body.email.strip().lower()

    role, doc = "superadmin", await db.superadmin.find_one({"email": email})
    if doc is None:
        role, doc = "admin", await db.admins.find_one({"email": email})
    if doc is None or not await verify_password(body.password, doc.get("password_hash", "")):
        raise unauthorized("invalid_credentials", "E-mail ou mot de passe incorrect")

    if role == "admin":
        if doc.get("status") == "pending":
            raise forbidden("account_pending", "Compte en attente d'acceptation")
        if doc.get("status") != "active":
            raise forbidden("account_suspended", "Compte suspendu")

    token = make_token(str(doc["_id"]), role)
    return {"token": token, "user": user_json(role, doc)}


@router.get("/me")
async def me(p: Principal = Depends(auth(allow_password_change=True))):
    return {"user": user_json(p.role, p.doc)}


@router.post("/change-password")
async def change_password(
    body: ChangePasswordIn,
    p: Principal = Depends(auth("admin", "superadmin", allow_password_change=True)),
):
    if not await verify_password(body.current_password, p.doc.get("password_hash", "")):
        raise ApiError(401, "invalid_credentials", "Mot de passe actuel incorrect")
    if body.current_password == body.new_password:
        raise bad_request("same_password", "Le nouveau mot de passe doit être différent")
    collection = "superadmin" if p.role == "superadmin" else "admins"
    await get_db()[collection].update_one(
        {"_id": p.doc["_id"]},
        {
            "$set": {
                "password_hash": await hash_password(body.new_password),
                "must_change_password": False,
                "password_changed_at": now(),
            }
        },
    )
    fresh = await get_db()[collection].find_one({"_id": p.doc["_id"]})
    return {"ok": True, "user": user_json(p.role, fresh)}


@router.post("/eleveur/register", status_code=201)
async def eleveur_register(body: RegisterIn):
    db = get_db()
    code_hash = keyed_hash(extract_code(body.invite_code))
    t = now()

    # claim the invite atomically so one code can create only one account
    invite = await db.invites.find_one_and_update(
        {"code_hash": code_hash, "used_at": None, "expires_at": {"$gt": t}},
        {"$set": {"used_at": t}},
    )
    if invite is None:
        raise ApiError(400, "invalid_invite", "Code d'invitation invalide ou expiré")

    admin = await db.admins.find_one({"_id": invite["admin_id"]})
    if admin is None or admin.get("status") != "active":
        await db.invites.update_one({"_id": invite["_id"]}, {"$set": {"used_at": None}})
        raise forbidden("account_suspended", "Compte suspendu")
    if not subscription_active(admin):
        await db.invites.update_one({"_id": invite["_id"]}, {"$set": {"used_at": None}})
        raise subscription_expired()

    eleveur = {
        "name": body.name.strip(),
        "admin_id": admin["_id"],
        "created_at": t,
    }
    result = await db.eleveurs.insert_one(eleveur)
    await db.invites.update_one(
        {"_id": invite["_id"]}, {"$set": {"used_by": result.inserted_id}}
    )
    eleveur["_id"] = result.inserted_id
    token = make_token(
        str(result.inserted_id), "eleveur", str(admin["_id"]), days=ELEVEUR_TOKEN_DAYS
    )
    return {"token": token, "user": user_json("eleveur", eleveur)}
