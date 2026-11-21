from datetime import date, datetime, timezone
from typing import Any

from bson import ObjectId

from .errors import not_found


def iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def now() -> datetime:
    return datetime.now(timezone.utc)


def to_oid(value: str) -> ObjectId:
    try:
        return ObjectId(value)
    except Exception:  # noqa: BLE001
        raise not_found() from None


def clean(value: Any) -> Any:
    """Make a Mongo document JSON-safe (ObjectId -> str, datetime -> ISO)."""
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items()}
    if isinstance(value, list):
        return [clean(v) for v in value]
    if isinstance(value, ObjectId):
        return str(value)
    if isinstance(value, datetime):
        return iso(value)
    if isinstance(value, date):
        return value.isoformat()
    return value


def with_id(doc: dict, drop: tuple[str, ...] = ()) -> dict:
    """{_id: ObjectId, ...} -> {id: str, ...} without secrets."""
    out = {k: v for k, v in doc.items() if k not in drop and k != "_id"}
    out["id"] = str(doc["_id"])
    return clean(out)


SECRET_FIELDS = ("password_hash", "code_hash", "accept_token_hash")


def months_between(birth: datetime, today: datetime | None = None) -> int:
    today = today or now()
    months = (today.year - birth.year) * 12 + (today.month - birth.month)
    if today.day < birth.day:
        months -= 1
    return max(months, 0)
