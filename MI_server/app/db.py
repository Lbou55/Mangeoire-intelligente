"""MongoDB Atlas connection (database `farm`)."""
from pymongo import ASCENDING, DESCENDING, AsyncMongoClient
from pymongo.asynchronous.database import AsyncDatabase

from .config import get_settings

_client: AsyncMongoClient | None = None


def get_db() -> AsyncDatabase:
    global _client
    s = get_settings()
    if _client is None:
        _client = AsyncMongoClient(
            s.mongo_uri, tz_aware=True, serverSelectionTimeoutMS=15000
        )
    return _client[s.mongo_db]


async def close_db() -> None:
    global _client
    if _client is not None:
        await _client.close()
        _client = None


async def ensure_indexes() -> None:
    db = get_db()
    await db.superadmin.create_index("email", unique=True)
    await db.admins.create_index("email", unique=True)
    await db.admins.create_index("accept_token_hash", sparse=True)
    await db.eleveurs.create_index("admin_id")
    await db.invites.create_index("code_hash", unique=True)
    await db.invites.create_index("admin_id")
    await db.cow_profiles.create_index("cow_id", unique=True)
    await db.cow_profiles.create_index("admin_id")
    await db.alerts.create_index([("admin_id", ASCENDING), ("created_at", DESCENDING)])
    await db.daily_summaries.create_index(
        [("cow_id", ASCENDING), ("date", DESCENDING)], unique=True
    )
    await db.realtime_readings.create_index(
        [("cow_id", ASCENDING), ("timestamp", DESCENDING)]
    )
    await db.feed_dispatch.create_index(
        [("cow_id", ASCENDING), ("date", DESCENDING)], unique=True
    )
    await db.subscription_requests.create_index(
        [("admin_id", ASCENDING), ("created_at", DESCENDING)]
    )
