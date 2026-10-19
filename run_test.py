"""Run the simulator and detector, and print a simple Scorecard."""
import sys
import json
import pandas as pd

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from simulate import simulate
from detector import detect_cow

def main(csv_path, out_dir="."):
    hist = simulate(csv_path)
    results = []
    
    # 1. Run detector on every cow
    for _, g in hist.groupby("animal_id", sort=False):
        g = g.sort_values("date")
        recs = detect_cow(g)
        for rec, t in zip(recs, g.itertuples(index=False)):
            results.append({
                "animal_id": rec["animal_id"], "date": rec["date"], "status": rec["status"],
                "level": rec["level"], "features": ",".join(i["feature"] for i in rec["indicators"]),
                "truth": t.truth, "cow_type": t.cow_type, "severity": t.severity,
                "problem_start_day": t.problem_start_day, "problem_days": t.problem_days,
                "day_index": (pd.Timestamp(rec["date"]) - g.date.min()).days,
            })
    res = pd.DataFrame(results)
    
    # Save the detailed CSVs just in case
    hist.to_csv(f"{out_dir}/simulated_history.csv", index=False)
    res.to_csv(f"{out_dir}/detection_results.csv", index=False)

    # ==========================================
    # BUILD THE SIMPLE SCORECARD
    # ==========================================
    print("="*40)
    print("           DETECTION SCORECARD")
    print("="*40)
    
    n_cows = res.animal_id.nunique()
    print(f"Total Cows Tested: {n_cows}")
    print(f"Days per Cow:      {res.groupby('animal_id').size().iloc[0]}\n")

    # 1. Real Problems (Anomalies)
    an = res[res.cow_type == "anomaly"]
    an_problem_days = an[an.truth == "anomaly"]
    an_alerts = an_problem_days[an_problem_days.level == "alert"]
    an_any_flag = an_problem_days[an_problem_days.level.isin(["watch", "alert"])]
    
    cows_caught = an[an.level == "alert"].animal_id.nunique()
    total_an_cows = an.animal_id.nunique()
    
    print("🚨 REAL PROBLEMS (Feed Drop):")
    print(f"  - Sick Cows:          {total_an_cows}")
    print(f"  - Cows with an Alert: {cows_caught} ({(cows_caught/total_an_cows)*100:.1f}%)")
    print(f"  - Sick Days Flagged:  {len(an_any_flag)} out of {len(an_problem_days)} ({(len(an_any_flag)/len(an_problem_days))*100:.1f}%)")
    print()

    # 2. False Alarms (Normal cows)
    ok = res[res.status == "ok"]
    clean = ok[ok.truth == "normal"]
    clean_alerts = clean[clean.level == "alert"]
    clean_watches = clean[clean.level == "watch"]
    nc = ok[ok.cow_type == "normal"]
    cows_false_alarm = nc[nc.level == "alert"].animal_id.nunique()
    
    print("✅ NORMAL DAYS (False Alarms):")
    print(f"  - Normal Days Tested: {len(clean)}")
    print(f"  - False Alerts:       {len(clean_alerts)} ({(len(clean_alerts)/len(clean))*1000:.2f} per 1000 days)")
    print(f"  - False Watches:      {len(clean_watches)} ({(len(clean_watches)/len(clean))*1000:.2f} per 1000 days)")
    print(f"  - Healthy Cows that got a False Alert: {cows_false_alarm} out of {nc.animal_id.nunique()}")
    print()

    # 3. One-Day Glitches
    gl = ok[ok.cow_type == "glitch"]
    gd = gl[gl.truth == "glitch"]
    gl_alerts = (gd.level == "alert").sum()
    gl_watches = (gd.level == "watch").sum()
    
    print("⚠️ ONE-DAY GLITCHES (Should NOT be an Alert):")
    print(f"  - Total Glitch Days:  {len(gd)}")
    print(f"  - Caught as 'Watch':  {gl_watches}")
    print(f"  - False 'Alerts':     {gl_alerts} (Goal is 0)")
    print("="*40)

    # Save example JSON
    ex = an[an.level == "alert"].head(1)
    if len(ex):
        g = hist[hist.animal_id == ex.animal_id.iloc[0]].sort_values("date")
        recs = detect_cow(g)
        alert_rec = next(r for r in recs if r["level"] == "alert")
        open(f"{out_dir}/example_output.json", "w").write(json.dumps(alert_rec, indent=2, default=str))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ".")
