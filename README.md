# Smart Mangeoire: AI module (Phase 1)

Anomaly detector for the smart feeder project. It compares each cow's daily feeding behaviour
to **her own normal** (median and MAD over her last 7 normal days) and flags a deviation
that lasts. It does not diagnose illness.

## How it works

- `z = (x - median) / MAD` per feature, with MAD scaled by 1.4826.
- A feature deviates when `|z| >= 3` and the change is at least 20 %.
- Levels: `normal`, `watch` (one-day deviation), `alert` (same feature deviating 2+ days in a row).
- The first 7 days of each animal are `learning`: no alerts.
- Deviating days are not added to the baseline. A change lasting 7 days becomes the new normal.
- Features used for now: `total_consumed_g`, `nb_visits`.
- `anomaly_score` (0 to 1) is not defined yet and is returned as `null`.

## Files

| File | Role |
|---|---|
| `detector.py` | The detector (`detect_cow`), reusable on the Raspberry Pi |
| `simulate.py` | Builds 30-day histories from a one-row-per-cow dataset and injects labelled problems |
| `run_test.py` | Runs the simulator and the detector, then measures detections and false alarms |
| `test_summary.txt` | Result of the reference run (seed 42, 2000 cows) |
| `example_output.json` | One alert in the agreed JSON output format |

## Run the test

```
pip install pandas numpy
python run_test.py small.csv
```

`small.csv` is not included in this repository. It needs the columns
`Cattle_ID`, `Feed_Quantity_kg` and `Feeding_Frequency` (one row per cow).
The script writes `simulated_history.csv`, `detection_results.csv`, `test_summary.txt`
and `example_output.json` in the current folder.

## Reference results (simulated data)

- Hidden problems caught as an alert: 32 % (20 % feed drop), 90 % (35 %), 98 % (50 %).
- False alerts on normal days: 0.86 per 1000 cow-days. One-day glitches give a watch, almost never an alert.

## Limits

- The daily histories are simulated. The noise levels and problem shapes are assumptions, not measurements on real cows.
- The visit floor (`ABS_FLOOR`) was tuned on the same simulated data, so the scores are optimistic.
- All thresholds are starting values to recalibrate on real ESP32 data.
- A drop in feed can have other causes than illness: heat, new feed, a faulty scale.
