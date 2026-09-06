## Methodology

This page is a concise scientific summary of the SQL pipeline. For exact
execution order and output table names, see `RUN.md`.

### Cohort
Numeric age 18–120 with at least six hours of unit stay at cohort construction.
`SAFE_CAST` excludes top-coded `> 89` and other nonnumeric ages. SQL does not
filter `unittype`; a non-ICU exclusion must not be claimed. The hourly grid
starts at hour six and ends two hours before discharge, so a stay needs at
least eight hours to contribute a modeled row.

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
Vitals use offsets in `[t-360,t)`. Labs retain that specimen-draw lookback
and additionally require `GREATEST(labresultoffset, labresultrevisedoffset) < t`.
Both timestamps must be known; NULL revision timestamps exclude the record.
A later-revised stored value is withheld until its revision offset even if an
earlier value might have existed; the earlier version cannot be reconstructed.
"Last" means latest specimen draw among available values, with lab ID resolving
ties. Values entered exactly at t are unavailable for that prediction.
Rows at or after the event time are excluded from training.
Prediction times are generated from 6 hours after ICU admission through
`unitdischargeoffset - 120` on an hourly grid, so the retrospective grid uses
future discharge time and does not score the final 2 hours of a stay.

### Splitting Strategy
Hospitals are assigned to train/validation/test splits using a hash-based
partition to assess cross-institution generalization. Version `2.0.0-pit`
specifies `CUSTOM` splitting: `train` rows fit coefficients, all `val` rows
control early stopping, and `test` never enters model creation. `EARLY_STOP=TRUE`
and `MIN_REL_PROGRESS=0.01` are explicit, with the same 50-iteration cap and L2=1.
The historical v3 model used AUTO_SPLIT instead; its 444 positive hospital-val
windows were unused. New training completed after the owner enabled billing; the actual BQML evaluation table contains all 444 validation positives.

### Evaluation
Given extreme class imbalance, models are evaluated using ranking-based metrics,
with primary emphasis on precision in the corpus-wide top 0.5% of held-out test
rows rather than default classification thresholds. This is a retrospective
percentile, not a per-shift or per-census operational budget.

The final reported model is the single vitals + labs logistic regression defined
in `sql/08_bqml_models.sql`.

Hospital uncertainty uses 100,000 whole-hospital bootstrap resamples with fixed
observed alert memberships (seed 20260905). Within-hospital AUROC handles score
ties with half credit; AP groups tied scores before calculating precision.
Log loss assesses probabilistic prediction quality and is compared against a
constant probability estimated only from training labels. It is not a ranking
metric. The endpoint remains a documentation proxy, not adjudicated cardiac arrest.
