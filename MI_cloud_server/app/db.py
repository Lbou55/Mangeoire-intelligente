from pymongo import AsyncMongoClient, ReturnDocument
from pymongo.errors import DuplicateKeyError

from .config import settings

client: AsyncMongoClient | None = None
db = None


async def connect():
    global client, db
    client = AsyncMongoClient(settings.mongo_uri, tz_aware=True)
    db = client[settings.mongo_db]
    await ensure_indexes()


async def close():
    if client is not None:
        await client.close()


async def next_cow_display_id() -> str:
    try:
        counter = await db.counters.find_one_and_update(
            {"_id": "cow_display_id"},
            {"$inc": {"value": 1}},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
    except DuplicateKeyError:
        counter = await db.counters.find_one_and_update(
            {"_id": "cow_display_id"},
            {"$inc": {"value": 1}},
            return_document=ReturnDocument.AFTER,
        )

    return f"C{counter['value']}"


async def migrate_cow_display_ids():
    existing = await db.cows.find(
        {"display_id": {"$regex": r"^C\d+$"}},
        {"display_id": 1},
    ).to_list(length=None)

    highest = max(
        (int(c["display_id"][1:]) for c in existing),
        default=0,
    )

    await db.counters.update_one(
        {"_id": "cow_display_id"},
        {"$max": {"value": highest}},
        upsert=True,
    )

    cursor = db.cows.find(
        {"display_id": {"$exists": False}}
    ).sort([("created_at", 1), ("_id", 1)])

    async for cow in cursor:
        display_id = await next_cow_display_id()
        await db.cows.update_one(
            {"_id": cow["_id"], "display_id": {"$exists": False}},
            {"$set": {"display_id": display_id}},
        )


async def ensure_indexes():
    try:
        await db.users.create_index("email", unique=True)
        await db.cows.create_index("display_id", unique=True, sparse=True)
        await db.notifications.create_index([("user_id", 1), ("created_at", -1)])
        await db.reports.create_index([("cow_id", 1), ("created_at", -1)])
        await db[settings.mongo_collection].create_index(
            [("cow_id", 1), ("date", -1)]
        )
        await migrate_cow_display_ids()
    except Exception:
        import logging
        logging.getLogger("db").exception(
            "Could not create indexes or migrate cow IDs"
        )