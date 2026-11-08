from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from bson import ObjectId
from bson.errors import InvalidId
from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import db as database
from .config import settings

_ph = PasswordHasher()
_bearer = HTTPBearer(auto_error=False)
ALGO = "HS256"


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(hashed: str, password: str) -> bool:
    try:
        return _ph.verify(hashed, password)
    except (VerificationError, InvalidHashError):
        return False


def make_token(user_id: str, role: str) -> str:
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.token_minutes)
    return jwt.encode({"sub": user_id, "role": role, "exp": exp}, settings.secret_key, algorithm=ALGO)


def read_token(token: str) -> dict:
    """Raises jwt.PyJWTError if invalid or expired."""
    return jwt.decode(token, settings.secret_key, algorithms=[ALGO])


async def user_from_token(token: str) -> dict | None:
    try:
        payload = read_token(token)
        oid = ObjectId(payload["sub"])
    except (jwt.PyJWTError, InvalidId, KeyError):
        return None
    user = await database.db.users.find_one({"_id": oid})
    if not user or not user.get("active", True):
        return None
    return user


async def current_user(creds: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> dict:
    if creds is None:
        raise HTTPException(401, "Vous n'êtes pas connecté")
    user = await user_from_token(creds.credentials)
    if user is None:
        raise HTTPException(401, "Session expirée, reconnectez-vous")
    return user


async def owner_only(user: dict = Depends(current_user)) -> dict:
    if user["role"] != "owner":
        raise HTTPException(403, "Réservé au propriétaire")
    return user


async def service_only(x_service_key: str | None = Header(default=None)) -> None:
    """For machines (Node-RED, the Pi), not for people."""
    if not x_service_key or x_service_key != settings.service_key:
        raise HTTPException(401, "Clé de service invalide")


def public_user(u: dict) -> dict:
    return {
        "id": str(u["_id"]),
        "name": u["name"],
        "email": u["email"],
        "role": u["role"],
        "created_at": u.get("created_at"),
    }
