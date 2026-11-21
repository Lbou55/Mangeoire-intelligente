"""Create the one superadmin in farm.superadmin (run once).

    cd server
    set MONGO_URI=...   (or put it in .env)
    set SUPERADMIN_EMAIL=...  SUPERADMIN_PASSWORD=...
    python -m scripts.seed_superadmin
"""
import asyncio
import os
import sys

from app.db import close_db, ensure_indexes, get_db
from app.security import hash_password
from app.serializers import now


async def main() -> None:
    email = os.environ.get("SUPERADMIN_EMAIL", "").strip().lower()
    password = os.environ.get("SUPERADMIN_PASSWORD", "")
    name = os.environ.get("SUPERADMIN_NAME", "Super Admin")
    if not email or len(password) < 8:
        sys.exit("Set SUPERADMIN_EMAIL and SUPERADMIN_PASSWORD (8+ chars).")

    db = get_db()
    await ensure_indexes()
    if await db.superadmin.count_documents({}) > 0:
        sys.exit("A superadmin already exists - nothing done.")
    await db.superadmin.insert_one(
        {
            "name": name,
            "email": email,
            "password_hash": await hash_password(password),
            "must_change_password": False,
            "created_at": now(),
        }
    )
    print(f"Superadmin created: {email}")
    await close_db()


if __name__ == "__main__":
    asyncio.run(main())
