# Failure Modes & Safety Analysis  
## ICU Code Blue Early Warning System

**Author:** Nicholas Leko  
**Version:** 1.0  
**Last Updated:** February 2026  
**Scope:** System-level failure modes, evaluation failures, misuse risks, and safety guardrails  
**Related Artifacts:** PRD.md, MODEL_CARD.md, PCCP.md, CASE_STUDY.md

---

## 1. Purpose

This document enumerates **how the system can fail in practice**, why those failures occur, and how they are **bounded, mitigated, or governed**.

It intentionally goes beyond offline metrics to address:
- evaluation failures under extreme class imbalance,
- temporal and workflow-induced failures,
- human–AI interaction risks (automation bias),
- governance and post-deployment risks.

This is the **single source of truth** for failure analysis and safety reasoning for this project.

---

## 2. System Context (What Is Being Analyzed)

### 2.1 System Summary
- **Inputs:** Structured ICU vitals and labs (batch, hourly)
- **Model:** L2-regularized logistic regression producing hourly risk scores
- **Post-model logic:** Ranking, first-crossing detection, cooldown-based debouncing
- **Outputs:** Advisory alerts for prioritization only (no automation)

### 2.2 Safety Posture
- Decision support, not diagnosis
- Fixed alert budgets
- Human-in-the-loop at all times
- Operational controls prioritized over model complexity

---

## 3. Evaluation Failures (Why “Good Metrics” Can Still Be Unsafe)

### 3.1 Why Conventional Metrics Fail Here

With an event rate ≈ **0.025% per patient-hour**:
- Accuracy is meaningless
- Default-threshold F1 optimizes the wrong tradeoff
- Recall maximization produces unmanageable alert fatigue

A model can have strong ROC-AUC and still be **clinically unusable**.

**Primary evaluation question:**
> *Given a fixed and very limited alert budget, does the system meaningfully concentrate attention on patient-hours at elevated short-term risk?*

---

### 3.2 Capacity-Constrained Evaluation (Accepted Approach)

**Primary metric:** Precision at a fixed alert rate (top **0.5%** of patient-hours)

- Baseline prevalence ≈ 0.025%
- Observed precision ≈ 0.44%
- **~18× risk enrichment**

This metric directly measures **actionable signal under real attention constraints**.

**Secondary metrics (monitored, not optimized):**
- ROC-AUC (global ranking sanity check)
- Log loss (probabilistic stability)
- Alert volume per patient (operational burden)

---

## 4. Temporal Failure Modes (Static Alerts Break in Practice)

### 4.1 Persistence-Induced Alert Spam

**Failure:**  
Naively alerting every hour above a threshold repeatedly fires on the same patient, increasing burden without adding information.

**Observed behavior:**  
Persistent (≥3 consecutive) alerts:
- dominated alert volume,
- had *lower* precision than first alerts.

**Conclusion:**  
Time spent above a threshold ≠ increasing risk.

---

### 4.2 First-Crossing Failure (If Not Debounced)

**Failure:**  
Triggering alerts on every threshold crossing without suppression still leads to clustered alerts during unstable periods.

**Mitigation (Adopted):**
- **First-crossing alerts** only
- **Cooldown-based debouncing** (6–12 hours evaluated)

**Effect:**
- ~80% alert volume reduction
- Improved precision per alert
- Better alignment with clinician expectations of “new risk”

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
Measurement frequency and lab ordering encode clinician concern.

**Why this happens:**
- Sicker patients are monitored more frequently
- Documentation intensity correlates with risk

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
