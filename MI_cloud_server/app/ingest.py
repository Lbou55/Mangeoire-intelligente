"""RabbitMQ -> MongoDB ingestion of the ESP32 data (same logic as before) + the old live WebSocket.
Only started when AMQP_URL is set."""
import asyncio
import json
import logging

import aio_pika
from fastapi import WebSocket
from fastapi.encoders import jsonable_encoder
from pymongo import ReplaceOne

log = logging.getLogger("ingest")


class Hub:
    def __init__(self):
        self.clients: set[WebSocket] = set()

    async def broadcast(self, msg: dict):
        try:
            text = json.dumps(jsonable_encoder(msg))
        except Exception:
            log.exception("Could not encode broadcast message")
            return
        dead = []
        for ws in list(self.clients):
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.clients.discard(ws)


hub = Hub()


def parse_items(body: bytes) -> list[dict]:
    """Accept one cow object, a list of cow objects, or double-encoded JSON."""
    payload = json.loads(body)
    if isinstance(payload, str):
        payload = json.loads(payload)
    items = payload if isinstance(payload, list) else [payload]
    out = []
    for d in items:
        if not isinstance(d, dict) or "cow_id" not in d or "date" not in d:
            raise TypeError("every item must be an object with cow_id and date")
        d = dict(d)
        d["cow_id"] = str(d["cow_id"]).strip().upper()
        d["date"] = str(d["date"]).strip()
        d["_id"] = f'{d["cow_id"]}-{d["date"]}'  # one document per cow per day
        out.append(d)
    return out


async def handle(message, col):
    try:
        items = parse_items(message.body)
        if items:
            ops = [ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in items]
            await col.bulk_write(ops, ordered=False)
            log.info("Stored %d document(s): %s", len(items), items[0]["_id"])
        await message.ack()
    except (ValueError, TypeError):
        log.warning("Bad message dropped: %r", message.body[:200])
        await message.reject(requeue=False)
        return
    except Exception:
        log.exception("DB error, requeueing")
        await asyncio.sleep(2)
        await message.nack(requeue=True)
        return

    for d in items:
        data = {k: v for k, v in d.items() if k != "_id"}
        await hub.broadcast({"type": "update", "cow_id": d["cow_id"], "data": data})


async def consume(col, amqp_url: str, queue_name: str):
    while True:
        try:
            connection = await aio_pika.connect_robust(amqp_url)
            async with connection:
                channel = await connection.channel()
                await channel.set_qos(prefetch_count=20)
                queue = await channel.declare_queue(queue_name, passive=True)
                log.info("Consuming from %s", queue_name)
                async with queue.iterator() as it:
                    async for message in it:
                        await handle(message, col)
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("AMQP connection failed, retrying in 5 s")
            await asyncio.sleep(5)
