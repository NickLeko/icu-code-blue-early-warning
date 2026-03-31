# Reviewer Guide

This guide is for hiring managers, interviewers, or collaborators who want the fastest credible walkthrough of the project.

## In 2 Minutes

Read these files in order:

1. `README.md`
2. `docs/results.md`
3. `artifacts/reference_run/`
4. `MODEL_CARD.md`

You should come away with:

- what the project predicts
- what the label actually is and is not
- why the evaluation is capacity-constrained
- what the main result is
- what the system is not claiming

## In 5 Minutes

Read:

1. `README.md`
2. `docs/methodology.md`
3. `docs/results.md`
4. `RUN.md`
5. `artifacts/README.md`
6. `CASE_STUDY.md`

You should come away with:

- how the data pipeline is structured
- where the aggregate proof exports come from
- why hospital-level holdout matters
- why precision at a fixed alert rate is the main metric
- why post-model alerting policy is treated as a first-class design decision

## In 15 Minutes

Read:

1. `README.md`
2. `RUN.md`
3. `docs/methodology.md`
4. `docs/results.md`
5. `artifacts/README.md`
6. `MODEL_CARD.md`
7. `docs/supporting/INTENDED_USE.md`
8. `docs/supporting/FAILURE_MODES.md`
9. `CASE_STUDY.md`

You should come away with:

- the exact workflow from cohort to evaluation
- how to regenerate reviewer-facing counts and operating-point metrics
- the clinical and operational framing
- the major limitations and failure modes
- the governance posture and why the repo stops short of deployment claims

## What Makes This Repo Worth Reviewing

- The modeling choice is intentionally simple and interpretable
- The split strategy is more honest than typical random-split ML demos
- The evaluation is aligned to alert-budget reality rather than headline metrics
- The repo now includes aggregate-only proof queries rather than relying only on prose
- The repo explicitly documents limitations, failure modes, and intended use boundaries

## What Not to Miss

- `sql/02_labels.sql`: label definition is one of the most scientifically sensitive parts
- `sql/04_features_labs.sql`: final feature semantics live here
- `sql/06_splits.sql`: hospital-level split logic is central to the generalization claim
- `sql/09_eval_alert_rate.sql`: this is where the key reported metric is operationalized
- `artifacts/queries/`: this is the reviewer-facing aggregate proof surface
- `sql/11_eval_first_crossing_cooldown.sql`: post-model alert-policy analysis lives here

## Reading the Repo Safely

If you plan to modify the repo, read `docs/reproducibility.md`, `docs/validation_checklist.md`, and `docs/change_policy.md` first. Those documents separate routine maintenance from scientific changes.
