# Adversarial audit — 2026-09-05

The 13.55× calculation is arithmetically correct for the checked-in, selected patient-hour dataset. It does not establish advance detection of clinical code events. The strongest newly identified implementation defect is that the lab lookback uses specimen-draw time without enforcing availability of the value at prediction time. The closest match to a statistical check that is not meaningfully checking is BigQuery ML's implicit early-stopping evaluation: the configured defaults reserve 10,000 training-input rows, containing only about 2.84 positive windows in expectation, while the explicit hospital validation set with 444 positive windows is unused.

I reviewed all eleven pipeline SQL files, all five export queries and CSVs, README, model card, methodological/results/reproducibility/checklist documents, relevant supporting prose, and relevant Git history. Audited HEAD: `5d2616a`. No pipeline or existing documentation was changed. The only additions are this audit, read-only diagnostic queries, and a local reproduction script.

**Evidence limit:** I did not run the credentialed eICU pipeline or execute the diagnostic queries on BigQuery. The local CLI has no configured project; an authenticated BigQuery session was not established. Counts below come from the checked-in exports and are independently recalculated. Source semantics and BigQuery defaults were checked against official documentation. Actual leakage frequency, cross-split patient overlap, hospital concentration, internal evaluation positives, and current-model reproduction remain unmeasured. Synthetic counterexamples establish what the SQL permits, not how frequently it occurs in eICU.

Reproduce local calculations and counterexamples with `python3 audit/2026-09-05/reproduce_local.py`. All assertions passed. [Local reproduction script](/Users/nicholasleko/projects/icu-code-blue-early-warning/audit/2026-09-05/reproduce_local.py). [Read-only BigQuery diagnostics, Q1–Q10](/Users/nicholasleko/projects/icu-code-blue-early-warning/audit/2026-09-05/diagnostics.sql).

Severity means impact on scientific interpretation: **High** undermines a clinical early-warning or generalization conclusion; **Medium** materially weakens evaluation, population definition, or reproducibility; **Low** is documentation inconsistency without a demonstrated numerical impact. A disclosed limitation remains a limitation, but disclosure is credited below.

## Pipeline reconstructed from SQL

1. `01`: Select stays with numeric age 18–120 and `unitdischargeoffset >= 360`. Keep hospital and patient identifiers. No DNR, death, unit-type, measurement-density, or lab-availability eligibility rule.
2. `02`: Find the minimum matching diagnosis offset and minimum matching treatment offset per stay. Take the earliest across both sources. Retain no-match stays and stays whose earliest match is at least minute 360. A match before 360 removes the entire stay, even if there is a later match.
3. `03`: Generate hourly prediction times `t = 360,420,... <= discharge-120`. Aggregate vital records satisfying `t-360 <= observationoffset < t`.
4. `04`: Aggregate selected labs separately, with `t-360 <= labresultoffset < t`; join aggregates to vital features. Produce 19 vital summaries and 30 lab summaries. Counts are actual inputs. Missing numerical summaries remain NULL; counts are zero.
5. `05`: Retain rows with no proxy event or `t < E`. Set `y=1` exactly when `t < E <= t+120`. Other retained rows are negative. Feature window is `[t-360,t)`; label window is `(t,t+120]`. There is no washout gap and no guaranteed two-hour lead time.
6. `06–07`: Hash hospital ID into 100 buckets; assign `<70` train, `<85` validation, remainder test, then join by hospital. Reference counts are 135/42/31 hospitals; percentages are hash targets, not exact quotas.
7. `08`: Train logistic regression, L2=1, maximum 50 iterations, using only `split='train'`. The explicit SELECT includes 49 features and label `y`; it excludes event time, prediction time, stay/person/hospital IDs, admission-source/unit fields, treatments, medications, and care-team fields. BigQuery performs numeric preprocessing and an implicit internal evaluation split.
8. `09`: Score all retained test rows. Rank the entire test corpus by score, with stay/time tie-breakers. Select `NTILE(200)=1`.
9. `10–11`: Diagnose persistence tiers; select new above-threshold runs; suppress a new crossing if the previous crossing was less than 12 hours earlier. The previous crossing need not have emitted an alert.

## 1. Target leakage

### F1 — High: lab temporal guard uses the wrong clock

**Confirmed missing enforcement; magnitude unmeasured.** [Lab extraction](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/04_features_labs.sql:16) selects `labresultoffset`, the final stored value/text and lab ID, but never `labresultrevisedoffset`. [The join](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/04_features_labs.sql:84) admits values solely by draw offset. eICU defines `labresultoffset` as specimen-draw time and `labresultrevisedoffset` as entry time for the revised value. These are different temporal facts. [Official lab schema](https://eicu.mit.edu/eicutables/lab/).

**Reproduction:** At `t=600`, a lab drawn at 590 and entered/revised at 660 passes `590 >= 240 AND 590 < 600`. A proxy at 630 yields `y=1`. The model can therefore use a value entered after both prediction and proxy documentation. The local SQLite fixture returns `(accepted=1, available_before_t=0, y=1)`. Q1 counts this path on modeled windows.

**Mechanism:** retrospective final values are placed into earlier feature windows. This is potential look-ahead even for the narrower documentation-time prediction task. It affects values, “last” measurements, and counts of eventually available valid results. The revised-offset field is not a full historical result-version log: filtering it conservatively would remove unavailable revised values, but would not reconstruct earlier versions or prove initial turnaround times. Repaired point-in-time features require availability/version semantics, not simply renaming the current timestamp.

### F2 — High: the exclusion guard protects chart-entry time, not clinical event time

**Confirmed endpoint limitation; amount of post-clinical-event contamination unknown; already disclosed.** [Diagnosis/treatment minima](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/02_labels.sql:9) feed [the row exclusion](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/05_train_rows.sql:21). These offsets identify when a diagnosis/treatment was entered. [Diagnosis schema](https://eicu.mit.edu/eicutables/diagnosis/), [treatment schema](https://eicu.mit.edu/eicutables/treatment/).

**Reproduction:** A clinical event at minute 570, chart entry at 650, and prediction at 600 allow measurements from minutes 570–599 into a positive prediction window. The guard `600 < 650` passes. It cannot establish that prediction preceded the actual event.

No direct resuscitation medication, treatment, provider, care-team, or unit-change feature is selected. However, post-event physiology and increased observation/lab density can enter before delayed chart documentation. There are twelve explicit count features: six vital counts and six lab counts. Pre-prediction clinician concern is legitimate predictive information if the intended task permits it; its presence alone is not proof of leakage. This artifact does not distinguish advance physiological warning from surveillance, already-recognized deterioration, or post-event recovery. It needs onset/availability validation and care-pattern baselines or ablations. Large raw coefficients do not establish the magnitude of this effect; see F9.

## 2. The proxy and population

### F3 — High: a documentation proxy lacks adjudication and competing-outcome accounting

**Confirmed construction, with clinical false-positive/false-negative rates unmeasured.** [The complete matches](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/02_labels.sql:17) are diagnosis substrings `cardiac arrest`, `cardiorespiratory arrest`, `asystol`, `ventricular fibrillation`, `ventricular tachycardia`, `vfib`, `vtach`; and treatment substrings `cpr`, `cardiopulmonary resuscitation`, `defibrillat`, `acls`, `code blue`.

Either source is sufficient. There is no dx/tx corroboration, clinical adjudication, pulselessness requirement, negation/context processing, or upper-bound check against ICU discharge. Stable/non-arrest VT qualifies. Broad defibrillation or arrest substrings require an actual vocabulary inventory before assuming their matches are specific. I did not find patient-level evidence proving particular negated/device strings are present; Q10 inventories the actual matches. The diagnosis source does not reliably resolve ruled-out diagnoses, and eICU explicitly cautions against inferring treatment absence from absent documentation. [Diagnosis](https://eicu.mit.edu/eicutables/diagnosis/), [treatment](https://eicu.mit.edu/eicutables/treatment/).

**DNR/death/discharge reproduction:** [The CASE](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/05_train_rows.sql:12) assigns zero whenever `event_offset_min IS NULL`. No SQL reads DNR/code-status/care-plan data or death status. Thus an otherwise eligible DNR stay or a patient who dies without a matching chart string contributes negative retained hours. DNR does not itself censor or exclude anything. Its potential effect on whether resuscitation is attempted/documented is unmodeled. Death is not an alternative positive endpoint or explicitly handled competing event. Final discharge-adjacent hours are dropped by the grid, regardless of death; see F4. An actual code missing both strings is negative for this proxy. A qualifying documented arrhythmia can be positive regardless of DNR.

This is not inherently incorrect for the literal task “predict whether these strings will be documented.” It is an invalid substitution for an adjudicated deterioration/arrest endpoint. The pipeline measures proximity to documentation and cannot determine how much of its signal is clinical versus documentation behavior. Q4 quantifies death-status and event-observability accounting.

### F4 — High: outcome-dependent scoring population removes observable terminal events

**Confirmed; discharge selection and early-event exclusion already disclosed, edge effects insufficiently described.** [Grid](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/03_features_vitals.sql:6): `GENERATE_ARRAY(360, unitdischargeoffset-120,60)`. [Label inclusion](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/02_labels.sql:47): earliest event must be NULL or ≥360. [Rows](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/05_train_rows.sql:18): inner join labels and exclude `t>=E`.

**Reproductions:**

- LOS 479 minutes passes the ≥6-hour cohort filter but generates zero rows. LOS 480 produces its first row at 360. Modeled stays therefore require at least eight hours, despite the six-hour base-cohort rule.
- Event exactly at minute 360 survives `labels_v2`, but generates no retained prediction rows.
- Discharge at 1030 and event at 1025: final prediction is 900; its horizon ends at 1020. This observed in-stay event produces zero positive windows. It disappears from positive-window sensitivity denominators.
- An earliest match at 300 and later CPR at 900 drops the entire stay; the later event is never considered after the minimum is taken.
- An event recorded after discharge may remain a positive stay in `labels_v2`, but cannot be positive in the discharge-bounded prediction rows.

Reference cohort-to-label attrition is `177418-171833=5585` stays. Further attrition to unique modeled stays is not exported. The row baseline is conditional on survival/continued unit residence through `t+120`, absence of an earlier proxy, and the other eligibility filters. Future discharge need not be an input column to induce selection bias. Complete-horizon restriction may define a legitimate retrospective estimand, but it does not establish performance for all live scoring opportunities. Neither direction nor size of bias can be inferred from the published aggregates.

### F5 — Medium: documented adult/ICU scope differs from eligibility code

**Confirmed eligibility defects; affected counts not measured.** [Cohort age casting](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/01_cohort.sql:20) excludes top-coded `'> 89'` because `SAFE_CAST` returns NULL. This contradicts the unqualified adult/age-18–120 population description and omits an older adult group. eICU also permits unit types such as `SDU/Step down`; the query selects `unittype` but never filters it. Consequently the [model card's exclusion of non-ICU settings](/Users/nicholasleko/projects/icu-code-blue-early-warning/MODEL_CARD.md:77) is not enforced. Q5 reports actual scope. [Official patient schema](https://eicu.mit.edu/eicutables/patient/).

## 3. Split and model selection

### F6 — High: implicit early-stopping validation is statistically inadequate for this outcome

**Confirmed configuration/default behavior; realized validation count and stopping decision unmeasured.** [Training options](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/08_bqml_models.sql:9) do not set `DATA_SPLIT_METHOD`, `EARLY_STOP`, or `MIN_REL_PROGRESS`. BigQuery defaults to `AUTO_SPLIT`, reserving 10,000 input rows when input exceeds 50,000; early stopping defaults on with 1% minimum relative progress. This creates an internal row-level evaluation set within the training hospitals. [Official GLM options](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-create-glm).

**Calculation:** `10000 × 1819/6400461 = 2.8419827884` expected positive windows. Under an illustrative iid binomial sample, P(zero positives)≈5.83% and P(at most two)≈45.95%. These are not observations of the actual deterministic split; repeated patient windows and split implementation prevent treating the illustration as measured uncertainty. Nearby windows from one stay are not explicitly grouped in this internal split. The external validation set has 2,015,025 rows and 444 positives but is unused.

This is the most direct statistical equivalent of a guard that looks reassuring while checking very little of the rare outcome. Small loss changes among almost entirely negative rows can govern early stopping without meaningful rare-event validation. The maximum of 50 iterations does not mean 50 were run. Inspect effective options, actual internal split table/counts if retained, and `ML.TRAINING_INFO` with Q7. I cannot prove that this model stopped early or that this defect caused its reported performance. It does not invalidate the separate hospital test holdout; it weakens training/selection and the description of the selection process.

**What held:** Hospital assignments really depend only on hospital ID in [06](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/06_splits.sql:8); [07](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/07_model_table.sql:5) joins that assignment to each stay. Given source key integrity, a hospital and a stay cannot cross outer splits. The numeric feature transforms before splitting are per-window aggregates, not full-dataset learned normalization. BigQuery preprocessing receives only the `WHERE split='train'` input: no evidence of outer-test means or imputation leakage. [Official preprocessing](https://docs.cloud.google.com/bigquery/docs/auto-preprocessing).

**What cannot be certified:** No person-level grouping or overlap assertion uses `uniquepid`. Repeated stays within the same hospital stay together; cross-hospital persons need Q2. I found no actual patient crossing. No executable hyperparameter sweep or test-label-driven selection exists in the current pipeline. Test score quantiles determine retrospective membership, which is legitimate for the stated top-k estimand but does not provide a prospectively fixed cutoff. The policy length is evaluated on test; its independence from prior test inspection is not documented. Git history (`git show 5ed8a03^:README.md`) contains earlier LR v1/v3/v4 comparisons and final-v3 selection language, but no reproducible selection record. Their removal does not prove either clean historical prespecification or actual test-driven tuning. The current narrow claim “one published fixed path” is supportable; strict untouched-test provenance is not established.

## 4. The 13.55× and statistical evaluation

**The exact reconstruction is:**

`baseline = 310 / 2078011 = 0.000149181115980618 = 0.0149181116%`

`alerts = ceil(2078011 / 200) = 10391`

`PPV = 21 / 10391 = 0.002020979693965932 = 0.2020979694%`

`lift = PPV / baseline = 13.547154951089807 ≈ 13.55`

[Canonical ranking](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/09_eval_alert_rate.sql:57) and [enrichment export](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/queries/02_reference_run_operating_point.sql:75) reproduce the formula. The base rate is **all eligible, retained test prediction rows**, not all ICU hours, all adults, all stays, or 1,401 proxy-positive stays across all splits. The alert count is globally pooled across all held-out hospitals and all retrospective times; no hospital/stay/day/shift partition exists. The actual fraction is 0.5000455%, a harmless consequence of `NTILE` rounding.

There are **10,370 proxy-negative alert rows**, **6.7742% positive-window recall**, and approximately **495 selected rows per positive labeled window**. These are not 21 unique arrests: each stay has one retained proxy offset but can contribute two positive hourly windows. Under current row uniqueness, 21 raw positive windows represent between 11 and 21 stays. The exact count requires patient-level predictions. Clinical event identity and clinical-event sensitivity cannot be derived from these aggregates.

### F7 — High: pooled lift does not test within-hospital warning ability; uncertainty is absent

**Confirmed evaluation gap; hospital confounding not empirically established.** The global `NTILE` in [09](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/09_eval_alert_rate.sql:61) and pooled prevalence in [the export](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/queries/02_reference_run_operating_point.sql:3) have no hospital-stratified comparator. No per-hospital PPV, sensitivity, alert allocation, cluster interval, PR-AUC, or event-level recall is published. Thirty-one held-out hospital IDs and two million correlated windows do not constitute two million independent clinical validation cases.

**Counterexample:** Invent two groups of hospitals with `(N,K)=(50000,1355)` and `(950000,645)`. A score that merely identifies the first group and randomly selects 5,000 of its hours has expected PPV 2.71%; pooled prevalence is 0.2%; expected lift is **13.55×**, despite no within-group discrimination. This proves that the published statistic alone cannot rule out hospital/documentation-mix signal. It does not prove that the actual score behaves this way.

**Reproduction on this dataset:** Q6 reports `N_h,K_h,A_h,TP_h`, unique evaluable event stays, and the hospital-mix null `expected TP = Σ_h A_h K_h/N_h`. Compare observed TP to this expectation, alongside within-hospital performance. Separate a random patient-hour baseline from realistic comparators such as already-observed physiology or monitoring density. For uncertainty, resample hospitals and patients/stays, keeping windows together and recomputing the defined ranking/policy. The existing aggregates cannot support a defensible cluster interval; a naive binomial CI around 21/10,391 would overstate independence. I do not manufacture one.

### F8 — Medium: low reported log loss masks performance worse than a no-feature baseline

**Confirmed from exports; not a wrong log-loss formula.** The [ML.EVALUATE export](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/reference_run/05_reference_run_ml_evaluate.csv:2) gives log loss 0.0027230414. With training-only constant probability `q=1819/6400461`, its held-out loss is `-[p ln(q)+(1-p)ln(1-q)] = 0.0015023852`, where `p=310/2078011`. The model's loss is **81.25% higher**. The test-prevalence constant gives 0.0014635078, but that is a descriptive oracle baseline and should not be presented as trained without test labels. Q9 and the local script reproduce the honest training-prevalence comparator.

The exported 99.9850819% accuracy exactly equals the all-negative accuracy; precision/recall/F1 at the default threshold are zero. Those facts do not negate top-tail ranking, and the README does not advertise that accuracy as success. However, [CASE_STUDY.md:145](/Users/nicholasleko/projects/icu-code-blue-early-warning/CASE_STUDY.md:145) calls log loss a secondary ranking metric; it is a probability-scoring metric and this value offers no evidence of good calibration or improvement over a trivial probability model. Base-rate normalization and recall are essential context in this imbalance regime.

There is **no downsampling, rebalanced evaluation set, SMOTE, or class-weight option in the checked-in path**. Count-feature zero values and BigQuery mean imputation are not resampling. Precision at sparse top-k is a reasonable ranking metric, but insufficient as the sole clinical-success criterion.

## 5. Alert policy

**The counters held.** In [11:79–83](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/11_eval_first_crossing_cooldown.sql:79), both numerator and denominator require `alert_debounced=1`. The [policy export](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/queries/03_reference_run_alert_policy.sql:68) consistently applies each policy to alerts and positives. Suppressed positive windows are not credited to an earlier negative alert. No implementation path found inflates PPV by retaining suppressed true positives.

| Policy | Selected rows | Positive rows | PPV | Fraction of test rows | Positive-row capture / 310 |
|---|---:|---:|---:|---:|---:|
| Raw top 0.5% | 10,391 | 21 | 0.20210% | 0.50005% | 6.7742% |
| First crossing | 3,350 | 8 | 0.23881% | 0.16121% | 2.5806% |
| 12-hour quiet period | 2,650 | 7 | 0.26415% | 0.12753% | 2.2581% |

The headline **13.55× belongs to raw scores, not the debounced policy**. Debouncing reduces alert rows 74.50% and positive alert rows 66.67%. Rising PPV is not equivalent to preserving sensitivity. The last column is retained positive-row capture, not event sensitivity: deduplication changes the meaning of this denominator, so evaluate unique event detection separately before claiming clinical loss or preservation. With a two-hour label horizon and a 12-hour separation, the seven debounced positives represent seven distinct proxy-positive stays if input rows are unique; that still does not establish seven adjudicated codes.

**Behavioral reproduction:** crossings at hours 6,16,26 with non-alert hours between emit only hour 6 under this implementation. Each suppressed crossing resets the timer. A 12-hour cooldown from last emitted alert emits at 6 and 26. The current README correctly distinguishes them. A persistently high run can remain suppressed indefinitely until a new crossing; the code does not reschedule repeats every 12 hours. “Quiet” here means no recent first crossing, not necessarily no recent above-threshold scores.

The current persistence SQL increments reset groups on non-alert rows and counts only alert rows; its inline fixture has explicit expected tiers. I found no remaining tier defect on its continuous hourly grid. Published tier results are withdrawn. The historical broken implementation must not be attributed to current HEAD, and the fixture does not regenerate clinical results.

## 6. Additional evidence defects and documentation drift

### F9 — Medium: coefficient ordering is not comparable feature importance

**Confirmed scale issue; wording about largest raw coefficients is literally accurate.** [Weights query](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/queries/04_reference_run_weights.sql:3) orders `ABS(weight)` from `ML.WEIGHTS` without `STRUCT(TRUE AS standardize)`. BigQuery defaults to unstandardized weights. [Official weights semantics](https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-weights).

[Failure-mode discussion](/Users/nicholasleko/projects/icu-code-blue-early-warning/docs/supporting/FAILURE_MODES.md:211) uses large pH/lab coefficients in its care-pattern explanation. The export proves those coefficients are numerically large per native unit; it does not prove those features dominate predictions. Changing a feature's unit rescales its coefficient without changing its predictions. Counts, pH, heart rate and pressure have different scales; correlated mean/min/max/last features further complicate interpretation. Q8 produces standardized coefficients, which are more comparable but still not causal importance. To establish monitoring-density dependence, use held-out ablation or appropriate feature-attribution analyses. I do not use the current coefficient ranking as proof of leakage.

### F10 — Medium: current-code/source binding of the reference result is unverified

**Confirmed and partly disclosed.** [Results provenance note](/Users/nicholasleko/projects/icu-code-blue-early-warning/docs/results.md:10) admits no shared run ID/source-snapshot binding. [Reproducibility note](/Users/nicholasleko/projects/icu-code-blue-early-warning/docs/reproducibility.md:91) says the exports predate deterministic tie-breakers. Current lab “last” selection includes `labid DESC`; current ranking includes stay/time tie-breakers. The assertion that any regeneration difference must be “marginal” is not established: a tied lab choice can alter training features, and a boundary tie can change one of only 21 positive windows.

The [operating-point export](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/queries/02_reference_run_operating_point.sql:3) takes baseline counts from `model_table_v3`, but PPV from a separately replaceable `preds_test_v3`. It never asserts matching row keys, labels, score completeness, or common run identity. A stale predictions table and a newer model table can silently combine into a plausible but invalid lift. I found no proof that the checked-in tables were mismatched. Q3 checks their current row agreement; run/model/source fingerprints are needed for durable provenance.

**Consequently:** the formula and CSV arithmetic reproduce locally; exact 13.55× from the current pipeline is not independently reproduced or proven by this repository alone. ROC-AUC and log loss are only traceable to their exports, not recomputable from counts and weights without predictions/features.

### F11 — Low: remaining quantitative/semantic prose drift

- [README:75](/Users/nicholasleko/projects/icu-code-blue-early-warning/README.md:75) still says early-event stays are “excluded from positive labeling”; its own lines 89–91 correctly explain that they are dropped entirely. Keep only the precise wording.
- The six-hour base cohort and six-hour lookback are real, but six-to-under-eight-hour stays cannot be modeled. “Minimum lead time” of six hours is really a minimum earliest-documentation offset after admission; prediction-to-documentation lead time is `(0,120]` minutes.
- Numeric age 18–120 and non-ICU exclusions do not describe actual scope accurately; F5.
- The policy CSV has legacy `cooldown_hours` and `debounced_first_crossing` names while its current export query uses `quiet_period_hours` and `quiet_period_debounced_first_crossing`. [Artifact README](/Users/nicholasleko/projects/icu-code-blue-early-warning/artifacts/README.md:10) explicitly explains the discrepancy. Numeric behavior is consistent; this is not evidence of a denominator error.
- [Cohort SQL:18](/Users/nicholasleko/projects/icu-code-blue-early-warning/sql/01_cohort.sql:18) incorrectly describes `hospitaldischargeoffset` as minutes from hospital admission; it is relative to unit admission. The field is not used by the current model/grid, so no demonstrated numerical impact. [Patient schema](https://eicu.mit.edu/eicutables/patient/).
- [Case study:45](/Users/nicholasleko/projects/icu-code-blue-early-warning/CASE_STUDY.md:45) gives a universal-looking ~1–2% alert-fatigue threshold without a source or evaluated workflow. That number is an unsupported informal assumption, not a result produced by this code. “Log loss” is also incorrectly grouped under ranking metrics; F8.

**Quantitative claim reconciliation:**

| Claim in README/model card/results | Audit result |
|---|---|
| eICU-CRD v2.0 | Declared source; SQL uses a dataset name, without a frozen snapshot identifier. |
| 177,418 cohort stays | Matches cohort export; not number of modeled stays or people. |
| 171,833 labeled stays, 1,401 positive, 0.815% | `1401/171833=0.8153265%`; matches export; some positives can have no positive row. |
| 135/42/31 hospitals | Matches split export, sums to 208; does not prove every assigned hospital contributes modeled rows. |
| 2,078,011 test rows; 310 positive; 0.0149% | Matches export and arithmetic. |
| 10,391 alerts; 21 positive; 0.2021%; 13.55× | Matches `NTILE` count and formulas; raw selected-row proxy result only. |
| 3,350/8/0.2388% first crossing | Matches policy export arithmetic and query meaning. |
| 2,650/7/0.2642%, 12-hour debounce | Matches export arithmetic; current suppression rule is quiet-period, not post-emission cooldown. |
| ROC-AUC 0.6377, loss 0.002723 | Correct rounding of ML.EVALUATE export; independent source-data recomputation unavailable. |
| 49 features: 19 vital, 30 lab | Matches explicit training SELECT and 49 non-intercept weight rows. |
| Six-hour lookback, hourly cadence, two-hour horizon | Correct offset predicates; lab availability and clinical onset are not protected by them. |
| No minimum observation count | Correct: LEFT JOIN aggregates retain sparse rows; counts can be zero. |
| Rows at/after proxy removed | Correct for chart-entry offset only. |
| First six hours/final two hours excluded | Broadly correct, with exact-boundary and effective-eight-hour eligibility caveats above. |
| Persistence-tier findings | Withdrawn; no current quantitative tier claim to verify. |

Older ~18×, 0.44% PPV and model-comparison results appear in Git history but are removed from current headline documents. I do not report them as current claims. `make smoke` only checks repository structure/text and is described as such; its success cannot establish scientific correctness, but the README does not pretend it can.

## Assessment and highest-value change

**Defensible restatement:** “In a checked-in retrospective reference export, the highest-scoring 10,391 of 2,078,011 eligible test prediction rows contained 21 proxy-positive windows: PPV 0.2021%, versus 0.014918% over those same test rows, for 13.55× pooled row enrichment and 6.77% positive-window recall. Selection was global across held-out hospitals and retrospective time, before debouncing. The endpoint is documentation of selected diagnosis/treatment strings; clinical lead time, point-in-time lab availability, within-hospital utility and uncertainty remain unvalidated.”

The current README is already substantially more careful than the initial task description might suggest: it provides the PPV/denominator, distinguishes documentation time, discloses discharge selection, and labels the cooldown correctly. Its central arithmetic is defensible as a qualified descriptive result. Interpreting 13.55× as arrest-risk enrichment, clinically useful early warning, a debounced-policy improvement, or achieved live 0.5% budgeting is not supported.

**Health-system AI governance:** This is an auditable exploratory research artifact, not evidence sufficient for clinical deployment approval. I would require correction/quantification of availability leakage, endpoint and competing-outcome validation, a prospectively defined scoring population and threshold, and hospital/event-level uncertainty before a clinical-benefit conclusion. Governance prose cannot substitute for those measurements. This is a readiness judgment, not a claim about a specific committee's formal decision.

**Clinical-ML technical interview:** It can survive as a candid retrospective case study if the author explains the actual estimand, 21 versus seven positive windows, the 6.77% raw row recall, the failed no-feature log-loss comparator, and the implicit tiny early-stopping split. Selling two million rows and 13.55× as evidence of robust code-blue warning would not survive a careful interview. Several limitations were correctly acknowledged before this audit; the additional temporal and statistical findings need actual analysis rather than further qualification alone.

**If only one change is allowed:** make feature generation point-in-time correct using value-availability/version timestamps, starting with labs, and regenerate the fixed-model held-out evidence. This is the most concrete fix to an invalid information boundary; everything downstream, including the 13.55×, currently depends on that boundary. It does not by itself establish a valid cardiac-arrest endpoint. If the goal remains clinical code-blue early warning after this repair, adjudicated event-time validation is the next indispensable step.
