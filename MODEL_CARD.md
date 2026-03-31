# Model Card: Retrospective ICU Code-Event Proxy Ranking Model

**Version:** 1.1  
**Last Updated:** March 2026  
**Author:** Nicholas Leko  
**License:** MIT  
**Data License:** eICU-CRD (PhysioNet credentialed access required)

---

## Model Overview

- **Model type:** Logistic Regression (L2-regularized)  
- **Task:** Predict risk of a documented ICU code-event / resuscitation proxy within the next 2 hours  
- **Prediction unit:** Patient-hour  
- **Primary output:** Continuous risk score used for ranking and prioritization under fixed alert-rate constraints  

This repository is a **retrospective modeling artifact**, not evidence of live
clinical deployment readiness.

---

## Intended Use

This repo frames the model around a potential clinical decision-support use case.
In the current artifact, the model is intended to:

- Support retrospective analysis of ICU patients at elevated short-term risk of a documented code-event / resuscitation proxy  
- Enable **prioritization of clinical attention** under constrained alert budgets  
- Serve as a **clinical decision support signal**, not an autonomous decision-maker  

Any live clinical use would require additional local validation, silent-mode
testing, workflow review, monitoring, and governance.

Importantly, **model outputs alone do not define alerting behavior**. Actionability depends on post-model alerting policies (e.g., debouncing, cooldown windows) designed to balance signal detection with clinical workflow constraints.

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
- Adult ICU stays  
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
- Patient-hours with insufficient lookback data  
- Time windows immediately adjacent to documented proxy events (to reduce label leakage)  
- Non-ICU care settings  

---

## Model Configuration

### Training
- **Algorithm:** Logistic Regression (BigQuery ML)  
- **Regularization:** L2  
- **Feature set:** ~30 engineered summary statistics  
- **Cohort and row counts:** checked in under `artifacts/reference_run/` and regenerable via `artifacts/queries/`  

### Inference
- **Lookback window:** 6 hours  
- **Prediction horizon:** 2 hours  
- **Scoring cadence:** Hourly batch scoring (not real-time streaming)  

---

## Model Assumptions

This model assumes:

- ICU monitoring practices broadly similar to those represented in eICU  
- Comparable definitions and documentation of the chart-derived proxy events used here  
- Stable relationships between physiological deterioration and short-term proxy-event risk  
- Risk scores are used for **ranking and prioritization**, not interpreted as calibrated absolute probabilities without additional processing  

---

## Evaluation Summary

Evaluation was performed using a **hospital-level train/val/test split** to
assess held-out-hospital performance within the same eICU data ecosystem. The
current published repo path trains one prespecified final model on `train`; it
does not reproduce a validation-based model-selection sweep.

### Test Set Performance (Hospital Holdout)

- **Held-out hospitals:** 31
- **Held-out patient-hours:** 2,078,011
- **Positive labeled windows on test:** 310 (0.0149% row prevalence)
- **Held-out `ML.EVALUATE`:** ROC-AUC 0.6377, log loss 0.002723
- **Operating point at top 0.5% of test rows:** 10,391 alerts, 21 positive
  labeled windows, 0.2021% precision, 13.55x enrichment over test prevalence
- **First-crossing alert policy:** 3,350 alerts, 8 positive labeled windows,
  0.2388% precision
- **12-hour debounced first-crossing:** 2,650 alerts, 7 positive labeled
  windows, 0.2642% precision

This is retrospective held-out-hospital evaluation only; it does **not**
constitute external, prospective, or live-workflow validation. Exact aggregate
counts supporting these metrics are checked in under `artifacts/reference_run/`.

---

## Deployment & Alerting Considerations

Hourly risk scores can repeatedly flag the same patient across consecutive
hours. This repo therefore includes retrospective analyses of **first-crossing
alerts** and **cooldown-based debouncing** as post-model alert-policy studies.

These policies operate **on top of** model outputs and should be treated as
evaluation artifacts here, not as evidence of a deployment-ready alerting stack.

---

## Known Limitations

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
support careful evaluation under realistic operational constraints. Its
simplicity, interpretability, and explicit treatment of post-model alerting
decisions are intentional design choices for defensible analysis rather than a
claim of deployment readiness.
