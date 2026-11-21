import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .db import close_db, ensure_indexes, get_db
from .deps import load_principal
from .errors import ApiError, install_handlers
from .hub import hub
from .ingest import consume_forever
from .ingest import router as ingest_router
from .routers import admins, ai, alerts, auth, data, eleveurs, invites, profiles, subscription

log = logging.getLogger("mangeoire")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        await ensure_indexes()
    except Exception as exc:  # noqa: BLE001 - the server must still start
        log.error("index creation failed: %s", exc)
    consumer = None
    if get_settings().amqp_url:
        consumer = asyncio.create_task(consume_forever())
    yield
    if consumer:
        consumer.cancel()
    await close_db()


app = FastAPI(title="Mangeoire Intelligente API", version="2.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)
install_handlers(app)

for r in (
    auth.router, admins.router, admins.public_router, invites.router, eleveurs.router,
    profiles.router, alerts.router, data.router, subscription.router, ai.router,
    ingest_router,
):
    app.include_router(r)


@app.get("/health")
async def health():
    """Light endpoint: used by UptimeRobot to keep the free instance awake."""
    return {"status": "up"}


@app.get("/")
async def root():
    return {"name": "Mangeoire Intelligente API", "status": "up"}


@app.get("/health/db")
async def health_db():
    await get_db().command("ping")
    return {"status": "up", "db": "ok"}


@app.websocket("/ws/cows")
async def ws_cows(ws: WebSocket, token: str = ""):
    try:
        p = await load_principal(token)
        if p.farm_admin is None:
            raise ApiError(403, "forbidden")
    except ApiError:
        await ws.close(code=4401)
        return
    await ws.accept()
    hub.add(ws, str(p.farm_admin["_id"]))
    try:
        while True:
            text = await ws.receive_text()  # keeps the socket open; answers pings
            if text == "ping":
                await ws.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        hub.remove(ws)
