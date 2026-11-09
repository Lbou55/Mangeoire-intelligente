
"""Fill the TEST database with fake data.

    docker compose -f docker-compose.dev.yml exec api python seed.py
    docker compose -f docker-compose.dev.yml exec api python seed.py --reset

Without Docker:
    python seed.py

Test accounts (password for all: Test1234!)
    owner   : karim@test.com
    farmers : sami@test.com , leila@test.com
"""

import random
import sys
from datetime import date, datetime, timedelta, timezone

from argon2 import PasswordHasher
from pymongo import MongoClient, ReturnDocument

from app.config import settings

PASSWORD = "Test1234!"
now = datetime.now(timezone.utc)

# RFID tag, type, age_months, status
COWS = [
    ("3C43FA39", "laitiere", 86.0, "normal"),
    ("822D4251", "laitiere", 49.5, "alerte"),
    ("92B47151", "viande", 37.0, "danger"),
    ("92EBEA51", "laitiere", 61.0, "alerte"),
    ("CC8B7922", "viande", 73.0, "normal"),
    ("EC954B17", "laitiere", 55.0, "normal"),
    ("EDFF4D24", "viande", 61.9, "normal"),
]

USUAL = {
    "3C43FA39": 8800,
    "822D4251": 7200,
    "92B47151": 6500,
    "92EBEA51": 7600,
    "CC8B7922": 6900,
    "EC954B17": 8100,
    "EDFF4D24": 6800,
}


def next_cow_display_id(db):
    counter = db.counters.find_one_and_update(
        {"_id": "cow_display_id"},
        {"$inc": {"value": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    return f"C{counter['value']}"


def synchronize_counter(db):
    """Ensure the counter is at least as high as existing cow IDs."""

    existing = db.cows.find(
        {"display_id": {"$regex": r"^C\d+$"}},
        {"display_id": 1},
    )

    highest = max(
        (int(c["display_id"][1:]) for c in existing),
        default=0,
    )

    db.counters.update_one(
        {"_id": "cow_display_id"},
        {"$max": {"value": highest}},
        upsert=True,
    )


def events_for(tag, age, status, rng, days=14):
    base = USUAL[tag]
    out = []

    for i in range(days, 0, -1):
        d = date.today() - timedelta(days=i - 1)
        f = rng.uniform(0.94, 1.06)

        if i <= 2 and status == "alerte":
            f = rng.uniform(0.62, 0.72)

        if i <= 2 and status == "danger":
            f = rng.uniform(0.35, 0.5)

        food = round(base * f)
        offered = round(base * 1.4)
        visits = max(
            2,
            round(rng.randint(8, 13) * (0.5 if f < 0.75 else 1)),
        )
        minutes = round(105 * f * rng.uniform(0.95, 1.05))

        out.append({
            "_id": f"{tag}-{d.isoformat()}",
            "cow_id": tag,
            "date": d.isoformat(),
            "age_months": age,
            "food_consumed_g": food,
            "feed_offered_g": offered,
            "visits": visits,
            "eating_minutes": minutes,
            "avg_meal_duration_min": round(minutes / visits, 1),
            "no_food_visits": rng.randint(1, 3) + (3 if f < 0.75 else 0),
            "first_visit_hour": round(rng.uniform(6.0, 7.2), 1),
            "last_visit_hour": round(rng.uniform(19.0, 21.0), 1),
        })

    return out


def main():
    reset = "--reset" in sys.argv

    client = MongoClient(settings.mongo_uri, tz_aware=True)
    db = client[settings.mongo_db]

    print("Database:", settings.mongo_db)

    if reset:
        for name in (
            "users",
            "cows",
            "reports",
            "notifications",
            "settings",
            "counters",
            settings.mongo_collection,
        ):
            db[name].drop()

        print("Collections dropped")

    ph = PasswordHasher()
    pw = ph.hash(PASSWORD)

    db.users.create_index("email", unique=True)
    db.cows.create_index("display_id", unique=True, sparse=True)

    ids = {}

    for name, email, role in [
        ("Karim Ben Salem", "karim@test.com", "owner"),
        ("Sami Trabelsi", "sami@test.com", "farmer"),
        ("Leila Mansouri", "leila@test.com", "farmer"),
    ]:
        db.users.update_one(
            {"email": email},
            {
                "$set": {
                    "name": name,
                    "role": role,
                    "active": True,
                    "password_hash": pw,
                },
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )

        ids[email] = str(
            db.users.find_one({"email": email})["_id"]
        )

    db.settings.update_one(
        {"_id": "farm"},
        {"$set": {"vet_phone": "+21612345678"}},
        upsert=True,
    )

    synchronize_counter(db)

    rng = random.Random(42)
    col = db[settings.mongo_collection]

    for tag, typ, age, status in COWS:
        existing = db.cows.find_one(
            {"_id": tag},
            {"display_id": 1},
        )

        display_id = (
            existing.get("display_id")
            if existing and existing.get("display_id")
            else next_cow_display_id(db)
        )

        db.cows.update_one(
            {"_id": tag},
            {
                "$set": {
                    "display_id": display_id,
                    "name": "",
                    "type": typ,
                    "age_months": age,
                    "status": status,
                    "archived": False,
                    "p_flagged": {
                        "normal": 0.05,
                        "alerte": 0.72,
                        "danger": 0.93,
                    }[status],
                    "category": {
                        "normal": "normal",
                        "alerte": "decreased",
                        "danger": "decreased",
                    }[status],
                    "status_at": now,
                    "created_by": ids["sami@test.com"],
                    "created_by_name": "Sami Trabelsi",
                },
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )

        for ev in events_for(tag, age, status, rng):
            col.replace_one(
                {"_id": ev["_id"]},
                ev,
                upsert=True,
            )

        print(f"Seeded {display_id}")

    # Clear names from every cow already in the database.
    result = db.cows.update_many(
        {},
        {"$set": {"name": ""}},
    )

    print(f"Cleared names from {result.modified_count} cows")

    # Example report and notification.
    alert_cow = db.cows.find_one({"_id": "822D4251"})
    alert_id = alert_cow["display_id"]

    if db.reports.count_documents({}) == 0:
        rep = {
            "cow_id": "822D4251",
            "cow_name": "",
            "level": "alerte",
            "reasons": ["mange_moins", "fatiguee"],
            "note": "Elle est restee loin de l'auge ce matin.",
            "voice": None,
            "author_id": ids["sami@test.com"],
            "author_name": "Sami Trabelsi",
            "created_at": now - timedelta(hours=2),
            "replies": [],
            "vet": None,
        }

        rid = str(db.reports.insert_one(rep).inserted_id)

        db.notifications.insert_one({
            "user_id": ids["karim@test.com"],
            "type": "report_alerte",
            "title": f"Alerte : {alert_id}",
            "body": "Sami Trabelsi : Mange moins que d'habitude, semble fatiguee",
            "cow_id": "822D4251",
            "report_id": rid,
            "needs_vet": False,
            "created_at": now - timedelta(hours=2),
            "read_at": None,
        })

    print("Done.")
    print("Users:", db.users.count_documents({}))
    print("Cows:", db.cows.count_documents({}))
    print("Events:", col.count_documents({}))
    print("Login with karim@test.com / sami@test.com / leila@test.com")
    print("Password:", PASSWORD)

    client.close()


if __name__ == "__main__":
    main()
