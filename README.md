# ICU Code Blue Early Warning System

Early warning model to identify ICU patient-hours at elevated risk of
documented cardiac arrest / CPR within the next 2 hours.

This project emphasizes **temporal correctness, honest generalization, and
clinically meaningful evaluation**, not leaderboard metrics.


> **Additional Documentation:**  
> - See [`MODEL_CARD.md`](MODEL_CARD.md) for intended use, limitations, risks, and monitoring considerations.  
> - See [`CASE_STUDY.md`](CASE_STUDY.md) for product rationale, design tradeoffs, and lessons learned.

---

## Dataset
- **eICU Collaborative Research Database v2.0**
- Accessed via **Google BigQuery** (PhysioNet credentialed access required)
- No patient-level data is redistributed in this repository
- 
> **Data access:**  
> This project uses the eICU-CRD v2.0 dataset from PhysioNet. Data are *not* included in this repo; users must obtain access independently under the PhysioNet Data Use Agreement. See `CITATION.md` for details.


```md
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
   - Did not materially improve performance and was excluded from final model

---

## Model
- Logistic Regression (BigQuery ML)
- L2 regularization
- Trained on ~170k ICU stays
- **Hospital-level split** to test cross-institution generalization

---

## Evaluation Strategy
Given extreme class imbalance (~0.025% event rate), evaluation focuses on:

**Primary**
- Precision at fixed alert rate (top **0.5%** highest-risk patient-hours)

**Secondary**
- ROC-AUC
- Log loss

Accuracy and default-threshold F1 are intentionally deprioritized.

---

## Results (Held-out Test Hospitals)

| Model | Features | ROC-AUC | Precision @ 0.5% |
|------|----------|--------:|------------------:|
| LR v1 | Vitals | ~0.70 | 0.33% |
| LR v3 | Vitals + Labs | 0.73 | 0.44% |
| LR v4 | + Trends | 0.73 | 0.41% |


Baseline prevalence ≈ **0.025%**  
Final model achieves **~18× enrichment** at a realistic alert rate.

---

## Key Methodological Notes
- Strict temporal alignment: no future information leakage
- Early ICU documentation artifacts removed
- Hospital-level split prevents institutional memorization
- Ranking-based evaluation reflects real alerting workflows

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
docs/
  methodology.md
  results.md
run.md


---

## License
MIT
