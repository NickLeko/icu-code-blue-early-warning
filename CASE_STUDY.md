# Case Study: ICU Code Blue Early Warning Model

## Context & Motivation

In-hospital cardiac arrest (“code blue”) events are rare but catastrophic.  
Clinicians operate under severe attention constraints, and many early warning systems either:

- generate excessive alerts (alert fatigue), or  
- optimize retrospective metrics that do not map to real workflows  

The goal of this project was **not** to build the most complex model possible, but to explore whether a **simple, interpretable risk model** could meaningfully enrich clinical attention under **realistic alerting constraints**.

---

## Problem Definition

**Clinical question:**  
Can we identify ICU patient-hours at elevated short-term risk of cardiac arrest (within 2 hours) early enough to support clinical awareness?

**Operational constraint:**  
Alerts must be extremely sparse to be usable (≪1% of patient-hours).

**Workflow context (informal):**
- ICU clinicians monitor dozens of patients simultaneously  
- Alert fatigue becomes prohibitive above ~1–2% alert rates  
- The model must support prioritization, not continuous interruption  

These constraints fundamentally shaped the modeling and evaluation strategy.

---

## Key Design Decisions & Tradeoffs

### 1. Framing the Task Around Alert Budgets

**Decision:**  
Optimize and evaluate the model using **precision at fixed alert rates**, rather than accuracy or F1.

**Rationale:**  
In clinical environments, *how many alerts fire* matters more than aggregate discrimination.  
A model that performs well at a 0.5% alert rate is more actionable than one with higher AUC but excessive alerts.

**Tradeoff:**  
Sacrifices headline metrics in favor of workflow realism.

---

### 2. Choosing Simplicity Over Model Complexity

**Decision:**  
Use L2-regularized logistic regression instead of deep learning.

**Rationale:**  
- Improves interpretability and calibration  
- Easier to audit and reason about  
- More aligned with hospital governance expectations  

This model was designed to be **inspectable and defensible**, not opaque.

**Tradeoff:**  
Potentially lower ceiling performance compared to more complex architectures.

---

### 3. Hospital-Level Validation Instead of Random Splits

**Decision:**  
Evaluate using **hospital-level holdout splits**.

**Rationale:**  
Random splits can leak institution-specific practice patterns and inflate performance.  
Holding out entire hospitals better approximates real-world generalization.

**Tradeoff:**  
More conservative performance estimates (ROC-AUC dropped ~0.12 vs. random splits).

---

### 4. Explicit Feature Exclusions to Reduce Leakage

**Decision:**  
Exclude:
- Provider identifiers  
- Room or bed numbers  
- Shift or staffing indicators  

**Rationale:**  
These variables risk encoding care patterns rather than patient physiology.  
The goal was to predict **patient risk**, not infer who was delivering care.

**Tradeoff:**  
Potential loss of predictive signal in exchange for safer generalization.

---

### 5. Treating the Model as a Ranking System, Not an Oracle

**Decision:**  
Use the model strictly for **risk ranking**, not absolute probability interpretation.

**Rationale:**  
Ranking at fixed alert rates is more robust to distribution shift than relying on calibrated probabilities.

---

## What Worked Well

- At a **0.5% alert rate**, the model achieved **~18× risk enrichment**  
  (precision ≈ 0.44% vs. baseline prevalence ≈ 0.025%)
- ROC-AUC ≈ **0.73** on held-out hospitals  
- At operational alert rates, the model would surface roughly **1 true event per ~227 alerts**, compared to ~1 per 4,000 patient-hours under random screening

These results suggest the model can meaningfully concentrate clinical attention despite the rarity of events.

---

## Potential User Impact (Hypothetical)

**For bedside nurses:**
- Focus attention on the highest-risk patients during prioritization
- Reduce cognitive load from uniformly monitoring all patients

**For charge nurses / unit leads:**
- Support escalation decisions and resource allocation
- Provide objective backing for early intervention discussions

**For hospital quality teams:**
- Enable retrospective review of near-miss events
- Provide a measurable signal for early deterioration detection

All impact claims are hypothetical and would require prospective validation.

---

## Known Failure Modes & Risks

- **Care-pattern confounding:**  
  Lab ordering frequency and monitoring intensity may partially drive predictions.

- **Calibration drift:**  
  As standards of care evolve, absolute risk estimates may degrade.

- **Feedback loops:**  
  If alerts trigger earlier interventions (e.g., fluids, escalation, monitoring), some predicted arrests may be prevented.  
  This can make the model appear “less accurate” over time even as outcomes improve—a success mode masquerading as a failure.

These risks informed the decision to frame the model strictly as **decision support**, not automation.

---

## What This Model Is *Not*

This model is not:
- Deployment-ready  
- Externally validated  
- Intended to replace clinician judgment  
- Suitable for provider performance evaluation  

These boundaries are intentionally explicit.

---

## Lessons Learned

**What I would do differently:**
- Start with a vitals-only baseline before adding labs  
- Integrate calibration analysis earlier in evaluation  
- Document feature importance sooner for clinical face validity  

**What surprised me:**
- Trend features (slopes) added limited value  
- Measurement frequency was highly predictive  
- Hospital-level splits exposed how much apparent performance comes from institutional memorization

**What this taught me about healthcare ML:**
- Evaluation design matters more than model architecture  
- Temporal correctness is easy to get wrong  
- Clinicians care far more about false positives than AUC  

---

## What I Would Do Next With More Resources

1. External validation on an independent dataset (e.g., MIMIC-IV)  
2. Subgroup performance analysis (demographics, ICU type)  
3. Calibration stability assessment across hospitals  
4. Prospective silent-mode testing  
5. Exploration of representation learning to reduce feature engineering  

---

## Key Takeaways

- In healthcare ML, **operational realism beats metric optimization**  
- Simpler models can be safer and more governable  
- Designing for failure modes is as important as optimizing performance  

---

## Why This Case Study Matters

This case study is intentionally written to demonstrate:
- Product judgment under real-world constraints  
- Awareness of governance, ethics, and deployment risks  
- Willingness to trade performance for trust and safety  

These considerations are central to successful healthcare AI products.
