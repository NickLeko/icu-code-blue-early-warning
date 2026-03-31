# Change Policy for Sensitive Files

This repo is a scientific and portfolio artifact. Not all edits are equal.

## Routine Maintenance

Usually safe without scientific review:

- README and explanatory docs
- reviewer guidance
- reproducibility notes
- local smoke checks
- generated-output hygiene such as `.gitignore`
- helper scripts that do not modify canonical SQL semantics

## Scientific Changes

Treat as explicit scientific changes requiring review:

- edits to cohort inclusion or exclusion logic
- edits to label definitions or event-source matching
- edits to feature windows, parsing, or aggregation logic
- edits to train/validation/test split behavior
- edits to model specification or training options
- edits to alerting or evaluation methodology
- edits that would change reported metrics or claims

## High-Sensitivity SQL Files

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

## Required Practice

If you change one of the high-sensitivity files:

1. Treat it as a scientific edit, not cleanup.
2. Document the rationale separately from maintenance notes.
3. Re-run the relevant validation checks in `docs/validation_checklist.md`.
4. Reassess whether README, results summaries, or model-card claims need updating.

## Maintenance Boundary for Future Upgrade Passes

Routine maintenance should not be described as preserving scientific behavior if
it changes feature construction, labels, model inputs, evaluation outputs, or
reported results. Any such departure should be called out explicitly as a
scientific change.
