# ICU Code Blue Early Warning System

Early warning model to predict documented in-ICU cardiac arrest / CPR events
within a 2-hour horizon using routinely collected ICU data.

## Dataset
- eICU Collaborative Research Database v2.0
- Accessed via Google BigQuery (PhysioNet credentialed access)
- No patient-level data redistributed

## Problem Definition
- Binary prediction task at hourly time steps
- Label: first documented CPR / cardiac arrest event per ICU stay
- Prediction horizon: next 2 hours
- Lookback window: prior 6 hours
- Minimum lead-time: events <6h from ICU admission excluded

## Features
- Vitals (HR, RR, SaO2, BP, MAP, temperature)
- Laboratory values (lactate, pH, potassium, creatinine, hemoglobin, WBC)
- Summary statistics over 6h lookback (mean, min, max, last, count)

## Model
- Logistic Regression (BigQuery ML)
- Trained on ~170k ICU stays
- Hospital-level split to test generalization

## Evaluation
Primary metric:
- Precision at fixed alert rate (top 0.5% highest-risk patient-hours)

Secondary metrics:
- ROC-AUC
- Log loss

## Results (Test Set)
| Model | Features | ROC-AUC | Precision @ 0.5% |
|------|----------|---------|------------------|
| LR v1 | Vitals only | ~0.70 | 0.33% |
| LR v3 | Vitals + Labs | **0.73** | **0.44%** |
| LR v4 | + Slopes | 0.73 | 0.41% |

Baseline prevalence ≈ 0.025%.  
Final model achieves ~18× enrichment at alert threshold.

## Notes
- Default classification thresholds are inappropriate for rare events;
  ranking-based evaluation is used instead.
- This work focuses on model development and evaluation, not clinical deployment.

## License
MIT
