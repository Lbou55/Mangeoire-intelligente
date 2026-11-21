"""Give the 7 existing cows to an admin (sets admin_id), creating them if missing.

    python -m scripts.seed_cows admin@example.com
Existing fields are never overwritten, only admin_id is set when missing.
"""
import asyncio
import sys
from datetime import datetime, timedelta, timezone

from app.db import close_db, get_db

TAGS = ["3C43FA39", "CC8B7922", "92EBEA51", "822D4251", "EC954B17", "92B47151", "EDFF4D24"]
SAMPLE = [  # type, breed, weight_kg, age_months
    ("dairy", "Holstein", 610, 36), ("dairy", "Jersey", 420, 28),
    ("beef", "Angus", 580, 30), ("beef", "Limousin", 690, 42),
    ("beef", "Charolais", 760, 48), ("dual", "Simmental", 650, 34),
    ("dairy", "Holstein", 540, 24),
]


async def main(email: str) -> None:
    db = get_db()
    admin = await db.admins.find_one({"email": email.lower()})
    if admin is None:
        sys.exit("Admin not found (create and accept the admin first).")
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    for i, tag in enumerate(TAGS):
        kind, breed, weight, age = SAMPLE[i]
        await db.cow_profiles.update_one(
            {"_id": tag},
            {
                "$setOnInsert": {
                    "cow_id": f"COW{i + 1:03d}",
                    "age_months": age,
                    "birth_date": today - timedelta(days=round(age * 30.44)),
                    "breed": breed,
                    "type": kind,
                    "weight_kg": weight,
                    "created_at": datetime.now(timezone.utc),
                }
            },
            upsert=True,
        )
        await db.cow_profiles.update_one(
            {"_id": tag, "admin_id": {"$exists": False}}, {"$set": {"admin_id": admin["_id"]}}
        )
    print(f"{len(TAGS)} cows assigned to {email}")
    await close_db()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python -m scripts.seed_cows <admin_email>")
    asyncio.run(main(sys.argv[1]))
