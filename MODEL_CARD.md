# Model Card: Retrospective ICU Code-Event Proxy Ranking Model

**Version:** 2.0.0-pit (rerun completed)\
**Last Updated:** September 2026\
**Author:** Nicholas Leko  
**License:** MIT  
**Data License:** eICU-CRD (PhysioNet credentialed access required)

---

## Model Overview

- **Model type:** Logistic Regression (L2-regularized)  
- **Task:** Predict elevated risk within 2 hours of the documentation time of a documented ICU code-event / resuscitation proxy; charting lag is uncharacterized, so true clinical lead time is not established
- **Prediction unit:** Patient-hour  
- **Primary output:** Continuous risk score used for retrospective ranking; the reported operating point is a corpus-wide test-set percentile, not a per-shift or per-census operational constraint

This repository is a **retrospective modeling artifact**, not evidence of live
clinical deployment readiness.

---

## Intended Use

This repo frames the model around a potential clinical decision-support use case.
In the current artifact, the model is intended to:

- Support retrospective analysis of ICU patient-hours within 2 hours before the documentation time of a documented code-event / resuscitation proxy; this is not established clinical lead time
- Evaluate ranking under a sparse corpus-wide percentile rule; operational prioritization is not established
- Serve as a **clinical decision support signal**, not an autonomous decision-maker  

Any live clinical use would require additional local validation, silent-mode
testing, workflow review, monitoring, and governance.

**Model outputs alone do not define alerting behavior**. The current
post-model policy uses a quiet-period debounce in which suppressed crossings
reset the window; it is not a cooldown measured from the last emitted alert.

---

## Non-Goals / Out-of-Scope Use

This model is **not** intended to:

- Diagnose cardiac arrest  
- Replace clinician judgment  
- Autonomously determine treatment decisions  
- Evaluate or compare individual clinician performance  
- Be used outside ICU settings without revalidation  
- Be deployed without calibration, monitoring, and governance safeguards  

---

## Data Description

**Training and evaluation data source:**  
- eICU Collaborative Research Database v2.0  

**Population:**
- Stays with numeric age 18–120; top-coded `> 89` and other nonnumeric ages are excluded
- The source is eICU, but SQL applies no `unittype` restriction; a non-ICU exclusion is not established
- Multiple hospitals across the United States  
- Data collected within a consistent modern care era  

**Feature categories:**
- Vital signs  
- Laboratory values  
- Aggregated summary statistics over a 6-hour lookback window  

**Explicitly excluded features (by design):**
- Provider identifiers  
- Room or bed identifiers  
- Shift or staffing identifiers  
- Order-set identifiers  

These exclusions are intentional to reduce care-pattern and provider leakage.

**Exclusion criteria (for modeling cohort):**
- Prediction times before six elapsed ICU hours; rows are not required to contain a minimum number of observations, so sparse rows remain included
- Rows at or after the documented proxy-event offset  
- ICU stays with qualifying proxy events in the first 6 ICU hours  
- Final 2 hours of each ICU stay, because the retrospective prediction grid is
  bounded by `unitdischargeoffset - 120`  
- Stays shorter than six hours at cohort construction; the downstream grid requires at least eight hours to yield a row

---

## Model Configuration

### Training
- **Algorithm:** Logistic Regression (BigQuery ML)  
- **Regularization:** L2  
- **Feature set:** 49 non-intercept features (19 vital-sign summaries and 30 laboratory summaries)
- **Split:** `CUSTOM`, with `is_validation = (split = 'val')`; only train/val enter model creation. All validation hospitals are reserved for early stopping, not coefficient fitting.
- **Stopping:** `EARLY_STOP=TRUE`, `MIN_REL_PROGRESS=0.01`, maximum 50 iterations; L2=1.
- **Availability:** lab draws must be in `[t-360,t)` and `GREATEST(labresultoffset, labresultrevisedoffset) < t`. Missing revised-entry timestamps exclude records. A final revision cannot stand in for an unavailable earlier version.
- **Counts/provenance:** `artifacts/reference_run/` is the historical v3 run, not an export of the new specification. The new export is `artifacts/reference_run_v4_pit/`, with job provenance in `audit/2026-09-05/pit_v4/`.

### Inference
- **Lookback window:** 6 hours  
- **Prediction horizon:** 2 hours before proxy documentation time; true clinical lead time is not established because charting lag is uncharacterized
- **Scoring cadence:** Hourly batch scoring (not real-time streaming)  

---

## Model Assumptions

This model assumes:

- ICU monitoring practices broadly similar to those represented in eICU  
- Comparable definitions and documentation of the chart-derived proxy events used here  
- Stable relationships between the available features and proximity to proxy-event documentation time
- Risk scores are used for **ranking and prioritization**, not interpreted as calibrated absolute probabilities without additional processing  

---

## Evaluation Summary

The model uses hospital-level train/val/test assignment with a CUSTOM BQML
split. Actual temporary split tables confirm that 6,400,461 training rows
(1,819 positives) fit the model and 2,015,025 validation rows (444 positives)
are reserved for evaluation. Test rows do not enter model creation. The final
model completed nine iterations; its effective options explicitly enable early
stopping with 1% minimum relative progress and a 50-iteration cap. The returned
metadata does not expose the precise reason for the nine-iteration termination.

### Point-in-Time Corrected Test Performance

- 31 hospitals; 2,078,011 patient-hours; 310 positive windows (0.014918% prevalence).
- Raw global top 0.5%: **10,391 alerts, 36 TP, 0.3465% PPV, 11.61%
  positive-window recall, 23.22x pooled enrichment (95% hospital-cluster CI
  11.45–41.53)**.
- Within-hospital AUROC: **0.7348 row-weighted, 0.7827 median** among 21 hospitals
  with both classes; positive alerts occurred in **9/31 hospitals**, versus
  7/31 previously. Ten hospitals have no positive windows; seven receive no alerts.
- Hospital-mix expectation: 1.443 TP; observed/expected: 24.94x.
- Global ROC-AUC: 0.7292. **Log loss: 0.007776, worse than the constant
  training-prevalence baseline of 0.001502 and the prior model's 0.002723.**
  Log loss is not a ranking metric. Poor probability quality can coexist with
  ranking signal; these results do not justify interpreting scores as useful
  absolute risk probabilities.
- First crossing: 2,040 alerts/8 TP (0.3922% PPV). Quiet-period debounce:
  1,596 alerts/8 TP (0.5013% PPV). Both retain 2.58% of positive windows.

The CI uses 100,000 paired hospital resamples, seed 20260905, with fixed observed
alert membership. It excludes uncertainty from retraining and source drift.
Q1 found future-entered lab values in 106,328 historical test rows, including
35 positive windows. Regeneration also applies the deterministic lab tie rule
already present in SQL: 7,823 rows outside Q1 exposure changed, including
1,469 test rows and one positive window; all cases were explained by draw-time
ties. Old/new differences therefore cannot be attributed solely to availability.
The prior 13.55x enrichment is preserved only as a
historical comparison. The endpoint remains a **documentation proxy, not
adjudicated cardiac arrest**. See [the full version audit](audit/2026-09-05/pit_v4/REPORT.md)
for exposure, per-hospital old/new metrics, the prespecified AUTO_SPLIT control,
and the remaining limitations.

---

## Deployment & Alerting Considerations

Hourly risk scores can repeatedly flag the same patient across consecutive
hours. This repo therefore includes retrospective analyses of **first-crossing
alerts** and **quiet-period debouncing** as post-model alert-policy studies.

These policies operate **on top of** model outputs and should be treated as
evaluation artifacts here, not as evidence of a deployment-ready alerting stack.

---

## Known Limitations

### Confirmed Methodological Limitations
- **Discharge-bounded prediction grid:**  
  Prediction times are generated using `unitdischargeoffset` as an endpoint.
  This uses a future discharge timestamp that would not be known in deployment
  and excludes the final 2 hours of each ICU stay from scoring.

- **Documentation-time label:**  
  The 2-hour horizon is measured against diagnosis/treatment entry offsets, not
  adjudicated bedside event timestamps. Because documentation lag is
  uncharacterized, true clinical lead time is not established and measurements
  preceding chart entry may occur after the clinical event.

- **Proxy label contamination:**  
  The diagnosis string match includes ventricular tachycardia without separating
  pulseless VT from stable/monitored VT, so the positive class can include
  non-arrest events.

- **Early-event survivorship bias:**  
  Stays with qualifying events in the first 6 ICU hours are excluded from the
  downstream dataset entirely, removing rapid-deterioration cases from the
  evaluation population.

### Not Yet Evaluated
- Performance by demographic subgroups (age, sex, race/ethnicity)  
- Performance by ICU subtype (medical, surgical, cardiac)  
- Temporal stability across calendar years  
- Prospective performance in live clinical workflows  
- Calibration stability across individual hospitals  

### Known to Impact Performance
- Differences in ICU staffing models  
- Differences in monitoring frequency  
- Differences in intervention thresholds  
- Changes in documentation or coding practices  

---

## Potential Biases & Risks

- **Care-pattern confounding:**  
  Model predictions may partially reflect local practice patterns (e.g., lab ordering behavior) rather than pure physiology.

- **Outcome definition drift:**  
  Changes in how proxy events are documented may degrade performance over time.

- **Feedback loops:**  
  If integrated into active workflows, clinician responses to alerts may alter future outcome distributions.

These risks require ongoing monitoring and governance.

---

## Drift & Monitoring Considerations

If deployed, the following should be monitored:

- Calibration drift  
- Alert volume stability at fixed thresholds  
- Feature distribution shifts  
- Outcome prevalence changes  

Retraining should be **infrequent and triggered only by sustained degradation in ranking quality or alert enrichment**, with alert policy adjustments (e.g., debouncing or threshold recalibration) preferred as first-line mitigations.

---

## Ethical & Governance Considerations

- Model outputs should not be used for:
  - Provider performance evaluation  
  - Staffing or operational ranking  

- Any clinical use should be:
  - Transparent  
  - Auditable  
  - Reviewed by a multidisciplinary governance group  

---

## Summary Statement

This model is a **task-specific retrospective ICU ranking artifact** designed to
support careful retrospective evaluation under a corpus-wide sparse-selection
rule that is not an operational alert budget. Its
simplicity, interpretability, and explicit treatment of post-model alerting
decisions are intentional design choices for defensible analysis rather than a
claim of deployment readiness.
