from datetime import datetime, timezone

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect

from .. import db as database
from ..notify import hub, notif_out
from ..security import current_user, user_from_token

router = APIRouter(tags=["notifications"])


@router.get("/notifications")
async def list_notifications(limit: int = Query(50, ge=1, le=200), user: dict = Depends(current_user)):
    cur = database.db.notifications.find({"user_id": str(user["_id"])}).sort("created_at", -1).limit(limit)
    return [notif_out(n) for n in await cur.to_list(length=limit)]


@router.get("/notifications/unread-count")
async def unread_count(user: dict = Depends(current_user)):
    n = await database.db.notifications.count_documents({"user_id": str(user["_id"]), "read_at": None})
    return {"count": n}


@router.post("/notifications/read-all")
async def read_all(user: dict = Depends(current_user)):
    await database.db.notifications.update_many({"user_id": str(user["_id"]), "read_at": None},
                                                {"$set": {"read_at": datetime.now(timezone.utc)}})
    return {"ok": True}


@router.post("/notifications/{notif_id}/read")
async def read_one(notif_id: str, user: dict = Depends(current_user)):
    try:
        oid = ObjectId(notif_id)
    except InvalidId:
        raise HTTPException(404, "Notification introuvable")
    res = await database.db.notifications.update_one(
        {"_id": oid, "user_id": str(user["_id"]), "read_at": None},
        {"$set": {"read_at": datetime.now(timezone.utc)}})
    return {"ok": True, "changed": res.modified_count}


@router.websocket("/ws/notifications")
async def ws_notifications(ws: WebSocket, token: str = ""):
    """Live notifications. The app connects with  /api/ws/notifications?token=<JWT>."""
    user = await user_from_token(token)
    if user is None:
        await ws.close(code=4401)
        return
    await ws.accept()
    uid = str(user["_id"])
    hub.add(uid, ws)
    try:
        while True:
            await ws.receive_text()  # the app may send "ping"; we ignore the content
    except WebSocketDisconnect:
        pass
    finally:
        hub.remove(uid, ws)
