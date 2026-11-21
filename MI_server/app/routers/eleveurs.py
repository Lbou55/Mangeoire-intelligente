from fastapi import APIRouter, Depends

from ..db import get_db
from ..deps import Principal, auth
from ..errors import not_found
from ..serializers import iso, to_oid

router = APIRouter(prefix="/eleveurs", tags=["eleveurs"])


@router.get("")
async def list_eleveurs(p: Principal = Depends(auth("admin", farm=True))):
    cursor = get_db().eleveurs.find({"admin_id": p.doc["_id"]}).sort("created_at", -1)
    return [
        {"id": str(e["_id"]), "name": e.get("name", ""), "created_at": iso(e.get("created_at"))}
        for e in await cursor.to_list()
    ]


@router.delete("/{eleveur_id}")
async def delete_eleveur(eleveur_id: str, p: Principal = Depends(auth("admin", farm=True))):
    res = await get_db().eleveurs.delete_one(
        {"_id": to_oid(eleveur_id), "admin_id": p.doc["_id"]}
    )
    if res.deleted_count == 0:
        raise not_found()
    return {"ok": True}
