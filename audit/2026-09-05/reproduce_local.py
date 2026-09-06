"""Read-only aggregate reconciliation and synthetic SQL-boundary counterexamples.

Run: python3 audit/2026-09-05/reproduce_local.py
No patient data, network requests, or pipeline writes.
"""
import csv
import json
import math
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "artifacts/reference_run"


def read(name):
    with (REF / name).open() as f:
        return list(csv.DictReader(f))


counts = {(r["split"], r["metric"]): float(r["value"])
          for r in read("01_reference_run_counts.csv")}
op = {r["metric"]: float(r["value"])
      for r in read("02_reference_run_operating_point.csv")}
evaluation = read("05_reference_run_ml_evaluate.csv")[0]
n, k = int(op["test_rows"]), int(op["test_positive_rows"])
a, tp = int(op["alerts_top_0_5pct"]), int(op["positive_windows_top_0_5pct"])
p = k / n
q = counts["train", "n_positive_rows"] / counts["train", "n_rows"]
assert a == math.ceil(n / 200)
assert math.isclose(tp / a, op["precision_top_0_5pct"])
assert math.isclose((tp / a) / p, op["enrichment_top_0_5pct"])
assert sum(counts[s, "n_rows"] for s in ("train", "val", "test")) == counts["", "train_rows"]
assert sum(counts[s, "n_positive_rows"] for s in ("train", "val", "test")) == counts["", "positive_rows"]
assert len(read("04_reference_run_weights.csv")) == 50  # 49 features + intercept

def loss(prob):
    return -p * math.log(prob) - (1 - p) * math.log1p(-prob)

metrics = {
    "test_rows": n, "test_positive_windows": k,
    "test_prevalence": p, "top_alerts": a, "top_positive_windows": tp,
    "ppv": tp / a, "enrichment": (tp / a) / p,
    "raw_row_recall": tp / k, "false_positive_alert_rows": a - tp,
    "alerts_per_positive_window": a / tp,
    "all_negative_accuracy": 1 - p,
    "train_prevalence_constant_log_loss_on_test": loss(q),
    "test_prevalence_constant_log_loss_on_test_descriptive_only": loss(p),
    "model_log_loss": float(evaluation["log_loss"]),
    "model_loss_ratio_to_train_constant": float(evaluation["log_loss"]) / loss(q),
    "expected_positive_windows_in_10000_internal_rows": 10000 * q,
    "iid_binomial_illustration_P_zero_not_actual_split_count": (1 - q) ** 10000,
    "iid_binomial_illustration_P_le_2_not_actual_split_count": sum(
        math.comb(10000, j) * q**j * (1 - q)**(10000-j) for j in range(3)),
}
policies = []
for r in read("03_reference_run_alert_policy.csv"):
    alerts, positives = int(r["alerts"]), int(r["positive_windows"])
    assert math.isclose(positives / alerts, float(r["precision"]))
    assert math.isclose(alerts / a, float(r["alert_ratio_vs_naive"]))
    policies.append({"policy": r["policy"], "alerts": alerts,
                     "positive_windows": positives, "ppv": positives / alerts,
                     "fraction_test_rows": alerts / n,
                     "fraction_all_positive_rows_retained": positives / k,
                     "fraction_raw_alerts_removed": 1 - alerts / a,
                     "fraction_raw_positive_rows_removed": 1 - positives / tp})

# Execute the same integer predicates using SQLite. This is a counterexample
# to the boundary logic, not a claim to have executed BigQuery or eICU data.
db = sqlite3.connect(":memory:")
lab = db.execute("""
WITH fixture(t, draw, revised_entry, documented_event) AS
     (VALUES (600, 590, 660, 630))
SELECT draw >= t-360 AND draw < t AS accepted_by_current_lab_window,
       revised_entry < t AS value_available_before_prediction,
       documented_event > t AND documented_event <= t+120 AS y
FROM fixture
""").fetchone()
assert lab == (1, 0, 1)

def rows(discharge, event=None):
    return [(t, int(event is not None and t < event <= t + 120))
            for t in range(360, discharge - 120 + 1, 60)
            if event is None or t < event]

assert rows(479) == []
assert rows(480) == [(360, 0)]
assert rows(1200, 360) == []
assert sum(y for _, y in rows(1030, 1025)) == 0

crossings = [6, 16, 26]  # separated by non-alert rows
quiet = [h for i, h in enumerate(crossings) if i == 0 or h-crossings[i-1] >= 12]
cooldown = []
for h in crossings:
    if not cooldown or h-cooldown[-1] >= 12:
        cooldown.append(h)
assert quiet == [6] and cooldown == [6, 26]

# A hospital-only score can have 13.55x EXPECTED pooled lift despite no
# ranking ability within either hospital. These are invented counterexample
# counts, deliberately different from the reference run.
nh, kh, nl, kl, ah = 50000, 1355, 950000, 645, 5000
hospital_only_expected_lift = ((ah * kh / nh) / ah) / ((kh + kl) / (nh + nl))
assert math.isclose(hospital_only_expected_lift, 13.55)

print(json.dumps({"reference_calculations": metrics, "policies": policies,
                  "synthetic_counterexamples": {
                      "lab_window_accepts_future_entered_value": list(lab),
                      "six_to_under_eight_hour_stays_have_no_rows": True,
                      "event_at_minute_360_has_no_rows": True,
                      "D1030_E1025_has_zero_positive_rows": True,
                      "quiet_period_emissions": quiet,
                      "last_emitted_cooldown_emissions": cooldown,
                      "hospital_only_expected_pooled_lift": hospital_only_expected_lift}}, indent=2))
