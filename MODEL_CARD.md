# Model Card: ICU Code Blue Early Warning Model

**Version:** 1.1  
**Last Updated:** January 2026  
**Author:** Nicholas Leko  
**License:** MIT  
**Data License:** eICU-CRD (PhysioNet credentialed access required)

---

## Model Overview

- **Model type:** Logistic Regression (L2-regularized)  
- **Task:** Predict risk of in-hospital cardiac arrest / CPR (“code blue”) within the next 2 hours  
- **Prediction unit:** Patient-hour  
- **Primary output:** Continuous risk score used for ranking and prioritization under fixed alert-rate constraints  

---

## Intended Use

This model is intended to:

- Support **early identification of ICU patients at elevated short-term risk** of cardiac arrest  
- Enable **prioritization of clinical attention** under constrained alert budgets  
- Serve as a **clinical decision support signal**, not an autonomous decision-maker  

Model outputs are designed to be used in **retrospective analysis** and **silent-mode prospective testing** prior to any clinical integration.

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
- Time windows immediately adjacent to documented events (to reduce label leakage)  
- Non-ICU care settings  

---

## Model Configuration

### Training
- **Algorithm:** Logistic Regression (BigQuery ML)  
- **Regularization:** L2  
- **Feature set:** ~30 engineered summary statistics  
- **Training cohort:** ~170k ICU stays (~2M patient-hours)  

### Inference
- **Lookback window:** 6 hours  
- **Prediction horizon:** 2 hours  
- **Scoring cadence:** Hourly batch scoring (not real-time streaming)  

---

## Model Assumptions

This model assumes:

- ICU monitoring practices broadly similar to those represented in eICU  
- Comparable definitions and documentation of cardiac arrest / CPR events  
- Stable relationships between physiological deterioration and short-term arrest risk  
- Risk scores are used for **ranking and prioritization**, not interpreted as calibrated absolute probabilities without additional processing  

---

## Evaluation Summary

Evaluation was performed using **hospital-level holdout splits** to assess generalization across care settings within the same data ecosystem.

### Test Set Performance (Hospital Holdout)

- **ROC-AUC:** ~0.73  
- **Baseline event prevalence:** ~0.025% per patient-hour  
- **Precision @ 0.5% alert rate:** ~0.44%  
- **Risk enrichment:** ~18× baseline  

**Interpretation:**  
At a realistic alert rate of 0.5% (approximately 1 alert per 200 patient-hours), the model identifies patient-hours with roughly **18× higher event rates** than random screening.

This represents strong **internal validation**, but does **not** constitute external or prospective clinical validation.

---

## Deployment & Alerting Considerations

Hourly risk scores can repeatedly flag the same patient across consecutive hours. To address this, post-model alerting policies such as **first-crossing alerts** and **cooldown-based debouncing** were evaluated to reduce alert burden while improving precision per alert.

These policies operate **on top of** model outputs and are critical for aligning model performance with real ICU workflows.

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
  Changes in how cardiac arrest events are documented may degrade performance over time.

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

Retraining should be **triggered by observed drift or performance degradation**, not by elapsed time alone.

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

This model is a **task-specific ICU early warning system** designed to support timely clinical awareness under realistic operational constraints. Its simplicity, interpretability, and explicit treatment of post-model alerting decisions are intentional design choices to support safe evaluation and potential future deployment.
