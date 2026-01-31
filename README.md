# ICU Code Blue Early Warning System

Early warning system to identify **ICU patient-hours entering elevated short-term risk** of documented cardiac arrest / CPR within the next 2 hours.

This project emphasizes **temporal correctness, honest generalization, and operational realism**, rather than leaderboard metrics or abstract optimization.

> **Additional Documentation:**  
> - See [`MODEL_CARD.md`](MODEL_CARD.md) for intended use, limitations, risks, and monitoring considerations.  
> - See [`CASE_STUDY.md`](CASE_STUDY.md) for product rationale, design tradeoffs, and lessons learned.

---

## Dataset
- **eICU Collaborative Research Database v2.0**
- Accessed via **Google BigQuery** (PhysioNet credentialed access required)
- No patient-level data is redistributed in this repository

> **Data access:**  
> This project uses the eICU-CRD v2.0 dataset from PhysioNet. Data are *not* included in this repo; users must obtain access independently under the PhysioNet Data Use Agreement. See `CITATION.md` for details.

> **Citation:**  
> eICU Collaborative Research Database v2.0 (PhysioNet).  
> See `CITATION.md` for full reference and BibTeX.

---

## Problem Definition
- Binary prediction task at **hourly time steps**
- Outcome: first documented in-ICU cardiac arrest / CPR event
- Prediction horizon: **next 2 hours**
- Lookback window: **previous 6 hours**
- Minimum lead time: events occurring <6h from ICU admission excluded

Each row represents a *patient-hour*, framing the task as **short-term risk estimation over time**, not one-off event prediction.

---

## Feature Sets
1. **Vitals only**
   - HR, RR, SaO₂, BP, MAP, temperature
   - Summary statistics over 6h (mean, min, max, count)

2. **Vitals + labs** (final model)
   - Lactate, pH, potassium, creatinine, hemoglobin, WBC
   - Parsed numerically from structured and text lab fields
   - Same 6h summary statistics + most recent value

3. **Vitals + labs + trends**
   - Tested via simple slopes
   - Did not materially improve performance and was excluded from the final model

---

## Model
- Logistic Regression (BigQuery ML)
- L2 regularization
- Trained on ~170k ICU stays
- **Hospital-level split** to test cross-institution generalization

The model outputs a **continuous short-term risk score** used for ranking and alerting policy design.

---

## Evaluation Strategy
Given extreme class imbalance (~0.025% event rate), evaluation prioritizes **actionable signal under constrained attention**, not default classification metrics.

**Primary**
- Precision at fixed alert rate (top **0.5%** highest-risk patient-hours)

**Secondary**
- ROC-AUC (global ranking quality)
- Log loss (probabilistic sanity check)

Accuracy and default-threshold F1 are intentionally deprioritized due to their poor alignment with ICU alerting workflows.

---

## Temporal alerting: persistence vs debounced alerts

A naive “top 0.5% risk per patient-hour” policy repeatedly alerts on the same patient across consecutive hours, creating **alert spam without new information**. To assess temporal behavior and operational realism, we evaluated two post-model alerting strategies.

### 1) Persistence tiers (diagnostic)
Alerts were bucketed by consecutive runs:

- **Tier 1:** first alert hour  
- **Tier 2:** second consecutive alert hour  
- **Tier 3:** ≥3 consecutive alert hours  

**Finding:**  
Tier 3 alerts comprised the majority of alerts and exhibited *lower* precision than Tier 1 alerts, indicating that prolonged high-risk states primarily increase alert burden without adding predictive signal.

This suggests that **time spent above a threshold is not equivalent to increasing risk**, and that persistence alone does not reliably encode progression toward arrest.

---

### 2) Debounced first-crossing alerts (deployment-oriented)
Alerts are triggered only when a patient **enters** the extreme-risk set (top 0.5%), with subsequent alerts suppressed for a cooldown window.

| Policy | Alerts | True events | Precision |
|---|---:|---:|---:|
| Hourly top-0.5% (baseline) | 10,391 | 46 | 0.443% |
| First-crossing (0h cooldown) | 2,322 | 14 | 0.603% |
| Debounced (6h cooldown) | 2,074 | 14 | 0.675% |
| Debounced (12h cooldown) | 1,799 | 14 | 0.778% |

**Takeaway:**  
Debounced first-crossing alerts substantially reduce alert burden while improving precision per alert. These results indicate that **risk transitions (entering the extreme tail)** carry more actionable information than sustained elevation, making debouncing more aligned with ICU workflow constraints.

---

## Results (Held-out Test Hospitals)

| Model | Features | ROC-AUC | Precision @ 0.5% |
|------|----------|--------:|------------------:|
| LR v1 | Vitals | ~0.70 | 0.33% |
| LR v3 | Vitals + Labs | 0.73 | 0.44% |
| LR v4 | + Trends | 0.73 | 0.41% |

Baseline prevalence ≈ **0.025%**  
Final model achieves **~18× enrichment** at a clinically realistic alert rate.

---

## Key Methodological Notes
- Strict temporal alignment; no future information leakage
- Early ICU documentation artifacts excluded
- Hospital-level split prevents institutional memorization
- Ranking-based evaluation reflects real alerting constraints
- Alert thresholds treated as **capacity decisions**, not learned parameters

---

## Why this project stops here
This project intentionally stops at **post-model alerting policy design** rather than additional model complexity. Results show that **operational decisions (debouncing, alert consolidation)** have a larger impact on usability and signal quality than marginal gains in discrimination.

Further work would prioritize:
- Prospective validation
- Workflow integration
- Clinician-in-the-loop evaluation

rather than additional feature engineering or model tuning.

---

```text
sql/
  01_cohort.sql
  02_labels.sql
  03_features_vitals.sql
  04_features_labs.sql
  05_train_rows.sql
  06_splits.sql
  07_model_table.sql
  08_bqml_models.sql
  09_eval_alert_rate.sql
  10_eval_temporal_alert_tiers.sql
  11_eval_first_crossing_cooldown.sql
docs/
  methodology.md
  results.md
run.md'''
  


License

MIT

