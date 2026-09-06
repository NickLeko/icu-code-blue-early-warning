# Point-in-time corrected reference run — 2.0.0-pit

Executed in BigQuery using `bqml_lr_v4_pit` and `preds_test_v4_pit`.

The five CSVs are direct aggregate exports from `artifacts/queries/`.
Pooled enrichment is 23.223694x (95% hospital-cluster CI 11.452149–41.533945),
with 10,391 alerts, 36 true-positive proxy windows, 0.346454% PPV, and 11.612903%
positive-window recall. Within-hospital AUROC is 0.734822 row-weighted and
0.782711 median; positive alerts occur in 9/31 test hospitals. Log loss is
0.007776029, worse than the constant training-prevalence baseline 0.001502385.

Full old/new results, per-hospital AUROC/AP, policy results, Q1 exposure, exact
query hashes, job IDs, source metadata and known limitations are in
[`audit/2026-09-05/pit_v4/`](../../audit/2026-09-05/pit_v4/REPORT.md).
[`RUN_MANIFEST.json`](../../audit/2026-09-05/pit_v4/RUN_MANIFEST.json) binds the SQL
and output hashes. Original exports remain in `../reference_run/`.

The endpoint is a documentation proxy, not adjudicated cardiac arrest. No
patient-level rows are included. The numerical alert cutoff follows the same
fixed global percentile rule; it was not tuned against held-out outcomes.
