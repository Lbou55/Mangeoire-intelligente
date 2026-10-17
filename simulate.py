"""Simulator: builds a 30-day daily history per cow from small.csv.

small.csv has ONE row per cow, so there is no history to test a per-cow baseline.
We take each cow's real values (Feed_Quantity_kg, Feeding_Frequency) as her "normal"
and generate daily values around them with natural noise.

Some cows get a labelled problem (feed and visits drop for 2 to 4 days),
some get a one-day glitch (should NOT raise an alert), the rest stay normal.

All noise levels below are ASSUMPTIONS, not measured on real cows.
"""
import numpy as np
import pandas as pd


def simulate(csv_path, n_cows=2000, n_days=30, seed=42,
             anomaly_frac=0.30, glitch_frac=0.10, start_date="2026-09-01"):
    rng = np.random.default_rng(seed)
    src = pd.read_csv(csv_path, usecols=["Cattle_ID", "Feed_Quantity_kg", "Feeding_Frequency"])
    cows = src.sample(n_cows, random_state=seed).reset_index(drop=True)
    dates = pd.date_range(start_date, periods=n_days, freq="D")

    frames = []
    for _, cow in cows.iterrows():
        base_feed_g = cow.Feed_Quantity_kg * 1000.0
        base_visits = float(cow.Feeding_Frequency)

        # Natural daily variation (assumption): feed varies 4 to 10 % per cow
        feed_sd = rng.uniform(0.04, 0.10)
        feed = base_feed_g * (1 + rng.normal(0, feed_sd, n_days))
        visits = np.maximum(0, np.round(base_visits + rng.normal(0, 0.7, n_days)))

        truth = np.array(["normal"] * n_days, dtype=object)
        cow_type, severity, start, duration = "normal", 0.0, -1, 0

        r = rng.random()
        if r < anomaly_frac:
            cow_type = "anomaly"
            severity = float(rng.choice([0.20, 0.35, 0.50]))
            duration = int(rng.integers(2, 5))                 # 2 to 4 days
            start = int(rng.integers(10, n_days - duration))   # after the 7-day learning period
            sl = slice(start, start + duration)
            feed[sl] = feed[sl] * (1 - severity)
            visits[sl] = np.round(visits[sl] * 0.5)
            truth[sl] = "anomaly"
        elif r < anomaly_frac + glitch_frac:
            cow_type = "glitch"                                # one bad day (broken scale, recharge error)
            start = int(rng.integers(10, n_days))
            duration = 1
            feed[start] = feed[start] * 0.5
            truth[start] = "glitch"

        frames.append(pd.DataFrame({
            "animal_id": cow.Cattle_ID,
            "date": dates,
            "total_consumed_g": np.round(feed, 0),
            "nb_visits": visits.astype(int),
            "cow_type": cow_type,
            "truth": truth,
            "severity": severity,
            "problem_start_day": start,
            "problem_days": duration,
        }))
    return pd.concat(frames, ignore_index=True)
