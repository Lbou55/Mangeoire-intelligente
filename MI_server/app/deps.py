"""Authentication / authorization dependencies.

Roles:  superadmin  -> creates admins, sees who accepted, approves renewals
        admin       -> owns a farm (eleveurs, cows, alerts, invites); needs a live subscription
        eleveur     -> farmer; read-only on cows; belongs to one admin
"""
from dataclasses import dataclass

import jwt
from fastapi import Request

from .db import get_db
from .errors import (
    ApiError,
    forbidden,
    subscription_expired,
    unauthorized,
)
from .security import decode_token
from .serializers import now, to_oid

ROLE_COLLECTION = {"superadmin": "superadmin", "admin": "admins", "eleveur": "eleveurs"}


@dataclass
class Principal:
    id: str
    role: str
    doc: dict
    farm_admin: dict | None = None  # the admin document that owns the farm

    @property
    def admin_id(self) -> str | None:
        """Id of the admin owning the data this user may see."""
        if self.role == "admin":
            return self.id
        if self.role == "eleveur":
            return str(self.doc.get("admin_id"))
        return None


def subscription_active(admin_doc: dict) -> bool:
    expires = admin_doc.get("subscription_expires_at")
    if expires is None:
        return False
    if expires.tzinfo is None:
        from datetime import timezone

        expires = expires.replace(tzinfo=timezone.utc)
    return expires > now()


def _bearer(request: Request) -> str:
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise unauthorized("missing_token", "Connexion requise")
    return header[7:].strip()


async def load_principal(token: str) -> Principal:
    try:
        payload = decode_token(token)
    except jwt.ExpiredSignatureError:
        raise unauthorized("token_expired", "Session expirée") from None
    except jwt.PyJWTError:
        raise unauthorized() from None

    role = payload.get("role")
    collection = ROLE_COLLECTION.get(role or "")
    if not collection:
        raise unauthorized()
    db = get_db()
    doc = await db[collection].find_one({"_id": to_oid(payload.get("sub", ""))})
    if doc is None:
        raise unauthorized("user_not_found", "Compte introuvable")

    principal = Principal(id=str(doc["_id"]), role=role, doc=doc)

    if role == "admin":
        status = doc.get("status")
        if status == "pending":
            raise forbidden("account_pending", "Compte en attente d'acceptation")
        if status != "active":
            raise forbidden("account_suspended", "Compte suspendu")
        principal.farm_admin = doc
    elif role == "eleveur":
        admin = await db.admins.find_one({"_id": doc.get("admin_id")})
        if admin is None or admin.get("status") != "active":
            raise forbidden("account_suspended", "Compte suspendu")
        principal.farm_admin = admin
    return principal


def auth(*roles: str, farm: bool = False, allow_password_change: bool = False):
    """Dependency factory.

    roles                  allowed roles (empty = any)
    farm                   True for feature routes: requires a live subscription
    allow_password_change  True only for /auth/me and /auth/change-password
    """

    async def dependency(request: Request) -> Principal:
        principal = await load_principal(_bearer(request))
        if roles and principal.role not in roles:
            raise forbidden()
        if (
            not allow_password_change
            and principal.role in ("admin", "superadmin")
            and principal.doc.get("must_change_password")
        ):
            raise ApiError(403, "password_change_required", "Changement de mot de passe requis")
        if farm and principal.farm_admin is not None:
            if not subscription_active(principal.farm_admin):
                raise subscription_expired()
        return principal

    return dependency
