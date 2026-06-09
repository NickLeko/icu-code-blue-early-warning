## Methodology

This page is a concise scientific summary of the SQL pipeline. For exact
execution order and output table names, see `RUN.md`.

### Cohort
Adult ICU stays (age 18–120) with ≥6 hours ICU length of stay.

### Label Construction
The outcome is a documented code-event / resuscitation proxy label built from
treatment and diagnosis records containing CPR, defibrillation, ACLS, or
code-blue terminology.
To reduce contamination from pre-ICU events, ICU stays with qualifying events in
the first 6 hours are excluded from `labels_v2` and therefore from the
downstream dataset entirely.

The label timestamp is the diagnosis/treatment entry offset in eICU, not an
adjudicated bedside event time. The broad diagnosis string match also includes
ventricular tachycardia without separating pulseless VT from stable or monitored
VT, so the outcome should be interpreted as a chart-derived proxy rather than an
adjudicated cardiac-arrest endpoint.

### Temporal Alignment
All features at time t are computed using data from [t−6h, t).
Rows at or after the event time are excluded from training.
Prediction times are generated from 6 hours after ICU admission through
`unitdischargeoffset - 120` on an hourly grid, so the retrospective grid uses
future discharge time and does not score the final 2 hours of a stay.

### Splitting Strategy
Hospitals are assigned to train/validation/test splits using a hash-based
partition to assess cross-institution generalization. The current published repo
path trains one prespecified final model on `train`; the `val` split is
materialized but not consumed by a reproduced model-selection sweep.

### Evaluation
Given extreme class imbalance, models are evaluated using ranking-based metrics,
with primary emphasis on precision at fixed alert rates rather than default
classification thresholds.

The final reported model is the single vitals + labs logistic regression defined
in `sql/08_bqml_models.sql`.
