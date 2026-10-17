"""Phase 1 detector: compares each cow to HER OWN last 7 normal days.

z = (x - median) / MAD   (MAD scaled by 1.4826 so it is comparable to a standard deviation)

Rules (all are starting values to calibrate on real data):
  - at least 7 baseline days before any alert  -> status "learning" until then
  - a feature deviates when |z| >= Z_THRESHOLD AND |deviation| >= MIN_DEV_PCT
  - level "watch" = a deviation on one day, "alert" = same feature deviating 2+ days in a row
  - days flagged as deviating are NOT added to the baseline, so a problem does not
    contaminate the cow's "normal". If a change lasts 7 days it becomes the new normal.

anomaly_score is left empty on purpose: how z becomes a 0-1 score is not defined yet.
"""
import numpy as np

FEATURES = ["total_consumed_g", "nb_visits"]
WINDOW = 7
Z_THRESHOLD = 3.0
MIN_DEV_PCT = 20.0
ALERT_PERSISTENCE = 2

# Minimum "typical variation", so a very regular cow does not give an infinite z
REL_FLOOR = {"total_consumed_g": 0.03, "nb_visits": 0.0}   # share of the median
ABS_FLOOR = {"total_consumed_g": 0.0, "nb_visits": 1.0}


def robust_baseline(values, feature):
    values = np.asarray(values, dtype=float)
    med = float(np.median(values))
    mad = 1.4826 * float(np.median(np.abs(values - med)))
    sigma = max(mad, REL_FLOOR[feature] * abs(med), ABS_FLOOR[feature])
    return med, sigma


def detect_cow(df, window=WINDOW, z_thr=Z_THRESHOLD, min_dev_pct=MIN_DEV_PCT,
               alert_persistence=ALERT_PERSISTENCE, features=FEATURES):
    """df: one cow, sorted by date, columns: animal_id, date, + FEATURES.
    Returns a list of records (one per day) shaped like the agreed JSON output."""
    accepted = []                      # list of {feature: value} for non-deviating days
    persist = {f: 0 for f in features}  # consecutive deviating days per feature
    day_persist = 0                    # consecutive days with any deviation
    recent = []                        # last `window` days, accepted or not
    out = []

    for row in df.itertuples(index=False):
        x = {f: getattr(row, f) for f in features}
        rec = {"animal_id": row.animal_id, "date": str(row.date)[:10]}

        if any(v is None or (isinstance(v, float) and np.isnan(v)) for v in x.values()):
            rec.update(status="insufficient_data", anomaly_score=None, level=None,
                       indicators=[], baseline_days=len(accepted), message=None)
            out.append(rec)
            continue

        recent.append(x)
        recent = recent[-window:]

        if len(accepted) < window:
            accepted.append(x)
            rec.update(status="learning", anomaly_score=None, level=None,
                       indicators=[], baseline_days=len(accepted), message=None)
            out.append(rec)
            continue

        base_rows = accepted[-window:]
        indicators = []
        for f in features:
            med, sigma = robust_baseline([r[f] for r in base_rows], f)
            z = (x[f] - med) / sigma
            dev_pct = (x[f] - med) / med * 100 if med else 0.0
            if abs(z) >= z_thr and abs(dev_pct) >= min_dev_pct:
                persist[f] += 1
                indicators.append({"feature": f, "value": x[f], "baseline": round(med, 1),
                                   "deviation_pct": round(dev_pct, 1), "z": round(z, 2),
                                   "days_persisting": persist[f]})
            else:
                persist[f] = 0

        if indicators:
            day_persist += 1
            if max(i["days_persisting"] for i in indicators) >= alert_persistence:
                level = "alert"
                message = ("Persistent deviation from this animal's normal. "
                           "Indicator to follow, this is not a diagnosis.")
            else:
                level = "watch"
                message = "One-day deviation from this animal's normal. To watch."
            if day_persist >= window:      # a change lasting a full window becomes the new normal
                accepted = list(recent)
                day_persist = 0
        else:
            day_persist = 0
            level = "normal"
            message = None
            accepted.append(x)

        rec.update(status="ok", anomaly_score=None, level=level, indicators=indicators,
                   baseline_days=min(len(accepted), window), message=message)
        out.append(rec)
    return out
