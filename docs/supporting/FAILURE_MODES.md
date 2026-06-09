# Failure Modes & If-Deployed Safety Analysis  
## ICU Code Blue Early Warning System

**Author:** Nicholas Leko  
**Version:** 1.0  
**Last Updated:** June 2026  
**Scope:** Retrospective evaluation failures plus hypothetical deployment misuse risks and safety guardrails  
**Related Artifacts:** docs/supporting/PRD.md, MODEL_CARD.md, docs/hypothetical_deployment/PCCP.md, CASE_STUDY.md

---

## 1. Purpose

This document enumerates **how the model and surrounding workflow can fail**,
why those failures occur, and how they are **bounded, mitigated, or governed**.

It intentionally goes beyond offline metrics to address:
- evaluation failures under extreme class imbalance,
- temporal and workflow-induced failures,
- human–AI interaction risks (automation bias),
- governance and post-deployment risks.

This is a companion reasoning artifact for the retrospective repo, not evidence
of an implemented deployment program.

---

## 2. System Context (What Is Being Analyzed)

### 2.1 System Summary
- **Inputs:** Structured ICU vitals and labs (batch, hourly)
- **Model:** L2-regularized logistic regression producing hourly risk scores
- **Post-model logic:** Ranking, first-crossing detection, cooldown-based debouncing
- **Outputs:** Retrospective alert-policy analyses; if deployed, advisory alerts for prioritization only (no automation)

### 2.2 Safety Posture
- Decision support, not diagnosis
- Fixed alert budgets
- Human-in-the-loop at all times
- Operational controls prioritized over model complexity

---

## 3. Evaluation Failures (Why “Good Metrics” Can Still Be Unsafe)

### 3.1 Why Conventional Metrics Fail Here

With a **very low event rate at the patient-hour level**:
- Accuracy is meaningless
- Default-threshold F1 optimizes the wrong tradeoff
- Recall maximization produces unmanageable alert fatigue

A model can have strong ROC-AUC and still be **clinically unusable**.

**Primary evaluation question:**
> *Given a fixed and very limited alert budget, does the system meaningfully concentrate attention on patient-hours at elevated short-term risk?*

---

### 3.2 Capacity-Constrained Evaluation (Accepted Approach)

**Primary metric:** Precision at a fixed alert rate (top **0.5%** of patient-hours)

This metric directly measures **actionable signal under real attention constraints**.

Because the corrected `sql/04_features_labs.sql` construction changes
downstream model inputs, exact prevalence / precision / enrichment values
should be regenerated from `artifacts/queries/` after rerunning the pipeline.

**Secondary metrics (monitored, not optimized):**
- ROC-AUC (global ranking sanity check)
- Log loss (probabilistic stability)
- Alert volume per patient (operational burden)

---

### 3.3 Prediction Grid Uses Discharge Time as a Future Endpoint

**Confirmed limitation:**  
The prediction grid in `sql/03_features_vitals.sql` is generated with
`GENERATE_ARRAY(360, c.unitdischargeoffset - 120, 60)` and then constrained by
`c.unitdischargeoffset - t_hour >= 120`.

This means every scored prediction time is selected using the ICU discharge
offset. In retrospective BigQuery analysis that timestamp is available, but in
deployment the system would not know a patient's future ICU discharge time.

**Impact:**  
The evaluation grid is conditioned on future information and excludes the final
2 hours of each ICU stay from downstream training/scoring rows. Those final
hours are clinically important and may contain many deterioration events.

**Required if-deployed correction:**  
A live system would need a different grid termination strategy, such as rolling
hourly scoring from admission while data remain available, or scoring triggered
by real-time observation availability. The checked-in metrics should therefore
be read as retrospective ranking results on this discharge-bounded grid, not as
evidence of a deployment-valid scoring schedule.

---

### 3.4 Outcome Offset Is Documentation Entry Time, Not Adjudicated Event Time

**Confirmed limitation:**  
The label query uses `MIN(diagnosisoffset)` and `MIN(treatmentoffset)` from
eICU diagnosis and treatment tables. eICU documentation defines these offsets as
the minutes from unit admission when the diagnosis or treatment was entered.

**Impact:**  
The 2-hour prediction horizon is measured against chart-entry time, not an
adjudicated bedside event timestamp. If documentation lags the true code event,
some apparent lead time may be documentation lag. The effective clinical lead
time is therefore 2 hours minus uncharacterized charting lag.

**Boundary:**  
The repo does not estimate charting lag for code-event documentation in eICU.
The reported metrics remain honest for the chart-derived proxy label, but they
should not be interpreted as proof of 2 full hours of clinical lead time before
true arrest.

---

### 3.5 Proxy Label Includes Non-Arrest Ventricular Tachycardia

**Confirmed limitation:**  
`sql/02_labels.sql` includes diagnosis-string matches for `ventricular
tachycardia` and `vtach` without distinguishing pulseless VT from stable or
monitored VT.

**Impact:**  
The positive class can include patients who had ventricular tachycardia but did
not have a code blue or cardiac arrest. This contaminates the proxy outcome,
inflates the positive count with non-arrest events, and reduces the clinical
specificity of the label.

**Boundary:**  
This is still a reproducible documented code-event / resuscitation proxy. It is
not an adjudicated cardiac-arrest registry.

---

### 3.6 Early-Event Stays Are Excluded From the Dataset

**Confirmed limitation:**  
The minimum lead-time filter in `sql/02_labels.sql` is applied with
`HAVING event_offset_min IS NULL OR event_offset_min >= 360` when constructing
`labels_v2`. `sql/05_train_rows.sql` then joins feature rows to `labels_v2`.

**Impact:**  
ICU stays with qualifying events in the first 6 hours fail the `HAVING` clause
and are absent from `labels_v2`, so they are excluded from the downstream
dataset entirely. They are not merely excluded from positive labeling.

This creates survivorship bias in the evaluation population by removing the
highest-acuity rapid-deterioration cases before model training and scoring.

---

## 4. Temporal Failure Modes (Static Alerts Break in Practice)

### 4.1 Persistence-Induced Alert Spam

**Failure:**  
Naively alerting every hour above a threshold repeatedly fires on the same patient, increasing burden without adding information.

**Questions to inspect in this repo:**  
Persistent (≥3 consecutive) alerts may:
- dominate alert volume,
- carry different precision than first alerts.

**Conclusion:**  
Time spent above a threshold ≠ increasing risk.

---

### 4.2 First-Crossing Failure (If Not Debounced)

**Failure:**  
Triggering alerts on every threshold crossing without suppression still leads to clustered alerts during unstable periods.

**Mitigation (Evaluated in repo):**
- **First-crossing alerts** only
- **Cooldown-based debouncing**

This repo includes first-crossing and cooldown analyses so reviewers can inspect
how alert volume and precision shift under suppression policies.

---

## 5. Model-Level Failure Modes

### 5.1 False Positives (Expected and Accepted)

**Description:**  
Alerts may fire for patients who do not arrest.

**Why this happens:**
- Physiologic instability does not always progress
- Early intervention may prevent events (success masquerading as error)

**Mitigations:**
- Fixed alert budgets cap burden
- Alerts are advisory only
- First-crossing + cooldown limits repetition

---

### 5.2 Care-Pattern Confounding

**Description:**  
Measurement frequency and lab ordering encode clinician concern. In the checked
in reference model weights, the largest non-intercept coefficients are dominated
by ABG/lab-derived pH features and lab-count features: `ph_last_6h`,
`ph_min_6h`, `ph_max_6h`, `ph_n_6h`, `ph_mean_6h`, `lactate_n_6h`, and
`creat_n_6h` are all among the top absolute weights. pO2 and pCO2 are not in
the current final feature set.

**Why this happens:**
- Sicker patients are monitored more frequently
- Documentation intensity correlates with risk
- The model can partially learn "clinicians ordered more labs" as a proxy for
  deterioration, which is surveillance bias rather than independent physiologic
  prediction

**Mitigations:**
- Explicit exclusion of provider, bed, and staffing identifiers
- Hospital-level holdout validation
- Transparent documentation of this limitation

---

### 5.3 Calibration Drift

**Description:**  
Absolute probabilities degrade as care practices evolve.

**Why this happens:**
- Protocol changes
- Documentation or coding shifts
- Population drift

**Mitigations:**
- Risk scores used for **ranking**, not absolute probability
- Thresholds treated as capacity decisions
- Alert policy tuning preferred over retraining

---

## 6. System & Workflow Failure Modes

### 6.1 Automation Bias

**Failure:**  
Users over-trust alerts as directives rather than advisory signals.

**Mitigations:**
- Explicit decision-support framing (PRD, Model Card)
- No automated actions
- Human judgment retained at all times

---

### 6.2 Alert Fatigue / Denial of Attention

**Failure:**  
Misconfigured thresholds or policies overwhelm staff.

**Mitigations:**
- Fixed alert budgets
- Debounced first-crossing logic
- Alert volume monitoring per shift
- Governance review for any policy change (PCCP)

This is treated as a **primary safety risk**, not a UX issue.

---

### 6.3 Silent Degradation

**Failure:**  
Model performance degrades while security and uptime remain intact.

**Mitigations:**
- Monitoring of alert enrichment at fixed alert rates
- Feature distribution and missingness tracking
- Preference for policy adjustment before retraining

---

## 7. Governance, Security, and Misuse Risks

### 7.1 Insider Misuse

**Risk:**  
Authorized users alter alerting behavior to suppress or inflate alerts.

**Mitigations:**
- Documented alert policy parameters
- Change control via PCCP
- Auditability of alert volume and enrichment

---

### 7.2 Information Disclosure (PHI)

**Risk:**  
Exposure of patient-identifiable data through logs or exports.

**Mitigations:**
- No raw patient data stored in repo
- Derived features only
- Controlled access via hosting environment

---

### 7.3 Feedback Loops

**Failure:**  
Successful alerts prevent events, making the model appear worse over time.

**Mitigations:**
- Model positioned strictly as decision support
- Monitor alert stability alongside outcome rates
- Avoid outcome-only performance interpretation

---

## 8. Explicit Safety Guardrails

**Design Guardrails**
- Fixed alert budget (default 0.5%)
- Rank-based alerting
- Debounced first-crossing logic
- No automated clinical actions

**Operational Kill Switches**
- Alerting can be disabled without retraining
- Thresholds can be tightened immediately
- Retraining is a last resort (governed by PCCP)

---

## 9. What This System Explicitly Does *Not* Do

This system does **not**:
- guarantee arrest prediction,
- maximize recall,
- infer causality,
- replace clinician judgment,
- operate without human oversight.

These are intentional non-goals.

---

## 10. Summary

Most healthcare AI failures are **not modeling failures**, but:
- evaluation failures,
- workflow mismatches,
- governance gaps,
- or silent degradation.

This document makes those risks explicit and bounded.

**Core principle:**  
Operational controls, alert policy design, and governance matter more than marginal model improvements for safety in high-acuity clinical settings.
