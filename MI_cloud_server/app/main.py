import asyncio
import contextlib
import json
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from . import db as database
from .config import settings
from .ingest import consume, hub as cow_hub
from .routers import auth, cows, notifications, reports, users
from .security import current_user, user_from_token

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    tasks = []
    if settings.amqp_url:
        col = database.db[settings.mongo_collection]
        tasks.append(asyncio.create_task(consume(col, settings.amqp_url, settings.queue_name)))
    else:
        log.info("AMQP_URL is empty: RabbitMQ ingestion is OFF (fine on your PC)")
    yield
    for t in tasks:
        t.cancel()
    for t in tasks:
        with contextlib.suppress(asyncio.CancelledError):
            await t
    await database.close()


app = FastAPI(title="Mangeoire API", lifespan=lifespan)

origins = [o.strip() for o in settings.cors_origins.split(",")] if settings.cors_origins else []
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
async def health():
    return {"status": "ok"}


# everything the Flutter app uses lives under /api
for r in (auth.router, users.router, cows.router, reports.router, notifications.router):
    app.include_router(r, prefix="/api")


# ---------------- older endpoints (kept, now behind login) ----------------
@app.get("/events/{cow_id}")
async def events(cow_id: str, limit: int = Query(30, ge=1, le=500), _: dict = Depends(current_user)):
    col = database.db[settings.mongo_collection]
    cur = col.find({"cow_id": cow_id.strip().upper()}, {"_id": 0}).sort("date", -1).limit(limit)
    return await cur.to_list(length=limit)


@app.websocket("/ws/cows")
async def ws_cows(ws: WebSocket, token: str = ""):
    """Live ESP32 updates (as before) but now needs  ?token=<JWT>."""
    if await user_from_token(token) is None:
        await ws.close(code=4401)
        return
    await ws.accept()
    cow_hub.clients.add(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        cow_hub.clients.discard(ws)
