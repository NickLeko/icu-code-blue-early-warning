# Decision Log

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
