import asyncio
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from .config import get_settings

# Unambiguous characters (no 0/O, 1/I/L) for codes typed by hand.
_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def _hash_pw(password: str) -> str:
    return bcrypt.hashpw(password.encode()[:72], bcrypt.gensalt(12)).decode()


def _check_pw(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode()[:72], hashed.encode())
    except ValueError:
        return False


async def hash_password(password: str) -> str:
    return await asyncio.to_thread(_hash_pw, password)


async def verify_password(password: str, hashed: str) -> bool:
    return await asyncio.to_thread(_check_pw, password, hashed)


def make_token(
    sub: str, role: str, admin_id: str | None = None, days: int | None = None
) -> str:
    s = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "role": role,
        "iat": now,
        "exp": now + timedelta(days=days or s.jwt_days),
    }
    if admin_id:
        payload["admin_id"] = admin_id
    return jwt.encode(payload, s.jwt_secret, algorithm="HS256")


def decode_token(token: str) -> dict:
    return jwt.decode(token, get_settings().jwt_secret, algorithms=["HS256"])


def keyed_hash(value: str) -> str:
    """HMAC-SHA256 used for invite codes and acceptance tokens (never stored raw)."""
    key = get_settings().jwt_secret.encode()
    return hmac.new(key, value.strip().upper().encode(), hashlib.sha256).hexdigest()


def new_invite_code() -> str:
    raw = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(8))
    return raw


def new_accept_token() -> str:
    return secrets.token_urlsafe(32)


def token_hash(token: str) -> str:
    key = get_settings().jwt_secret.encode()
    return hmac.new(key, token.encode(), hashlib.sha256).hexdigest()
