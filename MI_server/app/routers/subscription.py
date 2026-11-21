"""Monthly subscription. The admin asks for a renewal; the superadmin approves it."""
from datetime import timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from ..config import get_settings
from ..db import get_db
from ..deps import Principal, auth, subscription_active
from ..errors import bad_request, not_found
from ..serializers import iso, now, to_oid

router = APIRouter(prefix="/subscription", tags=["subscription"])


def _days_left(expires) -> int:
    if expires is None:
        return 0
    if expires.tzinfo is None:
        from datetime import timezone

        expires = expires.replace(tzinfo=timezone.utc)
    return max((expires - now()).days + (1 if (expires - now()).seconds else 0), 0)


@router.get("/me")
async def my_subscription(p: Principal = Depends(auth("admin"))):
    expires = p.doc.get("subscription_expires_at")
    pending = await get_db().subscription_requests.find_one(
        {"admin_id": p.doc["_id"], "status": "pending"}
    )
    return {
        "active": subscription_active(p.doc),
        "expires_at": iso(expires),
        "days_left": _days_left(expires),
        "pending_request": pending is not None,
    }


class RequestIn(BaseModel):
    note: str | None = Field(default=None, max_length=300)


@router.post("/requests", status_code=201)
async def request_renewal(body: RequestIn | None = None, p: Principal = Depends(auth("admin"))):
    db = get_db()
    if await db.subscription_requests.find_one({"admin_id": p.doc["_id"], "status": "pending"}):
        raise bad_request("request_pending", "Une demande est déjà en cours")
    doc = {
        "admin_id": p.doc["_id"],
        "admin_name": p.doc.get("name"),
        "admin_email": p.doc.get("email"),
        "note": body.note if body else None,
        "status": "pending",
        "created_at": now(),
        "resolved_at": None,
    }
    res = await db.subscription_requests.insert_one(doc)
    return {"id": str(res.inserted_id), "status": "pending", "created_at": iso(doc["created_at"])}


@router.get("/requests")
async def list_requests(status: str | None = None, _: Principal = Depends(auth("superadmin"))):
    query = {"status": status} if status in ("pending", "approved", "rejected") else {}
    cursor = get_db().subscription_requests.find(query).sort("created_at", -1).limit(200)
    return [
        {
            "id": str(r["_id"]),
            "admin_id": str(r["admin_id"]),
            "admin_name": r.get("admin_name"),
            "admin_email": r.get("admin_email"),
            "note": r.get("note"),
            "status": r.get("status"),
            "created_at": iso(r.get("created_at")),
            "resolved_at": iso(r.get("resolved_at")),
        }
        for r in await cursor.to_list()
    ]


async def _resolve(request_id: str, approve: bool) -> dict:
    db = get_db()
    t = now()
    req = await db.subscription_requests.find_one_and_update(
        {"_id": to_oid(request_id), "status": "pending"},
        {"$set": {"status": "approved" if approve else "rejected", "resolved_at": t}},
    )
    if req is None:
        raise not_found("not_found", "Demande introuvable ou déjà traitée")
    if approve:
        admin = await db.admins.find_one({"_id": req["admin_id"]})
        base = admin.get("subscription_expires_at") if admin else None
        if base is None or base.replace(tzinfo=base.tzinfo or t.tzinfo) < t:
            base = t
        await db.admins.update_one(
            {"_id": req["admin_id"]},
            {"$set": {"subscription_expires_at": base + timedelta(days=get_settings().subscription_days)}},
        )
    return {"ok": True}


@router.post("/requests/{request_id}/approve")
async def approve(request_id: str, _: Principal = Depends(auth("superadmin"))):
    return await _resolve(request_id, True)


@router.post("/requests/{request_id}/reject")
async def reject(request_id: str, _: Principal = Depends(auth("superadmin"))):
    return await _resolve(request_id, False)
