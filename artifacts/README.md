# Proof Artifacts

These queries generate **aggregate-only** reviewer exports after the BigQuery
pipeline has been run. They are the intended proof surface for the repo's main
reported numbers.

The current checked-in evidence pack from the corrected rerun lives in
`artifacts/reference_run/`. The queries here are how that bundle is regenerated.

Run them after `sql/11_eval_first_crossing_cooldown.sql`:

1. `artifacts/queries/01_reference_run_counts.sql`
2. `artifacts/queries/02_reference_run_operating_point.sql`
3. `artifacts/queries/03_reference_run_alert_policy.sql`
4. `artifacts/queries/04_reference_run_weights.sql`
5. `artifacts/queries/05_reference_run_ml_evaluate.sql`

The queries only return aggregate counts / metrics or model weights. They do
not export patient-level rows.
