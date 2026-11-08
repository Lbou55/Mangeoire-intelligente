"""Pure helpers (no database, no FastAPI) so they are easy to test."""

LEVELS = ("normal", "alerte", "danger")

ALERT_REASONS = {
    "mange_moins": "Mange moins que d'habitude",
    "boite": "Boite / marche difficilement",
    "fatiguee": "Semble fatiguée",
    "loin_mangeoire": "Ne vient pas à la mangeoire",
    "toux": "Toux ou respiration difficile",
    "autre": "Autre",
}
DANGER_EXTRA = {
    "ne_leve_pas": "Ne se lève pas",
    "blessure": "Blessure visible",
    "fievre": "Signes de fièvre",
    "ballonnement": "Ballonnement",
}
DANGER_REASONS = {**ALERT_REASONS, **DANGER_EXTRA}
ALL_LABELS = DANGER_REASONS


def allowed_reasons(level: str) -> set[str]:
    return set(DANGER_REASONS) if level == "danger" else set(ALERT_REASONS)


def check_reasons(level: str, reasons: list[str]) -> list[str]:
    """Return the cleaned list (no duplicates) or raise ValueError."""
    ok = allowed_reasons(level)
    out: list[str] = []
    for r in reasons:
        if r not in ok:
            raise ValueError(f"motif inconnu pour le niveau {level}: {r}")
        if r not in out:
            out.append(r)
    if not out:
        raise ValueError("choisissez au moins un motif")
    return out


def reasons_text(reasons: list[str]) -> str:
    return ", ".join(ALL_LABELS.get(r, r) for r in reasons)


def level_from_ai(alert: bool, p_flagged: float | None, threshold: float) -> str:
    """AI verdict -> normal / alerte / danger."""
    if not alert:
        return "normal"
    if p_flagged is not None and p_flagged >= threshold:
        return "danger"
    return "alerte"


def cow_label(cow: dict) -> str:
    name = (cow.get("name") or "").strip()
    return f'{name} ({cow["_id"]})' if name else cow["_id"]
