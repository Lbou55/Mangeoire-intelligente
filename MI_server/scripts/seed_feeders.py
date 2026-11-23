"""Create the example feeder for an admin.

    python -m scripts.seed_feeders <admin_email>
"""
import asyncio
import sys
from datetime import datetime, timezone

from app.db import close_db, get_db


async def main(email: str) -> None:
    db = get_db()
    admin = await db.admins.find_one({"email": email.lower()})
    if admin is None:
        sys.exit("Admin not found (create and accept the admin first).")

    existing = await db.feeders.find_one({"_id": "feeder-001"})
    if existing is None:
        await db.feeders.insert_one({
            "_id": "feeder-001",
            "farm_id": "farm-001",
            "admin_id": admin["_id"],
            "name": "Mangeoire A",
            "capacity_g": 100000,
            "current_quantity_g": 18500,
            "last_refill_at": None,
            "online": False,
            "last_seen_at": None,
        })
        print(f"feeder-001 created for {email}")
    else:
        print("feeder-001 already exists")
    await close_db()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python -m scripts.seed_feeders <admin_email>")
    asyncio.run(main(sys.argv[1]))
