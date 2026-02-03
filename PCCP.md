# Predetermined Change Control Plan (PCCP)

**Project:** ICU Code Blue Early Warning System  
**Version:** 1.0  
**Scope:** Post-deployment monitoring and controlled modification of an ICU early warning decision-support system.

---

## 1. Purpose and Scope

This Predetermined Change Control Plan (PCCP) defines the **anticipated, bounded modifications** for the ICU Code Blue Early Warning System following initial deployment.

The system is intended as a **non-diagnostic clinical decision support tool** that surfaces patient-hours entering elevated short-term risk for cardiac arrest. No automated clinical actions are taken based on model output.

This PCCP emphasizes **operational safety, alert burden control, and generalization stability**, rather than continuous model optimization.

---

## 2. Anticipated Modifications

### 2.1 Alerting Policy Adjustments (Primary Control)

- **Modification:** Adjustment of alert debouncing windows (e.g., 6h → 12h cooldown).
- **Rationale:** Operational tuning to align alert volume with ICU capacity.
- **Constraints:**  
  - No increase in total alert rate beyond predefined capacity limits.  
  - Debounced first-crossing logic must remain intact.

Alert policy changes are preferred over retraining when addressing alert fatigue or workflow misalignment.

---

### 2.2 Threshold Recalibration (Secondary Control)

- **Modification:** Recalibration of the fixed alert budget (default: top 0.5% of patient-hours).
- **Rationale:** Changes in staffing, census, or monitoring tolerance.
- **Constraints:**  
  - Thresholds remain rank-based, not probability-based.  
  - Changes must be evaluated under identical test conditions.

Thresholds are treated as **capacity decisions**, not learned parameters.

---

### 2.3 Model Retraining (Tertiary Control)

- **Modification:** Retraining of the existing **logistic regression model** using updated data.
- **Rationale:** Sustained degradation in ranking quality or alert enrichment.
- **Non-goals:**  
  - No architecture changes  
  - No feature expansion without separate review  
  - No change to intended clinical use

Retraining is expected to be **infrequent** relative to alert policy adjustments.

---

## 3. Monitoring Plan

### 3.1 Operational Monitoring (Primary)

- Alerts per shift
- Alerts per unique patient
- Debounced vs baseline alert volume
- First-crossing alert frequency

These metrics are reviewed regularly and act as early indicators of workflow risk.

---

### 3.2 Performance Monitoring (Secondary)

- Precision at fixed alert rate
- Event enrichment relative to baseline prevalence
- Recall at the chosen alert budget (informational only)

Global metrics (e.g., ROC-AUC) are monitored for stability, not optimization.

---

### 3.3 Data Integrity Monitoring

- Feature missingness rates
- Score distribution drift
- Changes in lab or vital documentation frequency

---

## 4. Validation Protocol for Changes

Any proposed modification must demonstrate:

- No increase in alert burden beyond predefined limits
- No degradation in event enrichment at the fixed alert rate
- Stable behavior across held-out hospitals (when applicable)

All evaluations are conducted on sequestered test data prior to deployment.

---

## 5. Risk Assessment and Mitigation

| Risk | Mitigation |
|----|----|
| Alert fatigue | Fixed alert budgets and debounced first-crossing logic |
| Distribution drift | Continuous score and missingness monitoring |
| Automation bias | Alerts are advisory only; no automated actions |
| Silent degradation | Regular review of alert volume and enrichment |

---

## 6. Human-in-the-Loop Oversight

- All changes are reviewed by clinical and operational stakeholders prior to deployment.
- Clinicians retain full discretion over interpretation and response.
- The system may be down-ranked or disabled without retraining if alert burden exceeds tolerance.

---

## 7. Summary

This PCCP reflects a system design where **deployment safety is governed primarily by alert policy**, not by continuous model retraining. Modifications are intentionally constrained to preserve interpretability, trust, and operational alignment in high-acuity ICU environments.
