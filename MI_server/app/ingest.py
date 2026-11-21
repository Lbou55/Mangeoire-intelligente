"""Measures coming from the Raspberry Pi.

Two doors, one pipeline (`process_measure`):
  * POST /ingest  with header X-Ingest-Key   (Node-RED / Pi, simplest on free hosting)
  * RabbitMQ queue (optional, if AMQP_URL is set)

Payload (what MI_module_AI_Forest/service.py publishes):
    {"esp32": {cow_id, date, food_consumed_g, feed_offered_g, visits, eating_minutes,
               avg_meal_duration_min, no_food_visits, first_visit_hour, last_visit_hour, ...},
     "model": {"status": "ok", "category": "normal|decreased|increased",
               "probabilities": {...}, "alert": bool}}
A bare esp32 dict, or a list of such items, is accepted too.
"""
import asyncio
import json
import logging

from fastapi import APIRouter, Header, Request

from .config import get_settings
from .db import get_db
from .errors import unauthorized
from .hub import hub
from .serializers import now

log = logging.getLogger("ingest")
router = APIRouter(tags=["ingest"])

CLASS_MAP = {
    "normal": "stable", "stable": "stable",
    "decreased": "decreasing", "decreasing": "decreasing", "low": "decreasing",
    "increased": "increasing", "increasing": "increasing", "high": "increasing",
}
ALERT_TEXT = {
    "decreasing": "Baisse d'appétit détectée pour {cow}.",
    "increasing": "Hausse d'appétit détectée pour {cow}.",
}


def _num(value, default=0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


async def _resolve_cow(cow_ref: str) -> dict | None:
    key = str(cow_ref).strip().upper()
    return await get_db().cow_profiles.find_one({"$or": [{"cow_id": key}, {"_id": key}]})


async def process_measure(item: dict) -> dict:
    esp = item.get("esp32") if isinstance(item.get("esp32"), dict) else item
    model = item.get("model") if isinstance(item.get("model"), dict) else None
    if "cow_id" not in esp or "date" not in esp:
        raise ValueError("cow_id and date are required")

    db = get_db()
    cow = await _resolve_cow(esp["cow_id"])
    cow_id = cow["cow_id"] if cow else str(esp["cow_id"]).strip().upper()
    admin_id = cow.get("admin_id") if cow else None
    day = str(esp["date"]).strip()[:10]
    t = now()

    consumed = _num(esp.get("food_consumed_g", esp.get("total_food_consumed_g")))
    offered = _num(esp.get("feed_offered_g", esp.get("total_feed_offered_g")))
    minutes = _num(esp.get("eating_minutes", esp.get("total_eating_minutes")))

    await db.realtime_readings.insert_one(
        {
            "cow_id": cow_id,
            "admin_id": admin_id,
            "timestamp": t,
            "visits": _num(esp.get("visits")),
            "food_consumed_g": consumed,
            "feed_offered_g": offered,
            "eating_minutes": minutes,
            "no_food_visits": _num(esp.get("no_food_visits")),
        }
    )

    daily = {
        "admin_id": admin_id,
        "total_food_consumed_g": consumed,
        "total_feed_offered_g": offered,
        "total_eating_minutes": minutes,
        "visits": _num(esp.get("visits")),
        "no_food_visits": _num(esp.get("no_food_visits")),
        "avg_meal_duration_min": _num(esp.get("avg_meal_duration_min")),
        "first_visit_hour": esp.get("first_visit_hour"),
        "last_visit_hour": esp.get("last_visit_hour"),
        "last_updated": t,
    }
    appetite_class = None
    if model and model.get("status") == "ok":
        raw = str(model.get("category", "")).lower()
        appetite_class = CLASS_MAP.get(raw)
        daily.update(
            {
                "appetite_raw": raw,
                "appetite_class": appetite_class,
                "appetite_pct": {
                    k: round(float(v) * 100, 1)
                    for k, v in (model.get("probabilities") or {}).items()
                },
                "appetite_source": "random_forest",
                "appetite_computed_at": t,
            }
        )
    await db.daily_summaries.update_one(
        {"cow_id": cow_id, "date": day},
        {"$set": daily, "$setOnInsert": {"first_reading_at": t}},
        upsert=True,
    )

    if offered > 0:
        await db.feed_dispatch.update_one(
            {"cow_id": cow_id, "date": day},
            {"$set": {"food_g": offered, "served_at": t, "admin_id": admin_id}},
            upsert=True,
        )

    # appetite alert: once per cow per day
    if appetite_class in ALERT_TEXT and admin_id is not None:
        res = await db.alerts.update_one(
            {"cow_id": cow_id, "type": "appetite", "day": day},
            {
                "$setOnInsert": {
                    "source": "ai",
                    "type": "appetite",
                    "severity": "warning" if appetite_class == "decreasing" else "info",
                    "message": ALERT_TEXT[appetite_class].format(cow=cow_id),
                    "cow_id": cow_id,
                    "admin_id": admin_id,
                    "action": None,
                    "status": "unread",
                    "created_at": t,
                    "read_at": None,
                    "day": day,
                    "appetite_class": appetite_class,
                    "appetite_pct": daily.get("appetite_pct"),
                }
            },
            upsert=True,
        )
        if res.upserted_id is not None:
            from .routers.alerts import alert_json  # noqa: PLC0415

            doc = await db.alerts.find_one({"_id": res.upserted_id})
            await hub.broadcast(str(admin_id), {"type": "alert", "alert": alert_json(doc)})

    await hub.broadcast(
        str(admin_id) if admin_id else None,
        {"type": "update", "cow_id": cow_id, "date": day, "appetite": appetite_class},
    )
    return {"cow_id": cow_id, "date": day, "appetite": appetite_class}


def _items(body) -> list[dict]:
    if isinstance(body, (str, bytes)):
        body = json.loads(body)
    if isinstance(body, str):  # double-encoded JSON
        body = json.loads(body)
    if isinstance(body, dict):
        return [body]
    if isinstance(body, list):
        return [b for b in body if isinstance(b, dict)]
    raise ValueError("object or list of objects expected")


@router.post("/ingest")
async def ingest(request: Request, x_ingest_key: str | None = Header(default=None)):
    key = get_settings().ingest_key
    if not key or x_ingest_key != key:
        raise unauthorized("invalid_ingest_key", "Clé d'ingestion invalide")
    results = []
    for item in _items(await request.body()):
        results.append(await process_measure(item))
    return {"ok": True, "processed": results}


async def consume_forever() -> None:
    """RabbitMQ consumer with automatic reconnection."""
    import aio_pika  # noqa: PLC0415

    s = get_settings()
    while True:
        try:
            conn = await aio_pika.connect_robust(s.amqp_url)
            async with conn:
                channel = await conn.channel()
                try:
                    queue = await channel.declare_queue(s.queue_name, passive=True)
                except Exception:  # noqa: BLE001 - queue missing: create it
                    channel = await conn.channel()
                    queue = await channel.declare_queue(s.queue_name, durable=True)
                log.info("consuming RabbitMQ queue %s", s.queue_name)
                async with queue.iterator() as it:
                    async for message in it:
                        async with message.process(requeue=False):
                            try:
                                for item in _items(message.body):
                                    await process_measure(item)
                            except Exception as exc:  # noqa: BLE001
                                log.error("bad message dropped: %s", exc)
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001
            log.error("RabbitMQ error: %s - retry in 10 s", exc)
            await asyncio.sleep(10)
