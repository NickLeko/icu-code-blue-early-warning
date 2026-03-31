# Decision Log

## 2026-03-31: Scientific correction and trust-tightening pass

Scope:

- corrected `sql/04_features_labs.sql` to aggregate vitals and labs separately before joining
- tightened outcome wording to a documented code-event / resuscitation proxy label
- removed unreproduced benchmark / model-selection claims
- added aggregate-only proof queries under `artifacts/queries/`
- moved post-deployment governance notes under `docs/hypothetical_deployment/`

Explicitly changed:

- final feature-table construction semantics in `sql/04_features_labs.sql`
- downstream model inputs derived from `features_v3`
- reviewer-facing claims about what the current repo directly reproduces

Explicitly not changed:

- cohort inclusion logic in `sql/01_cohort.sql`
- raw label string-matching logic in `sql/02_labels.sql`
- split assignment algorithm in `sql/06_splits.sql`
- model family (BigQuery ML logistic regression)

Rationale:

The prior `features_v3` construction could multiply raw vitals rows by raw lab
rows inside the same prediction window, which made count-based features
non-defensible. Once corrected, older headline metrics should be treated as
stale until the pipeline is rerun and aggregate proof exports are regenerated.

## 2026-03-27: Phase 1 maintenance and reproducibility pass

Scope:

- README clarity
- reproducibility and run documentation
- repository smoke check
- scientific sensitivity mapping

Explicitly not changed:

- cohort logic
- label definitions
- feature engineering
- preprocessing behavior
- train/validation/test split behavior
- model training behavior
- alerting logic
- evaluation logic
- reported results

## 2026-03-27: Tier 2 maintenance pass

Scope:

- documentation consistency across portfolio artifacts
- helper script to prepare non-canonical runnable SQL copies with `PROJECT_ID` substituted
- additional make targets and repository checks
- change log for future maintenance discipline

Explicitly not changed:

- canonical SQL semantics in `sql/`
- any scientific claims or reported metrics
- any model or evaluation outputs

Rationale:

The repo is a scientific and portfolio artifact. Maintenance changes should improve legibility and reproducibility without silently changing the experiment.

## 2026-03-27: Tier 3 documentation and guardrail pass

Scope:

- reviewer-facing guide
- manual validation checklist
- explicit change policy for sensitive SQL files
- generated-output ignore rules

Explicitly not changed:

- canonical SQL semantics in `sql/`
- any data, model, or evaluation behavior
- any reported metrics or claims

Rationale:

The goal of this tier is stronger review discipline and repo readability, not push-button execution or model iteration.
