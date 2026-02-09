# Intended Use — ICU Code Blue Early Warning System

## Intended Use (what this is for)
This system is intended to support **clinical decision support** in adult ICU settings by identifying **patient-hours entering elevated short-term risk** of documented cardiac arrest / CPR within the next 2 hours.

The output is a **risk score used for ranking and prioritization under a fixed alert budget**, not a diagnostic determination. The system is designed to be evaluated in **retrospective analysis** and **silent-mode prospective testing** prior to any clinical integration.

## Intended Users
- ICU bedside nurses and charge nurses (primary)
- ICU attending physicians / fellows (secondary)
- ICU quality & safety leadership (secondary)
- Clinical operations / governance committees (oversight)

## Decision Supported (what the user does with it)
> “Which ICU patients should receive additional clinical attention in the next 2 hours, given limited staff capacity?”

This is **prioritization**, not automated escalation, diagnosis, or treatment selection.

## Decision Authority and Human Oversight
- The system **does not** initiate clinical actions.
- Clinicians retain full authority to ignore, defer, or investigate alerts.
- The system should be deployed only with:
  - documented governance oversight,
  - audit logging,
  - a rollback/disable pathway,
  - and periodic review of alert burden and safety signals.

## Not Intended Use (explicit boundaries)
This system is **not** intended to:
- Diagnose cardiac arrest or determine that an arrest is occurring
- Recommend treatments, medication changes, or resuscitation actions
- Replace clinician judgment or ICU monitoring
- Operate autonomously without human review
- Be used outside ICU settings without revalidation
- Be used for provider evaluation, staffing optimization, or performance scoring
- Be used as the sole basis for triage, transfer, discharge, or escalation decisions

## Patient / Context Exclusions (deployment exclusions without additional validation)
This project is validated only within the eICU-CRD context and should be treated as **unvalidated** for:
- pediatric patients
- non-ICU care settings
- hospitals with materially different monitoring/documentation practices
- settings where key inputs (vitals/labs frequency) differ substantially from training distribution

## Safe Failure and Degradation Principles
If deployed, the system should degrade safely:
- Missing or delayed inputs should **reduce confidence** and suppress or down-rank alerts rather than fabricate certainty.
- Operational controls (fixed alert budgets + debouncing/cooldowns) are first-line safeguards against alert fatigue.
- If monitoring detects drift or unstable alert volume, the preferred mitigation is:
  1) adjust alert policy (cooldown / threshold), then
  2) recalibrate, then
  3) retrain only if sustained degradation persists.

## Evaluation and Rollout Expectations (what “responsible use” requires)
Before any live clinical use, the minimum expected steps are:
1. Retrospective evaluation on local data with hospital-specific slice analysis
2. Silent-mode prospective run to measure alert burden, stability, and failure patterns
3. Shadow-mode exposure with clinician feedback (no required action)
4. Limited rollout with rollback controls and governance sign-off
5. Ongoing monitoring for drift, alert burden, and adverse workflow effects
