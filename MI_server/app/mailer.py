"""Minimal SMTP sender (stdlib only). Never raises: returns True/False."""
import asyncio
import logging
import smtplib
from email.message import EmailMessage

from .config import get_settings

log = logging.getLogger("mailer")


def _send(to: str, subject: str, text: str, html: str | None) -> None:
    s = get_settings()
    msg = EmailMessage()
    msg["From"] = s.smtp_from or s.smtp_user
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(text)
    if html:
        msg.add_alternative(html, subtype="html")
    with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=20) as smtp:
        smtp.starttls()
        smtp.login(s.smtp_user, s.smtp_pass)
        smtp.send_message(msg)


def configured() -> bool:
    s = get_settings()
    return bool(s.smtp_host and s.smtp_user and s.smtp_pass)


async def send_mail(to: str, subject: str, text: str, html: str | None = None) -> bool:
    if not configured():
        log.warning("SMTP not configured - e-mail to %s not sent", to)
        return False
    try:
        await asyncio.to_thread(_send, to, subject, text, html)
        return True
    except Exception as exc:  # noqa: BLE001
        log.error("e-mail to %s failed: %s", to, exc)
        return False
