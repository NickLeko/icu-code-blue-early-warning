# Point-in-time correction and held-out rerun — 2.0.0-pit

Audit started: 2026-09-05; completed: 2026-09-06. Project: `citric-glow-485600-f4.icu_ml`, US.
Status: **executed**. Source SQL is on branch `codex/pit-v4`; new BigQuery objects
use suffix `v4_pit` because a historical `v4` already exists. The original v3/v4
outputs and original aggregate bundle were preserved. No threshold, cutoff,
feature-set, or model-selection sweep was performed.

## Finding before regeneration

**High severity, confirmed and fixed:** specimen draw time alone admitted lab
values that had not yet been entered/revised at prediction time. Original Q1
ran before regeneration against `model_table_v3` and found **574,482 exposed
modeled patient-hours**, including **106,328 test rows and 35 of the 310 positive
test windows**. Ten of those positive test windows included a value entered at
or after proxy documentation time. This exposure exists regardless of the
rerun's higher enrichment.

| Split | Exposed modeled rows | Exposed positive windows | Lab-window pairs removed |
|---|---:|---:|---:|
| Train | 373,376 | 205 | 985,221 |
| Validation | 94,778 | 47 | 253,518 |
| Test | 106,328 | 35 | 272,369 |
| Total | 574,482 | 287 | 1,511,108 |

Reproduction: [exact original Q1](q1_reference_exposure.sql),
[raw response](q1_reference_exposure_result.json), job
`job_D9n76_NX6V31xVKJvlcJsCYcmHyL`. These are feature rows and lab-window
contributions, not unique lab records or cardiac-arrest events. No contributing
numeric lab record in these modeled rows had a NULL revision offset.

## Exact corrected boundary

`sql/04_features_labs.sql` retains draw time in `[t-360,t)` and requires
`GREATEST(labresultoffset, labresultrevisedoffset) < t`. Both timestamps must be
known. A NULL revision timestamp excludes that record rather than assuming it
was available at draw time. This is conservative: a later final revision cannot
be used as a substitute for an earlier value whose version is unavailable.
"Last" continues to mean latest draw among available records, with lab ID
breaking draw-time ties. Entry exactly at t is excluded. This matches the
[source lab-offset definitions](https://eicu.mit.edu/eicutables/lab/), while
acknowledging that revision time is not a complete value-version history.

The label boundary is unchanged: only `t < event_offset_min <= t+120` is positive;
post-proxy rows are removed. Lab availability is enforced in SQL before any
feature aggregation, not merely described in prose. This fixes availability
relative to proxy-documentation prediction time; it cannot establish true
clinical lead time when the clinical event precedes its documentation.

[The nine-case boundary fixture](boundary_fixture.sql) passed in BigQuery.
[The full feature reconciliation](feature_reconciliation.sql) matched Q1 in
every split/label stratum, with zero missing keys, label/split changes, increases
in lab counts, or changes to vital features. A separate read-only execution of
the exact new feature SELECT gave the same removal counts before materialization.


### Reconciled inherited tie-breaking difference

The new SQL already contained deterministic `ORDER BY labresultoffset DESC,
labid DESC` before this pass, while the historical v3 export predates that
change. [The additional reconciliation](last_value_reconciliation.sql) found
**7,823 modeled rows / 8,761 last-value feature cells** changed outside Q1's
lab-count exposure: 4,432 training rows, 1,922 validation rows, and **1,469 test
rows (including one positive window)**. This is separate from the 574,482 Q1
exposed rows.

[The source-row tie explanation](last_value_tie_explanation.sql) verified every
case: multiple different numeric values shared the latest draw offset, the old
value belonged to that tie, and the new value matched the highest lab ID.
There were **zero unexplained feature cells**. No tie rule was changed in this
pass. Consequently, old v3 versus new reflects the PIT fix, the inherited tie
rule becoming effective on regeneration, and the explicit validation split;
it is not a pure estimate of the PIT fix alone. The final/control comparison
still uses identical new features and isolates the specified split choice.

## Old versus new held-out results

| Metric | Original v3 | PIT + CUSTOM final |
|---|---:|---:|
| Test hospitals | 31 | 31 |
| Test patient-hours | 2,078,011 | 2,078,011 |
| Positive windows | 310 | 310 |
| Test prevalence | 0.014918% | 0.014918% |
| Raw global top-0.5% alerts | 10,391 | 10,391 |
| True-positive windows | 21 | 36 |
| PPV | 0.2021% | 0.3465% |
| Positive-window recall | 6.7742% | 11.6129% |
| Pooled enrichment | 13.55x | 23.22x |
| 95% hospital-cluster enrichment CI | 7.20–27.03 | 11.45–41.53 |
| Within-hospital AUROC, row-weighted | 0.6110 | 0.7348 |
| Within-hospital AUROC, median | 0.6887 | 0.7827 |
| Within-hospital AUROC >0.5 | 19/21 | 19/21 |
| Within-hospital AUROC ≥0.6 | 13/21 | 18/21 |
| Within enrichment, row-weighted (defined hospitals) | 20.25x (19) | 22.89x (20) |
| Within enrichment, alert-weighted | 15.44x | 22.91x |
| Within enrichment, median (defined hospitals) | 0 | 0 |
| Hospital-mix expected TP | 1.179374 | 1.443294 |
| Observed / hospital-mix expected | 17.81x | 24.94x |
| 95% hospital-cluster mix-adjusted ratio CI | 10.07–33.65 | 12.49–40.19 |
| Hospital-mix enrichment factor | 0.7608 | 0.9311 |
| Hospitals with positive alerts | 7/31 | 9/31 |
| Hospitals with zero alerts | 7/31 | 7/31 |
| Hospitals with zero positives | 10/31 | 10/31 |
| Detected unique proxy stays / evaluable stays | 14/160 | 22/160 |
| High-prevalence hospitals: share of all rows | 50.83% | 50.83% |
| High-prevalence hospitals: share of alerts | 38.24% | 43.19% |
| Top-five alert hospitals: share of alerts | 86.25% | 77.02% |
| Top-five alert hospitals: share of rows | 60.75% | 64.77% |
| Global BQML ROC-AUC | 0.6377 | 0.7292 |
| Held-out log loss | 0.002723 | 0.007776 |
| Constant training-prevalence log loss | 0.001502 | 0.001502 |
| First crossing: alerts / TP / PPV | 3,350 / 8 / 0.2388% | 2,040 / 8 / 0.3922% |
| 12h quiet-period debounce: alerts / TP / PPV | 2,650 / 7 / 0.2642% | 1,596 / 8 / 0.5013% |

AUROC summaries include the 21 hospitals with both positive and negative
windows and weight by their patient-hour counts. The 10 zero-positive hospitals
have undefined AUROC/AP. Within-enrichment averages exclude hospitals with
zero alerts or zero positives: 19 old versus 20 new; their medians are still
zero. Those averages must not be read as evidence that most hospitals achieved
positive alert enrichment at this exceptionally sparse policy.

| Within-hospital distribution (21 hospitals) | Old | New |
|---|---:|---:|
| AUROC: min | 0.2820 | 0.4815 |
| AUROC: q1 | 0.5426 | 0.6729 |
| AUROC: median | 0.6887 | 0.7827 |
| AUROC: q3 | 0.8694 | 0.8998 |
| AUROC: max | 0.9990 | 0.9980 |
| AP (percent): min | 0.0034% | 0.0107% |
| AP (percent): q1 | 0.0627% | 0.0888% |
| AP (percent): median | 0.1092% | 0.1294% |
| AP (percent): q3 | 0.2539% | 0.4541% |
| AP (percent): max | 8.1169% | 9.4324% |

Every hospital's rows, positives, base prevalence, alerts, TP, PPV, within lift,
AUROC, AP, and row/alert concentration is shown old/new in
[HOSPITAL_COMPARISON.md](HOSPITAL_COMPARISON.md) and
[per_hospital_comparison.csv](per_hospital_comparison.csv). Every prior summary
field is compared in [comparison.csv](comparison.csv). Absolute AP remains
small and varies substantially across hospitals.

## Hospital mix and uncertainty

New pooled enrichment is `(36/10391)/(310/2078011) = 23.223694x`.
The hospital-mix expectation is `Σ_h A_h K_h/N_h = 1.4432937434` TP,
compared with 36 observed: **24.942947x**. Uniform row selection would expect
1.5501409762 TP. The exact decomposition is
`23.223694 = 0.931073 × 24.942947`: hospital allocation alone slightly lowers,
rather than produces, the pooled enrichment.

The new data demonstrate within-hospital ranking skill for this documentation
proxy: row-weighted AUROC is 0.7348, median 0.7827, and 19/21 evaluable hospitals
are above 0.5. Hospital mix alone does not explain the result. The positive alerts
are nevertheless sparse and concentrated: 36 windows from 22 stays in 9/31
hospitals, including 19/36 windows in hospitals 73 and 155. Seven hospitals
receive no alerts and ten have no positive windows. The 12 hospitals above
pooled prevalence contain 50.83% of rows but only 43.19% of alerts. The top five
alert recipients are 443, 300, 73, 252, and 176; they receive 77.02% of alerts
and contain 64.77% of rows. All hospital shares are available in the comparison.

The CI is the same paired hospital percentile bootstrap as the prior audit:
100,000 resamples, seed 20260905, sampling 31 whole hospitals with replacement
and keeping observed within-hospital alert memberships fixed. It yields
**11.45–41.53** for pooled enrichment and **12.49–40.19** for the mix-adjusted
ratio. New resamples had zero undefined pooled/mix ratios and zero zero-TP
draws; the old run had 35 zero-TP draws, which were retained. The analysis runner
reproduced all old summary fields and bootstrap endpoints exactly before being
applied to the new data. This CI is conditional on the fitted model, source data,
and observed policy; it does not incorporate retraining, cutoff re-estimation,
or future hospital/practice drift. It is not a CI for the improvement over v3.

Reproduce with [q6_new.sql](q6_new.sql), [within_new.sql](within_new.sql),
[integrity_new.sql](integrity_new.sql), and:

```bash
python3 audit/2026-09-05/pit_v4/analyze.py --input audit/2026-09-05/pit_v4/jobs --suffix _new --output audit/2026-09-05/pit_v4/analysis
python3 audit/2026-09-05/pit_v4/compare.py
```

## What changed in the model

The final SQL explicitly sets `DATA_SPLIT_METHOD='CUSTOM'`,
`DATA_SPLIT_COL='is_validation'`, `EARLY_STOP=TRUE`, and `MIN_REL_PROGRESS=0.01`.
Only train/val rows enter CREATE MODEL; TRUE marks validation rows and is excluded
from the feature list. The family, 49 numeric features, L2=1, 50-iteration cap,
and raw global NTILE(200)=1 evaluation remain unchanged. Both new models report
49 features, automatic class weights off, standardization on, and early stopping
on in their effective metadata.

Actual BQML temporary split tables confirm the final model fitted **6,400,461
training rows / 1,819 positives** and evaluated **2,015,025 validation rows /
444 positives**. The diagnostic AUTO_SPLIT control fitted 6,390,393 rows /
1,815 positives and reserved only **10,068 rows / 4 positives**. The original
model's exact temporary evaluation count was not recovered; 2.84 was an
expectation, not an observed positive count.

| Model | Completed iterations | Alerts | TP | PPV | Recall | Enrichment | Test log loss |
|---|---:|---:|---:|---:|---:|---:|---:|
| original_v3 | 14 | 10,391 | 21 | 0.2021% | 6.7742% | 13.55x | 0.002723 |
| pit_autosplit_control | 18 | 10,391 | 38 | 0.3657% | 12.2581% | 24.51x | 0.002222 |
| pit_custom_final | 9 | 10,391 | 36 | 0.3465% | 11.6129% | 23.22x | 0.007776 |


The explicit split changes the fitted model: **50/50 coefficients including
the intercept differ from the same-feature AUTO_SPLIT control**, and the recorded
training history changes from 18 completed iterations to 9. Final held-out
metrics differ as shown above. The control was specified before seeing new test
results and is not a candidate for replacing the final model. These three runs
are a descriptive attribution check, not a causal estimate or a benchmark sweep;
the old/new AUTO_SPLIT memberships can differ when input values change, and
the inherited last-value tie rule also becomes effective on regeneration.

Reproduction: [control_model.sql](control_model.sql),
[actual_custom_split_counts.sql](actual_custom_split_counts.sql),
[actual_control_split_counts.sql](actual_control_split_counts.sql),
[model_comparison.sql](model_comparison.sql),
[weight_comparison.csv](weight_comparison.csv), and the three saved model metadata
files in `jobs/`. BQML recorded no fatal `errorResult`; it emitted the standard
NULL-imputation advisory, which is retained in the job logs. Numeric missing
values continue to use BigQuery's automatic handling.

## Probability quality and policy

The new held-out log loss is **0.0077760292**, versus **0.0015023852** for a constant
probability `1819/6400461` estimated from training labels only: **5.18 times
worse**. It is also worse than the old model's 0.0027230414. Log loss measures
probabilistic prediction quality, not ranking alone. The result contradicts a
claim of better absolute probability estimation than the constant baseline;
it does not contradict the independently measured ranking signal. No post-hoc
calibration, threshold tuning, or model reselection was used to improve this result.

The 23.22x headline is for raw alerts, not debounced alerts. First crossing
retains 2,040 rows/8 TP (0.3922% PPV, 2.58% positive-window recall); a 12-hour
quiet-period debounce retains 1,596 rows/8 TP (0.5013% PPV, 2.58% recall).
Both numerator and denominator use the same retained policy rows. Suppressed
crossings reset the quiet period; this is not a cooldown from the last emitted
alert. The corrected persistence-tier query and its existing assertion also
ran; its results are separate and do not change the raw headline.

## Narrow correctness changes and remaining limitations

- Top-coded `> 89` and other nonnumeric ages remain excluded by SAFE_CAST. The
  cohort description now says so. No age/cohort change was mixed into this rerun.
- SQL does not filter `unittype`; the model card no longer claims that it does.
- Early proxy events in the first six hours drop the entire stay from downstream
  data, not just positive labeling. The base LOS rule is six hours, but the
  hourly grid needs eight hours to yield a row. These descriptions now match SQL.
- The hospital-discharge-offset comment now uses ICU/unit admission as its time
  origin. Functional discharge-grid behavior is unchanged.
- The endpoint remains a **documentation proxy, not adjudicated cardiac arrest**.
  Broad VT matching, charting delay, care-pattern features, and future-discharge
  conditioning remain limitations. This lab correction does not solve them.

The exact reason the CUSTOM optimizer retained only nine iterations is not
exposed by the returned job/model metadata. The last two recorded validation
losses still improve by more than 1%; these logs do not establish a visible
1% plateau. I report the observed history and configured options, not an
invented stopping mechanism. The fitted model and its results are preserved.
Higher point estimates after the correction do not show that the old leakage
was harmless or that the improvement would generalize prospectively.

## Execution and provenance

Billing initially blocked permanent output creation despite valid authentication;
even a one-row table with a one-hour expiration failed. The owner enabled
billing, after which all required stages completed. No existing dataset retention
settings were changed. Failed attempts and successful job IDs are retained.

The audit reran 04, 05, 07, 08, 09, 10, 11 and aggregate exports; it reused the
unchanged cohort, labels, vitals, and split objects. [SPECIFICATION.md](SPECIFICATION.md)
records the choices made before new outcomes. `prior_sql/` and its SHA-256 list
preserve pre-edit pipeline SQL. `jobs/` contains exact submitted queries,
submission hashes, results, training histories, and metadata. New aggregate
exports are in `artifacts/reference_run_v4_pit/`; the original bundle is intact.
