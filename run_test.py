"""Run the simulator, run the detector on every cow, measure detections and false alarms.

Usage: python3 -I run_test.py <path to small.csv> [output_dir]
"""
import sys
import json
import pandas as pd

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from simulate import simulate
from detector import detect_cow


def main(csv_path, out_dir="."):
    hist = simulate(csv_path)
    results = []
    for _, g in hist.groupby("animal_id", sort=False):
        g = g.sort_values("date")
        recs = detect_cow(g)
        for rec, t in zip(recs, g.itertuples(index=False)):
            results.append({
                "animal_id": rec["animal_id"], "date": rec["date"], "status": rec["status"],
                "level": rec["level"],
                "features": ",".join(i["feature"] for i in rec["indicators"]),
                "truth": t.truth, "cow_type": t.cow_type, "severity": t.severity,
                "problem_start_day": t.problem_start_day, "problem_days": t.problem_days,
                "day_index": (pd.Timestamp(rec["date"]) - g.date.min()).days,
            })
    res = pd.DataFrame(results)
    hist.to_csv(f"{out_dir}/simulated_history.csv", index=False)
    res.to_csv(f"{out_dir}/detection_results.csv", index=False)

    lines = []
    n_cows = res.animal_id.nunique()
    lines.append(f"Simulated cows: {n_cows}, days per cow: {res.groupby('animal_id').size().iloc[0]}")
    lines.append(f"Cow types: {res.drop_duplicates('animal_id').cow_type.value_counts().to_dict()}")

    # 1) Hidden problems: was an ALERT raised during the problem days?
    an = res[res.cow_type == "anomaly"]
    rows = []
    for aid, g in an.groupby("animal_id"):
        p = g[g.truth == "anomaly"]
        alert_days = p[p.level == "alert"]
        any_flag = p[p.level.isin(["watch", "alert"])]
        start = int(g.problem_start_day.iloc[0])
        rows.append({"animal_id": aid, "severity": g.severity.iloc[0],
                     "problem_days": int(g.problem_days.iloc[0]),
                     "alert": len(alert_days) > 0, "watch_or_alert": len(any_flag) > 0,
                     "delay_days": (int(alert_days.day_index.min()) - start) if len(alert_days) else None})
    ev = pd.DataFrame(rows)
    lines.append("\nHIDDEN PROBLEMS (detected = alert raised during the problem days)")
    lines.append(f"Overall: alert in {ev.alert.mean()*100:.1f}% of cows, watch-or-alert in {ev.watch_or_alert.mean()*100:.1f}%")
    by = ev.groupby("severity").agg(cows=("alert", "size"), alert_pct=("alert", lambda s: s.mean()*100),
                                    watch_or_alert_pct=("watch_or_alert", lambda s: s.mean()*100),
                                    mean_delay_days=("delay_days", "mean")).round(1)
    lines.append("By severity (feed drop):\n" + by.to_string())
    byd = ev.groupby("problem_days").agg(cows=("alert", "size"), alert_pct=("alert", lambda s: s.mean()*100)).round(1)
    lines.append("By problem length (days):\n" + byd.to_string())

    # 2) False alarms on days with no problem
    ok = res[res.status == "ok"]
    clean = ok[ok.truth == "normal"]
    lines.append("\nFALSE ALARMS (days with no injected problem, after the 7-day learning period)")
    lines.append(f"Alert days: {(clean.level=='alert').sum()} of {len(clean)} "
                 f"= {(clean.level=='alert').mean()*1000:.2f} per 1000 cow-days")
    lines.append(f"Watch days: {(clean.level=='watch').sum()} of {len(clean)} "
                 f"= {(clean.level=='watch').mean()*1000:.2f} per 1000 cow-days")
    nc = ok[ok.cow_type == "normal"]
    lines.append(f"Normal cows with at least one alert: {nc[nc.level=='alert'].animal_id.nunique()} of {nc.animal_id.nunique()}")
    lines.append(f"Normal cows with at least one watch: {nc[nc.level=='watch'].animal_id.nunique()} of {nc.animal_id.nunique()}")

    # 3) One-day glitches: should not become alerts
    gl = ok[ok.cow_type == "glitch"]
    gd = gl[gl.truth == "glitch"]
    lines.append("\nONE-DAY GLITCHES (should give watch at most, never alert)")
    lines.append(f"Glitch days: {len(gd)}; flagged watch: {(gd.level=='watch').sum()}, flagged alert: {(gd.level=='alert').sum()}, "
                 f"missed: {(gd.level=='normal').sum()}")
    lines.append(f"Alert days anywhere in glitch cows: {(gl.level=='alert').sum()}")

    # 4) Which feature raises the alarms?
    al = ok[(ok.level == "alert")]
    feats = al.features.str.split(",").explode().value_counts().to_dict()
    lines.append(f"\nFeatures present on alert days: {feats}")

    summary = "\n".join(lines)
    open(f"{out_dir}/test_summary.txt", "w").write(summary + "\n")
    print(summary)

    # one example of the agreed JSON output (first alert found)
    ex = an[an.level == "alert"].head(1)
    if len(ex):
        g = hist[hist.animal_id == ex.animal_id.iloc[0]].sort_values("date")
        recs = detect_cow(g)
        alert_rec = next(r for r in recs if r["level"] == "alert")
        open(f"{out_dir}/example_output.json", "w").write(json.dumps(alert_rec, indent=2, default=str))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ".")
