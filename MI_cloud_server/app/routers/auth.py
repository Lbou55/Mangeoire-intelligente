from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pymongo.errors import DuplicateKeyError

from .. import db as database
from ..schemas import LoginIn, PasswordChangeIn, RegisterIn
from ..security import (current_user, hash_password, make_token, public_user,
                        verify_password)

router = APIRouter(prefix="/auth", tags=["auth"])


def _session(user: dict) -> dict:
    return {"access_token": make_token(str(user["_id"]), user["role"]),
            "token_type": "bearer", "user": public_user(user)}


@router.post("/register", status_code=201)
async def register(body: RegisterIn):
    """Public sign-up creates THE owner. Only possible while there is no owner yet;
    the owner then creates the farmers' accounts (see /users)."""
    if await database.db.users.count_documents({"role": "owner"}) > 0:
        raise HTTPException(403, "Le compte propriétaire existe déjà. Demandez-lui de créer votre compte.")
    doc = {"name": body.name.strip(), "email": body.email.lower(), "role": "owner", "active": True,
           "password_hash": hash_password(body.password), "created_at": datetime.now(timezone.utc)}
    try:
        res = await database.db.users.insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(409, "Cette adresse e-mail est déjà utilisée")
    doc["_id"] = res.inserted_id
    return _session(doc)


@router.post("/login")
async def login(body: LoginIn):
    user = await database.db.users.find_one({"email": body.email.lower()})
    if not user or not user.get("active", True) or not verify_password(user["password_hash"], body.password):
        raise HTTPException(401, "E-mail ou mot de passe incorrect")
    return _session(user)


@router.get("/me")
async def me(user: dict = Depends(current_user)):
    return public_user(user)


@router.put("/me/password")
async def change_my_password(body: PasswordChangeIn, user: dict = Depends(current_user)):
    if not verify_password(user["password_hash"], body.old_password):
        raise HTTPException(400, "Ancien mot de passe incorrect")
    await database.db.users.update_one({"_id": user["_id"]},
                                       {"$set": {"password_hash": hash_password(body.new_password)}})
    return {"ok": True}
