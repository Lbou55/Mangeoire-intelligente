"""Superadmin: create admins (e-mail + password sent by mail), see who accepted."""
from datetime import timedelta
from html import escape

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from ..config import get_settings
from ..db import get_db
from ..deps import Principal, auth
from ..errors import bad_request, conflict, not_found
from ..mailer import send_mail
from ..security import hash_password, new_accept_token, token_hash
from ..serializers import SECRET_FIELDS, now, to_oid, with_id

router = APIRouter(prefix="/admins", tags=["admins"])
public_router = APIRouter(tags=["admins"])


class AdminIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=120, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    phone: str | None = Field(default=None, max_length=30)
    password: str = Field(min_length=8, max_length=128)


def accept_url(token: str) -> str:
    base = get_settings().public_url.rstrip("/")
    return f"{base}/accept/{token}"


def _mail_body(name: str, email: str, password: str, url: str) -> tuple[str, str]:
    text = (
        f"Bonjour {name},\n\n"
        "Un compte administrateur Mangeoire Intelligente a été créé pour vous.\n\n"
        f"E-mail : {email}\n"
        f"Mot de passe temporaire : {password}\n\n"
        f"Pour accepter ce compte, ouvrez ce lien : {url}\n"
        "Vous devrez ensuite choisir un nouveau mot de passe à la première connexion.\n\n"
        "---\n"
        f"مرحبا {name}،\n"
        "تم إنشاء حساب مسؤول لك في تطبيق المغذي الذكي.\n"
        f"البريد الإلكتروني: {email}\n"
        f"كلمة المرور المؤقتة: {password}\n"
        f"للموافقة على الحساب افتح الرابط: {url}\n"
    )
    html = (
        f"<p>Bonjour <b>{escape(name)}</b>,</p>"
        "<p>Un compte administrateur <b>Mangeoire Intelligente</b> a été créé pour vous.</p>"
        f"<p>E-mail : <b>{escape(email)}</b><br>"
        f"Mot de passe temporaire : <b>{escape(password)}</b></p>"
        f'<p><a href="{escape(url)}" style="background:#1E5BD8;color:#fff;padding:12px 22px;'
        'border-radius:10px;text-decoration:none;font-weight:bold">Accepter le compte</a></p>'
        "<p>Vous choisirez un nouveau mot de passe à la première connexion.</p><hr>"
        f'<div dir="rtl"><p>مرحبا <b>{escape(name)}</b>،</p>'
        "<p>تم إنشاء حساب مسؤول لك في تطبيق المغذي الذكي.</p>"
        f"<p>البريد الإلكتروني: <b>{escape(email)}</b><br>"
        f"كلمة المرور المؤقتة: <b>{escape(password)}</b></p>"
        f'<p><a href="{escape(url)}">الموافقة على الحساب</a></p></div>'
    )
    return text, html


@router.post("", status_code=201)
async def create_admin(body: AdminIn, _: Principal = Depends(auth("superadmin"))):
    db = get_db()
    email = body.email.strip().lower()
    if await db.admins.find_one({"email": email}) or await db.superadmin.find_one({"email": email}):
        raise conflict("email_taken", "Cet e-mail est déjà utilisé")

    token = new_accept_token()
    doc = {
        "name": body.name.strip(),
        "email": email,
        "password_hash": await hash_password(body.password),
        "phone": body.phone,
        "must_change_password": True,
        "subscription_expires_at": None,  # starts when the admin accepts
        "status": "pending",
        "accept_token_hash": token_hash(token),
        "created_at": now(),
    }
    res = await db.admins.insert_one(doc)
    doc["_id"] = res.inserted_id

    url = accept_url(token)
    text, html = _mail_body(doc["name"], email, body.password, url)
    sent = await send_mail(email, "Votre compte Mangeoire Intelligente / حسابك في المغذي الذكي", text, html)
    out = with_id(doc, SECRET_FIELDS)
    out["email_sent"] = sent
    if not sent:  # no SMTP configured: the superadmin can pass the link on himself
        out["accept_url"] = url
    return out


@router.get("")
async def list_admins(status: str | None = None, _: Principal = Depends(auth("superadmin"))):
    query = {"status": status} if status in ("pending", "active", "suspended") else {}
    cursor = get_db().admins.find(query).sort("created_at", -1).limit(500)
    return [with_id(a, SECRET_FIELDS) for a in await cursor.to_list()]


@router.post("/{admin_id}/resend")
async def resend(admin_id: str, body: dict | None = None, _: Principal = Depends(auth("superadmin"))):
    """New acceptance link. The password is not stored in clear, so the superadmin
    must supply a new temporary one."""
    password = (body or {}).get("password", "")
    if not isinstance(password, str) or len(password) < 8:
        raise bad_request("weak_password", "Mot de passe temporaire (8 caractères minimum) requis")
    db = get_db()
    admin = await db.admins.find_one({"_id": to_oid(admin_id)})
    if admin is None:
        raise not_found()
    if admin.get("status") != "pending":
        raise bad_request("already_accepted", "Ce compte est déjà accepté")
    token = new_accept_token()
    await db.admins.update_one(
        {"_id": admin["_id"]},
        {
            "$set": {
                "accept_token_hash": token_hash(token),
                "password_hash": await hash_password(password),
                "must_change_password": True,
            }
        },
    )
    url = accept_url(token)
    text, html = _mail_body(admin["name"], admin["email"], password, url)
    sent = await send_mail(admin["email"], "Votre compte Mangeoire Intelligente / حسابك في المغذي الذكي", text, html)
    return {"email_sent": sent, **({} if sent else {"accept_url": url})}


@router.delete("/{admin_id}")
async def delete_pending_admin(admin_id: str, _: Principal = Depends(auth("superadmin"))):
    """Cancel an invitation that was not accepted yet."""
    res = await get_db().admins.delete_one({"_id": to_oid(admin_id), "status": "pending"})
    if res.deleted_count == 0:
        raise not_found("not_found", "Introuvable ou déjà accepté")
    return {"ok": True}


def _page(title_fr: str, title_ar: str, ok: bool) -> HTMLResponse:
    color = "#1E5BD8" if ok else "#D93025"
    html = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mangeoire Intelligente</title></head>
<body style="font-family:system-ui,sans-serif;background:#F3F7FF;margin:0;display:flex;
align-items:center;justify-content:center;min-height:100vh">
<div style="background:#fff;border-radius:18px;padding:32px 28px;max-width:420px;margin:16px;
text-align:center;box-shadow:0 6px 24px rgba(30,91,216,.15)">
<div style="font-size:44px;color:{color}">{'✔' if ok else '✖'}</div>
<h2 style="color:{color};margin:8px 0">{escape(title_fr)}</h2>
<p dir="rtl" style="font-size:18px;color:#333">{escape(title_ar)}</p>
</div></body></html>"""
    return HTMLResponse(html, status_code=200 if ok else 400)


@public_router.get("/accept/{token}", response_class=HTMLResponse)
async def accept(token: str):
    db = get_db()
    t = now()
    admin = await db.admins.find_one_and_update(
        {"accept_token_hash": token_hash(token), "status": "pending"},
        {
            "$set": {
                "status": "active",
                "accepted_at": t,
                "subscription_expires_at": t + timedelta(days=get_settings().subscription_days),
            },
            "$unset": {"accept_token_hash": ""},
        },
    )
    if admin is None:
        return _page("Lien invalide ou déjà utilisé", "الرابط غير صالح أو مستعمل", False)
    return _page(
        "Compte accepté ! Vous pouvez vous connecter à l'application.",
        "تمت الموافقة على الحساب! يمكنك الآن تسجيل الدخول إلى التطبيق.",
        True,
    )
