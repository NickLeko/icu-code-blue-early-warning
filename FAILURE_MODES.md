# Failure Modes & Safety Analysis  
## ICU Code Blue Early Warning System

**Author:** Nicholas Leko  
**Version:** 1.0  
**Last Updated:** February 2026  
**Scope:** Known and anticipated failure modes for an ICU clinical decision support system  
**Related Artifacts:** PRD.md, MODEL_CARD.md, PCCP.md, SECURITY_THREAT_MODEL.md, CASE_STUDY.md  

---

## 1. Purpose

This document enumerates **known, anticipated, and structurally plausible failure modes** of the ICU Code Blue Early Warning System.

The intent is not to claim completeness or perfection, but to demonstrate:
- awareness of how the system can fail,
- understanding of which failures are most dangerous,
- and explicit strategies for detection and mitigation.

This analysis is written from a **product safety and deployment perspective**, not a purely statistical one.

---

## 2. Failure Mode Taxonomy

Failure modes are grouped into five categories:

1. **Model performance failures**  
2. **Data and measurement artifacts**  
3. **Temporal and alerting failures**  
4. **Human–AI interaction failures**  
5. **System-level and governance failures**

Each failure mode includes:
- description,
- potential impact,
- detectability,
- mitigation strategy.

---

## 3. Model Performance Failures

### 3.1 False Reassurance (High-Risk Patient Not Flagged)

**Description:**  
The model fails to surface a patient-hour that later progresses to cardiac arrest.

**Impact:**  
Missed opportunity for heightened clinical attention.

**Why this happens:**
- Extreme class imbalance
- Physiologic deterioration that is abrupt or poorly captured
- Events driven by non-physiologic causes (e.g., sudden arrhythmia)

**Detectability:**  
Low at the individual level; moderate in aggregate via recall analysis.

**Mitigations:**
- Model positioned as prioritization support, not exhaustive screening
- Alert budgets chosen to maximize enrichment, not recall
- Emphasis on trend awareness and clinical judgment
- Transparent communication of non-goals in PRD and Model Card

---

### 3.2 Spurious High-Risk Scores (False Positives)

**Description:**  
Patients are flagged as high risk without progressing to arrest.

**Impact:**  
Alert fatigue; erosion of trust.

**Why this happens:**
- Care-pattern confounding (frequent labs, intensive monitoring)
- Chronic instability without acute decompensation

**Detectability:**  
High via alert precision monitoring.

**Mitigations:**
- Fixed alert budgets
- Debounced first-crossing alerts
- Tiered alert analysis showing diminishing value of persistent alerts
- Preference for alert policy tuning over model retraining

---

## 4. Data & Measurement Artifacts

### 4.1 Measurement Frequency Bias

**Description:**  
The model partially learns *how often* patients are measured rather than *what the measurements show*.

**Impact:**  
Over-prioritization of patients receiving more attention rather than those at true physiologic risk.

**Detectability:**  
Moderate via feature importance inspection and subgroup analysis.

**Mitigations:**
- Explicit recognition in Case Study and Model Card
- Summary statistics used instead of raw event counts
- Governance awareness: monitoring frequency changes flagged as potential drift

---

### 4.2 Missing or Delayed Data

**Description:**  
Key labs or vitals are missing or delayed, degrading risk estimation.

**Impact:**  
Unstable scores; unpredictable alert behavior.

**Detectability:**  
High via missingness monitoring.

**Mitigations:**
- Batch scoring cadence (not real-time)
- Feature missingness monitoring
- Rank-based alerting reduces sensitivity to absolute values

---

## 5. Temporal & Alerting Failures

### 5.1 Alert Persistence Without Added Signal

**Description:**  
Repeated alerts on the same patient across consecutive hours without increased predictive value.

**Impact:**  
Alert fatigue without incremental benefit.

**Detectability:**  
High via tiered alert analysis.

**Mitigations:**
- First-crossing alert logic
- Cooldown-based debouncing
- Empirical demonstration that Tier 3 alerts reduce precision

---

### 5.2 Threshold Miscalibration

**Description:**  
Alert thresholds drift from operational capacity due to staffing or census changes.

**Impact:**  
Either excessive alerts or missed prioritization opportunities.

**Detectability:**  
High via alert volume monitoring.

**Mitigations:**
- Thresholds treated as capacity decisions
- Explicit change control via PCCP
- No automatic threshold adaptation

---

## 6. Human–AI Interaction Failures

### 6.1 Automation Bias

**Description:**  
Clinicians over-trust model output and discount contradictory clinical signals.

**Impact:**  
Inappropriate de-escalation or delayed intervention.

**Detectability:**  
Low without qualitative feedback.

**Mitigations:**
- Decision-support-only framing
- No automated actions
- Emphasis on prioritization, not diagnosis
- Human-in-the-loop retained at all times

---

### 6.2 Alert Desensitization

**Description:**  
Clinicians gradually ignore alerts due to perceived low value.

**Impact:**  
Loss of intended benefit even if model performance is stable.

**Detectability:**  
Moderate via alert acknowledgment rates (if available).

**Mitigations:**
- Alert volume minimization
- Emphasis on novelty (first-crossing alerts)
- Governance review if alert precision degrades

---

## 7. System-Level & Governance Failures

### 7.1 Silent Model Drift

**Description:**  
Changes in care practices or documentation reduce model relevance while surface metrics appear stable.

**Impact:**  
Gradual erosion of clinical utility.

**Detectability:**  
Moderate via enrichment and score distribution monitoring.

**Mitigations:**
- Monitoring of alert enrichment over time
- Preference for alert policy adjustment before retraining
- Conservative retraining strategy defined in PCCP

---

### 7.2 Feedback Loop Effects

**Description:**  
Alerts trigger interventions that prevent arrests, making the model appear less accurate over time.

**Impact:**  
False perception of degradation; pressure to “improve” a working system.

**Detectability:**  
Low without careful interpretation.

**Mitigations:**
- Explicit recognition as a success mode
- Avoid naive accuracy-based reevaluation
- Use enrichment and workflow-aligned metrics

---

## 8. Failure Modes Explicitly Accepted

The following are **known and accepted limitations**, given the system’s intended use:

- Incomplete recall of all cardiac arrests  
- Sensitivity to care-pattern differences across hospitals  
- Dependence on documentation quality  
- Lack of prospective clinical validation  

These are documented to prevent scope creep and misuse.

---

## 9. Why This Document Exists

This failure mode analysis demonstrates that:

- Safety is treated as a design problem, not an afterthought  
- Model evaluation extends beyond aggregate metrics  
- Governance decisions are grounded in realistic failure scenarios  

In healthcare AI, **knowing how a system fails is as important as knowing how it performs**.

---

## 10. Summary

This system is intentionally designed to:
- fail *gracefully* rather than catastrophically,
- surface uncertainty rather than conceal it,
- and prioritize trust and usability over maximal automation.

These failure modes inform alerting policy, monitoring strategy, and change control — and are central to any responsible evaluation or future deployment.
