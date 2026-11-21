from datetime import timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from ..config import get_settings
from ..db import get_db
from ..deps import Principal, auth, subscription_active
from ..errors import not_found
from ..security import keyed_hash, new_invite_code
from ..serializers import iso, now, to_oid

router = APIRouter(prefix="/invites", tags=["invites"])

QR_PREFIX = "MANGEOIRE:"


def extract_code(raw: str) -> str:
    """Accepts the bare code or the QR payload (MANGEOIRE:XXXXXXXX)."""
    value = raw.strip()
    if value.upper().startswith(QR_PREFIX):
        value = value[len(QR_PREFIX):]
    return value.replace("-", "").replace(" ", "").upper()


def invite_status(inv: dict) -> str:
    if inv.get("used_at") is not None:
        return "used"
    expires = inv["expires_at"]
    if expires.tzinfo is None:
        from datetime import timezone

        expires = expires.replace(tzinfo=timezone.utc)
    return "expired" if expires <= now() else "active"


@router.post("", status_code=201)
async def create_invite(p: Principal = Depends(auth("admin", farm=True))):
    db = get_db()
    ttl = get_settings().invite_hours
    t = now()
    for _ in range(5):  # collision-proof (unique index on code_hash)
        code = new_invite_code()
        doc = {
            "code_hash": keyed_hash(code),
            "admin_id": p.doc["_id"],
            "created_at": t,
            "expires_at": t + timedelta(hours=ttl),
            "used_at": None,
            "used_by": None,
        }
        try:
            res = await db.invites.insert_one(doc)
            break
        except Exception:  # noqa: BLE001
            continue
    else:
        raise RuntimeError("could not generate an invite code")
    return {
        "id": str(res.inserted_id),
        "code": code,
        "qr_payload": f"{QR_PREFIX}{code}",
        "expires_at": iso(doc["expires_at"]),
    }


@router.get("")
async def list_invites(p: Principal = Depends(auth("admin", farm=True))):
    db = get_db()
    out = []
    cursor = db.invites.find({"admin_id": p.doc["_id"]}).sort("created_at", -1).limit(100)
    for inv in await cursor.to_list():
        used_by_name = None
        if inv.get("used_by"):
            e = await db.eleveurs.find_one({"_id": inv["used_by"]})
            used_by_name = e.get("name") if e else None
        out.append(
            {
                "id": str(inv["_id"]),
                "status": invite_status(inv),
                "created_at": iso(inv["created_at"]),
                "expires_at": iso(inv["expires_at"]),
                "used_by_name": used_by_name,
            }
        )
    return out


@router.delete("/{invite_id}")
async def delete_invite(invite_id: str, p: Principal = Depends(auth("admin", farm=True))):
    res = await get_db().invites.delete_one(
        {"_id": to_oid(invite_id), "admin_id": p.doc["_id"]}
    )
    if res.deleted_count == 0:
        raise not_found()
    return {"ok": True}


class CheckIn(BaseModel):
    code: str = Field(min_length=4, max_length=64)


@router.post("/check")
async def check_invite(body: CheckIn):
    """Public: tells the farmer's app if a scanned/typed code is usable."""
    db = get_db()
    inv = await db.invites.find_one({"code_hash": keyed_hash(extract_code(body.code))})
    if inv is None or invite_status(inv) != "active":
        return {"valid": False, "admin_name": None}
    admin = await db.admins.find_one({"_id": inv["admin_id"]})
    valid = bool(admin and admin.get("status") == "active" and subscription_active(admin))
    return {"valid": valid, "admin_name": admin.get("name") if valid else None}
