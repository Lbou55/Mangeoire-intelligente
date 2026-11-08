from datetime import datetime, timezone

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException

from .. import db as database
from ..logic import check_reasons, cow_label, reasons_text
from ..notify import iso, notify
from ..schemas import ReplyIn, ReportIn, VetIn
from ..security import current_user, owner_only

router = APIRouter(tags=["reports"])


async def _owner_ids() -> list[str]:
    cur = database.db.users.find({"role": "owner", "active": {"$ne": False}}, {"_id": 1})
    return [str(u["_id"]) for u in await cur.to_list(length=10)]


async def _report_for(report_id: str, user: dict) -> dict:
    try:
        oid = ObjectId(report_id)
    except InvalidId:
        raise HTTPException(404, "Signalement introuvable")
    rep = await database.db.reports.find_one({"_id": oid})
    if rep is None:
        raise HTTPException(404, "Signalement introuvable")
    if user["role"] != "owner" and rep["author_id"] != str(user["_id"]):
        raise HTTPException(403, "Ce signalement ne vous appartient pas")
    return rep


async def _seen(rep: dict) -> dict:
    """Read receipts: when did the owner read the report, when did the farmer read the answers."""
    rid = str(rep["_id"])

    async def first_read(extra: dict):
        n = await database.db.notifications.find_one(
            {"report_id": rid, "read_at": {"$ne": None}, **extra}, sort=[("read_at", 1)])
        return iso(n["read_at"]) if n else None

    owner_seen = await first_read({"type": {"$in": ["report_alerte", "report_danger"]}})
    farmer_seen = await first_read({"user_id": rep["author_id"],
                                    "type": {"$in": ["owner_reply", "vet_called", "vet_declined"]}})
    return {"owner_seen_at": owner_seen, "farmer_seen_at": farmer_seen}


async def report_out(rep: dict, with_seen: bool = True) -> dict:
    out = {
        "id": str(rep["_id"]), "cow_id": rep["cow_id"], "cow_name": rep.get("cow_name", ""),
        "level": rep["level"], "reasons": rep["reasons"], "note": rep.get("note", ""),
        "voice": rep.get("voice"), "author_id": rep["author_id"], "author_name": rep["author_name"],
        "created_at": iso(rep["created_at"]), "vet": None,
        "replies": [{"by_id": r["by_id"], "by_name": r["by_name"], "by_role": r["by_role"],
                     "text": r["text"], "at": iso(r["at"])} for r in rep.get("replies", [])],
    }
    if rep.get("vet"):
        out["vet"] = {"called": rep["vet"]["called"], "at": iso(rep["vet"]["at"])}
    if with_seen:
        out["seen"] = await _seen(rep)
    return out


@router.post("/cows/{tag}/reports", status_code=201)
async def create_report(tag: str, body: ReportIn, user: dict = Depends(current_user)):
    cow = await database.db.cows.find_one({"_id": tag.strip().upper()})
    if cow is None:
        raise HTTPException(404, "Vache introuvable")
    level = cow.get("status", "normal")
    if level == "normal":
        raise HTTPException(400, "Cette vache est en état normal : rien à signaler")
    try:
        reasons = check_reasons(level, body.reasons)
    except ValueError as e:
        raise HTTPException(400, str(e))
    doc = {"cow_id": cow["_id"], "cow_name": cow.get("name", ""), "level": level, "reasons": reasons,
           "note": body.note.strip(), "voice": None, "author_id": str(user["_id"]),
           "author_name": user["name"], "created_at": datetime.now(timezone.utc),
           "replies": [], "vet": None}
    res = await database.db.reports.insert_one(doc)
    doc["_id"] = res.inserted_id
    owners = [o for o in await _owner_ids() if o != str(user["_id"])]
    danger = level == "danger"
    await notify(owners, type="report_danger" if danger else "report_alerte",
                 title=("DANGER : " if danger else "Alerte : ") + cow_label(cow),
                 body=f'{user["name"]} : {reasons_text(reasons)}',
                 cow_id=cow["_id"], report_id=str(res.inserted_id), needs_vet=danger)
    return await report_out(doc)


@router.get("/reports")
async def list_reports(cow: str | None = None, user: dict = Depends(current_user)):
    query: dict = {}
    if user["role"] != "owner":
        query["author_id"] = str(user["_id"])
    if cow:
        query["cow_id"] = cow.strip().upper()
    cur = database.db.reports.find(query).sort("created_at", -1).limit(100)
    return [await report_out(r) for r in await cur.to_list(length=100)]


@router.get("/reports/{report_id}")
async def get_report(report_id: str, user: dict = Depends(current_user)):
    return await report_out(await _report_for(report_id, user))


@router.post("/reports/{report_id}/seen")
async def mark_seen(report_id: str, user: dict = Depends(current_user)):
    """The app calls this when the report screen is opened: this is the 'read' receipt."""
    rep = await _report_for(report_id, user)
    await database.db.notifications.update_many(
        {"user_id": str(user["_id"]), "report_id": str(rep["_id"]), "read_at": None},
        {"$set": {"read_at": datetime.now(timezone.utc)}})
    return {"ok": True}


@router.post("/reports/{report_id}/replies", status_code=201)
async def reply(report_id: str, body: ReplyIn, user: dict = Depends(current_user)):
    rep = await _report_for(report_id, user)
    item = {"by_id": str(user["_id"]), "by_name": user["name"], "by_role": user["role"],
            "text": body.text.strip(), "at": datetime.now(timezone.utc)}
    await database.db.reports.update_one({"_id": rep["_id"]}, {"$push": {"replies": item}})
    rep.setdefault("replies", []).append(item)
    label = rep["cow_id"] if not rep.get("cow_name") else f'{rep["cow_name"]} ({rep["cow_id"]})'
    if user["role"] == "owner":
        targets, kind = [rep["author_id"]], "owner_reply"
    else:
        targets, kind = [o for o in await _owner_ids() if o != str(user["_id"])], "farmer_reply"
    await notify(targets, type=kind, title=f'Réponse · {label}',
                 body=f'{user["name"]} : {item["text"]}', cow_id=rep["cow_id"], report_id=str(rep["_id"]))
    return await report_out(rep)


@router.post("/reports/{report_id}/vet")
async def vet_decision(report_id: str, body: VetIn, user: dict = Depends(owner_only)):
    """Owner decides on a DANGER report: vet called (true) or not (false)."""
    rep = await _report_for(report_id, user)
    if rep["level"] != "danger":
        raise HTTPException(400, "Le vétérinaire ne concerne que les cas en danger")
    vet = {"called": body.called, "at": datetime.now(timezone.utc)}
    await database.db.reports.update_one({"_id": rep["_id"]}, {"$set": {"vet": vet}})
    rep["vet"] = vet
    label = rep["cow_id"] if not rep.get("cow_name") else f'{rep["cow_name"]} ({rep["cow_id"]})'
    await notify([rep["author_id"]], type="vet_called" if body.called else "vet_declined",
                 title=f"Vétérinaire · {label}",
                 body=("Le propriétaire a appelé le vétérinaire." if body.called
                       else "Le propriétaire n'appelle pas le vétérinaire pour le moment."),
                 cow_id=rep["cow_id"], report_id=str(rep["_id"]))
    return await report_out(rep)
