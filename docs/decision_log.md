# Decision Log

## 2026-09-05: Version 2.0.0-pit — availability and validation correction

- Enforced lab availability at the later of draw/revised-entry offset, strictly before prediction; unknown revision offsets exclude records.
- Measured original Q1 exposure before regeneration: 574,482 modeled rows, including 106,328 test rows and 35 positive test windows.
- Set CUSTOM hospital validation and explicit early stopping (TRUE, 1% progress, 50-iteration cap); retained the 49-feature logistic model, L2=1 and fixed global top-0.5% rule.
- Preserved cohort, labels, vitals, and hospital assignments; documented top-coded age exclusion, absence of a unit-type filter, effective eight-hour eligibility, full-stay early-event exclusion, and the correct offset time origin.
- Regenerated outputs under `v4_pit` and saved exact query/job metadata. Final enrichment is 23.22x (hospital-cluster CI 11.45–41.53), PPV 0.3465%, recall 11.61%, 36 TP in 10,391 alerts. Within-hospital AUROC is 0.7348 row-weighted and 0.7827 median; positive alerts occur in 9/31 hospitals.
- Published worse log loss (0.007776 versus constant baseline 0.001502) alongside improved ranking. No score cutoff or model was selected to preserve performance.
- Preserved the original v3 exports and added a prespecified AUTO_SPLIT diagnostic control for split-effect attribution. See `audit/2026-09-05/pit_v4/REPORT.md` for old/new tables and remaining limitations.

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
