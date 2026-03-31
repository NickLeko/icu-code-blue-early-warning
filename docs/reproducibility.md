# Reproducibility and Maintenance Notes

## Scope

This repository is designed to be reproducible as a BigQuery-first SQL pipeline over credentialed eICU-CRD access. It is also intended to remain legible as a portfolio artifact, so this document separates low-risk maintenance work from scientifically sensitive code.

## What Reproducibility Means Here

Reproducibility in this repo means:

- the SQL pipeline can be run in a fixed order against the same source dataset
- the cohort, labels, features, splits, model, and evaluation tables are clearly named
- the reported metrics can be traced to concrete evaluation queries
- reviewer-facing aggregate exports can be regenerated from checked-in artifact queries
- documentation states what was intentionally not changed

It does not mean bit-for-bit portability across arbitrary environments, because the project depends on:

- BigQuery execution
- PhysioNet-controlled data access
- the schema and contents of `physionet-data.eicu_crd.*`

## Environment Assumptions

- BigQuery is the execution environment
- Input data live in `physionet-data.eicu_crd.*`
- Output dataset is assumed to be `{{PROJECT_ID}}.icu_ml`
- SQL files are run manually in numeric order unless you create your own orchestration wrapper

There is no Python training package in this repo. That is intentional; the project’s executable artifact is the SQL pipeline itself.
The current published path is one prespecified final model, not a reproduced
benchmark sweep.

## Scientific Sensitivity Zones

The following files should be treated as high-sensitivity because even small edits could change data semantics, model behavior, or reported results:

- `sql/01_cohort.sql`
- `sql/02_labels.sql`
- `sql/03_features_vitals.sql`
- `sql/04_features_labs.sql`
- `sql/05_train_rows.sql`
- `sql/06_splits.sql`
- `sql/08_bqml_models.sql`
- `sql/09_eval_alert_rate.sql`
- `sql/10_eval_temporal_alert_tiers.sql`
- `sql/11_eval_first_crossing_cooldown.sql`

Safe maintenance work is usually limited to:

- README and explanatory docs
- execution instructions
- comments that do not alter SQL semantics
- lightweight repo validation scripts
- artifact naming clarification in docs

See also `docs/change_policy.md` for the maintenance boundary and review expectations around sensitive files.

## Artifact Provenance

Core output objects produced by the pipeline:

| Step | Artifact |
|---|---|
| Cohort | `{{PROJECT_ID}}.icu_ml.cohort_v1` |
| Labels | `{{PROJECT_ID}}.icu_ml.labels_v2` |
| Vitals features | `{{PROJECT_ID}}.icu_ml.features_v2` |
| Final features | `{{PROJECT_ID}}.icu_ml.features_v3` |
| Timepoint rows | `{{PROJECT_ID}}.icu_ml.train_rows_v3` |
| Split map | `{{PROJECT_ID}}.icu_ml.split_hospital_v1` |
| Model table | `{{PROJECT_ID}}.icu_ml.model_table_v3` |
| Trained model | `{{PROJECT_ID}}.icu_ml.bqml_lr_v3` |
| Test predictions | `{{PROJECT_ID}}.icu_ml.preds_test_v3` |

Reported result summaries in the README and `docs/results.md` are derived from these artifacts and the evaluation SQL files.
Aggregate-only reviewer exports are generated separately from `artifacts/queries/`,
and the current checked-in reference bundle lives in `artifacts/reference_run/`.

## Manual Verification Checklist

Recommended checks after key steps:

1. After `sql/02_labels.sql`, inspect positive prevalence and event-time plausibility.
2. After `sql/05_train_rows.sql`, inspect row-level prevalence and confirm rows at or after the event are excluded.
3. After `sql/06_splits.sql`, inspect train/val/test hospital counts.
4. After `sql/07_model_table.sql`, inspect row counts and positive counts per split.
5. After `sql/09_eval_alert_rate.sql`, export alert volume and precision at top 0.5% with `artifacts/queries/02_reference_run_operating_point.sql`.

These checks are intentionally manual in this repo to keep the project lightweight and transparent.

## Known Reproducibility Gaps

- No one-command orchestration wrapper is provided
- No automated BigQuery integration test is included
- No frozen source snapshot of eICU is possible within the repo
- Reported results are documented, but not regenerated automatically inside CI
- Validation splits are materialized, but the current published path does not implement a reproduced validation-based model-selection sweep

These are acceptable tradeoffs for a portfolio artifact, but they should be stated explicitly.

## Maintenance Principle

If a future edit could alter cohort membership, label definition, feature meaning, split logic, model specification, thresholding, or evaluation methodology, it should be treated as a scientific change rather than routine maintenance.
