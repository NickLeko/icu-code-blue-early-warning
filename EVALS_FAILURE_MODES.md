# EVALS_FAILURE_MODES.md
## Evaluation Strategy, Failure Modes, and Safety Analysis

**Project:** ICU Code Blue Early Warning System  
**Author:** Nicholas Leko  
**Last Updated:** January 2026  

---

## 1. Purpose of This Document

This document formalizes the **evaluation philosophy, failure mode analysis, and safety considerations** for the ICU Code Blue Early Warning System.

It is intentionally separate from model training details and metrics to make explicit:
- how the model is judged,
- how it can fail,
- why those failures are acceptable or mitigated, and
- which safeguards exist outside the model itself.

This artifact is designed to support:
- clinical governance review,
- silent-mode deployment decisions,
- regulatory discussions,
- and AI product risk assessment.

---

## 2. Evaluation Philosophy

### 2.1 Why Conventional Metrics Are Insufficient

In ICU early warning systems, **class imbalance is extreme** (≈0.025% event rate per patient-hour). Under these conditions:

- Accuracy is meaningless  
- Default-threshold F1 optimizes the wrong tradeoff  
- Recall maximization creates unmanageable alert fatigue  

A model with excellent ROC-AUC can still be operationally unusable if it fires too often.

---

### 2.2 Primary Evaluation Question

> **Given a fixed and very limited alert budget, does the system meaningfully concentrate clinical attention on patient-hours at elevated short-term risk?**

This framing treats the model as a **ranking system under capacity constraints**, not a classifier.

---

## 3. Primary Evaluation Metric

### Precision at Fixed Alert Rate (Top 0.5%)

**Definition:**  
Among the top **0.5% highest-risk patient-hours**, what fraction experience a documented cardiac arrest / CPR event within the next 2 hours?

**Why 0.5%?**
- Corresponds to ~1 alert per 200 patient-hours
- Aligns with ICU attention constraints
- Forces explicit tradeoffs between sensitivity and usability

**Interpretation:**  
Precision at a fixed alert rate measures **actionable signal**, not global discrimination.

- Baseline prevalence ≈ 0.025%  
- Observed precision ≈ 0.44%  
- Result: **~18× risk enrichment**

---

## 4. Secondary Metrics (Supporting, Not Optimized)

The following metrics are monitored for **sanity and stability**, not maximization:

- ROC-AUC — global ranking quality check  
- Log loss — probabilistic calibration check  
- Alert volume per patient — operational burden indicator  

---

## 5. Temporal Evaluation: Why Static Alerts Fail

### 5.1 The Persistence Problem

Naively alerting on every hour that exceeds a risk threshold leads to:
- repeated alerts on the same patient,
- inflated alert counts,
- diminishing marginal information.

Empirically, persistent alerts exhibited **lower precision** than first-time alerts.

**Key insight:**  
Time spent above a threshold is not equivalent to increasing risk.

---

## 6. Post-Model Alerting Strategies (Evaluated)

### 6.1 Persistence Tier Analysis (Diagnostic)

Alerts were categorized by consecutive duration:

- **Tier 1:** first alert hour  
- **Tier 2:** second consecutive alert hour  
- **Tier 3:** ≥3 consecutive alert hours  

**Finding:**  
Tier 3 alerts dominated alert volume while contributing less incremental signal.

This analysis was used **to reject persistence-based alerting**, not to deploy it.

---

### 6.2 First-Crossing Alerts with Cooldown (Preferred)

**Definition:**  
An alert fires only when a patient *enters* the extreme-risk set (top 0.5%), with subsequent alerts suppressed for a fixed cooldown window.

Cooldowns evaluated:
- 0 hours
- 6 hours
- 12 hours

**Result:**  
Debounced first-crossing alerts:
- reduced alert volume by ~80%,
- improved precision per alert,
- aligned with clinician expectations of “new risk.”

**Safety interpretation:**  
Risk *transitions* carry more actionable information than sustained elevation.

---

## 7. Known Failure Modes

This section explicitly enumerates **how the system can fail**, why those failures occur, and how they are mitigated.

---

### 7.1 False Positives (Expected and Accepted)

**Description:**  
Alerts may fire for patients who do not experience cardiac arrest.

**Why it happens:**
- Physiologic instability does not always progress to arrest
- Early intervention may prevent events (success masquerading as error)

**Mitigation:**
- Fixed alert budgets limit total burden
- Alerts are advisory, not prescriptive
- First-crossing + cooldown reduces repeated noise

---

### 7.2 Care-Pattern Confounding

**Description:**  
Lab ordering frequency and monitoring intensity may partially drive predictions.

**Why it happens:**
- Sicker patients receive more frequent labs and monitoring
- Measurement frequency encodes implicit clinician concern

**Mitigation:**
- Explicit exclusion of provider, bed, and staffing identifiers
- Hospital-level holdout validation
- Transparent documentation of this limitation

---

### 7.3 Calibration Drift

**Description:**  
Absolute risk scores may drift as care practices evolve.

**Why it happens:**
- Changes in ICU protocols
- Documentation or coding changes
- Population shifts

**Mitigation:**
- Risk scores used for **ranking**, not absolute probability
- Thresholds treated as capacity decisions
- Alert policy adjustment preferred over retraining

---

### 7.4 Feedback Loops

**Description:**  
If alerts prompt earlier intervention, some predicted arrests may be prevented.

**Why it matters:**
- Model performance may appear to degrade even as outcomes improve

**Mitigation:**
- Model positioned strictly as decision support
- Avoid using outcomes alone as performance signal
- Monitor alert stability alongside event rates

---

### 7.5 Distribution Shift Across Hospitals

**Description:**  
Performance may vary across institutions.

**Why it happens:**
- Different staffing models
- Different monitoring intensity
- Different ICU subtypes

**Mitigation:**
- Hospital-level validation
- Requirement for local retrospective validation
- No assumption of cross-institution equivalence

---

## 8. Safety Boundaries and Guardrails

### Explicit Guardrails
- Fixed alert budget (default 0.5%)
- Rank-based alerting (not probability thresholds)
- Debounced first-crossing logic
- No automated clinical actions

### Operational Kill Switches
- Alerting policy can be disabled without retraining
- Thresholds can be tightened if burden exceeds tolerance
- Model retraining is a last resort

---

## 9. What This System Does *Not* Attempt to Solve

This system explicitly does **not**:
- guarantee arrest prediction,
- maximize recall,
- infer causality,
- optimize long-term outcomes,
- replace clinician judgment.

Solving these problems would require:
- prospective clinical trials,
- workflow redesign,
- and additional governance structures.

---

## 10. Summary

This evaluation framework treats early warning as a **capacity-constrained prioritization problem**, not a classification problem.

Key principles:
- optimize usable signal, not headline metrics,
- design alerting logic explicitly,
- surface failure modes rather than hide them,
- prefer operational controls over model complexity.



## Why This File Matters

Most healthcare ML failures are **evaluation failures**, not modeling failures.

By making evaluation, failure modes, and safeguards explicit, this project prioritizes:
- patient safety,
- clinician trust,
- and responsible deployment over theoretical performance.
