## Results Summary

This repo publishes one fixed final-model path: the vitals + labs logistic
regression defined in `sql/08_bqml_models.sql`.

The checked-in corrected reference export lives in `artifacts/reference_run/`
and is derived from the final model artifact `bqml_lr_v3` plus the held-out
prediction table `preds_test_v3`.

The checked-in aggregates are internally consistent, but they carry no shared
run ID or source-snapshot binding, so single-run provenance cannot be proven
from the checked-in artifacts alone.

This repo does **not** currently publish reproducible benchmark comparisons for
alternative model versions, trend-feature variants, or random-split baselines,
so those comparisons are intentionally omitted from the current results summary.

### Internally Consistent Reference-Run Metrics

- Cohort: 177,418 ICU stays
- Labeled stays: 171,833, including 1,401 proxy-positive stays (0.815% stay-level prevalence)
- Hospital split: 135 train hospitals, 42 validation hospitals, 31 test hospitals
- Held-out test rows: 2,078,011 patient-hours with 310 positive labeled windows
  (0.0149% row prevalence)
- Held-out `ML.EVALUATE`: ROC-AUC 0.6377, log loss 0.002723
- Retrospective corpus-wide operating point at top 0.5% of test rows: 10,391 alerts, 21 positive labeled
  windows, 0.2021% precision, 13.55x enrichment over test prevalence
- First-crossing alert policy: 3,350 alerts, 8 positive labeled windows,
  0.2388% precision
- 12-hour quiet-period-debounced first-crossing (suppressed crossings reset the
  window): 2,650 alerts, 7 positive labeled windows, 0.2642% precision

**Persistence-tier analysis: WITHDRAWN.** The tier classification logic was
found defective in review and results will be republished after regeneration.

These counts are row-level proxy-label results, not deduplicated clinical
events and not prospective workflow outcomes.

### Reference Files

- `artifacts/reference_run/01_reference_run_counts.csv`
- `artifacts/reference_run/02_reference_run_operating_point.csv`
- `artifacts/reference_run/03_reference_run_alert_policy.csv`
- `artifacts/reference_run/04_reference_run_weights.csv`
- `artifacts/reference_run/05_reference_run_ml_evaluate.csv`

The canonical evaluation queries are:

- `sql/09_eval_alert_rate.sql` for precision in the corpus-wide top 0.5% of test rows
- `sql/10_eval_temporal_alert_tiers.sql` for the corrected persistence-tier analysis pending regeneration
- `sql/11_eval_first_crossing_cooldown.sql` for first-crossing quiet-period-debounce analysis
