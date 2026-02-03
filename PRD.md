# Product Requirements Document (PRD)
## ICU Code Blue Early Warning System

**Author:** Nicholas Leko  
**Status:** Final (Retrospective PRD)  
**Last Updated:** January 2026  

---

## 1. Problem Statement

In ICU settings, cardiac arrest events are rare but catastrophic. Existing monitoring systems generate frequent alarms, contributing to alert fatigue and reducing clinician trust. There is a need for a system that **prioritizes clinical attention toward the highest-risk patient-hours** without overwhelming staff.

The core problem is **not detection**, but **actionable prioritization under constrained attention**.

---

## 2. Target Users & Stakeholders

### Primary Users
- ICU clinicians (nurses, physicians) responsible for patient monitoring

### Secondary Stakeholders
- ICU leadership
- Clinical operations
- Quality & safety teams
- Data science / ML engineering

---

## 3. Goals & Non-Goals

### Goals
- Identify ICU patient-hours at elevated short-term risk of cardiac arrest
- Operate under a **fixed alert budget** to prevent alert fatigue
- Surface alerts that are interpretable and operationally feasible
- Enable safe evaluation prior to any live deployment

### Non-Goals
- Diagnosing cardiac arrest
- Automating treatment decisions
- Maximizing recall at the expense of alert burden
- Real-time bedside monitoring replacement
- External validation or regulatory submission

---

## 4. Product Scope

### In Scope
- Hourly risk scoring of ICU patient-hours
- Ranking-based prioritization
- Post-model alerting policy design (debouncing, cooldowns)
- Offline and silent-mode evaluation

### Out of Scope
- Continuous real-time streaming inference
- Computer vision or waveform analysis
- Automated escalation protocols
- Integration with EHR front-end systems

---

## 5. Decision Being Supported

**Decision:**  
> “Which ICU patient-hours should receive *additional clinical attention* in the next 2 hours, given limited staff capacity?”

The system supports **prioritization**, not diagnosis or intervention.

---

## 6. Success Metrics

### Primary Metric
- **Precision at fixed alert rate** (top 0.5% of patient-hours)

### Secondary Metrics
- Event enrichment relative to baseline prevalence
- Alert volume per shift
- Alerts per unique patient
- Stability of alert rate over time

### Explicitly Deprioritized Metrics
- Accuracy
- Default-threshold F1
- Recall maximization without alert constraints

---

## 7. Constraints & Guardrails

- Alert rate must remain within predefined capacity limits
- Alerts must be rank-based, not probability-threshold-based
- System must tolerate missing or delayed data gracefully
- False positives are acceptable; alert overload is not

---

## 8. Evaluation & Rollout Plan

### Offline Evaluation
- Hospital-level holdout split
- Retrospective precision and enrichment analysis

### Silent Mode
- Run end-to-end on live data without clinician exposure
- Monitor alert rates, drift, and system stability

### Shadow Mode
- Display alerts without actionability
- Collect qualitative clinician feedback

### Live Deployment
- Limited rollout with rollback controls
- Governance review prior to expansion

---

## 9. Risks & Mitigations

| Risk | Mitigation |
|----|----|
| Alert fatigue | Fixed alert budgets, debounced alerts |
| Model overfitting | Hospital-level generalization testing |
| Workflow mismatch | Shadow mode and clinician feedback |
| Silent degradation | Monitoring of alert volume and enrichment |

---

## 10. Stopping Criteria

This project intentionally stops after:
- Demonstrating feasible alert enrichment under realistic constraints
- Designing and validating post-model alerting policies
- Establishing monitoring and change control boundaries

Further model complexity is unlikely to yield proportional gains without prospective validation.

---

## 11. Dependencies

- Access to ICU EHR data (eICU)
- Batch processing infrastructure (BigQuery)
- Clinical stakeholder engagement for shadow-mode evaluation

---

## 12. Open Questions (Deferred)

- Prospective clinical impact on outcomes
- Performance variation by ICU subtype
- Long-term drift behavior across calendar years

These are intentionally deferred pending real-world evaluation.

---

## Summary

This PRD defines a **capacity-aware ICU early warning system** where success is governed by alert policy and workflow alignment rather than model complexity. All subsequent artifacts (Model Card, PCCP, Case Study) derive from the decisions locked in this document.