from pymongo import AsyncMongoClient

from .config import settings

client: AsyncMongoClient | None = None
db = None  # set by connect()


async def connect():
    global client, db
    client = AsyncMongoClient(settings.mongo_uri, tz_aware=True)
    db = client[settings.mongo_db]
    await ensure_indexes()


async def close():
    if client is not None:
        await client.close()


async def ensure_indexes():
    try:
        await db.users.create_index("email", unique=True)
        await db.notifications.create_index([("user_id", 1), ("created_at", -1)])
        await db.reports.create_index([("cow_id", 1), ("created_at", -1)])
        await db[settings.mongo_collection].create_index([("cow_id", 1), ("date", -1)])
    except Exception:  # never stop the server for an index problem
        import logging
        logging.getLogger("db").exception("Could not create indexes (continuing)")
