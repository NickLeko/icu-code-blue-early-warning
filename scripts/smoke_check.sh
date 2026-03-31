#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

required_files=(
  "README.md"
  "RUN.md"
  "artifacts/README.md"
  "artifacts/queries/01_reference_run_counts.sql"
  "artifacts/queries/02_reference_run_operating_point.sql"
  "artifacts/queries/03_reference_run_alert_policy.sql"
  "artifacts/queries/04_reference_run_weights.sql"
  "artifacts/queries/05_reference_run_ml_evaluate.sql"
  "MODEL_CARD.md"
  "CASE_STUDY.md"
  "docs/methodology.md"
  "docs/change_policy.md"
  "docs/decision_log.md"
  "docs/hypothetical_deployment/PCCP.md"
  "docs/hypothetical_deployment/SECURITY_THREAT_MODEL.md"
  "docs/reviewer_guide.md"
  "docs/results.md"
  "docs/reproducibility.md"
  "docs/supporting/CITATION.md"
  "docs/supporting/FAILURE_MODES.md"
  "docs/supporting/INTENDED_USE.md"
  "docs/supporting/PRD.md"
  "docs/validation_checklist.md"
  "scripts/prepare_sql.sh"
)

required_sql=(
  "sql/01_cohort.sql"
  "sql/02_labels.sql"
  "sql/03_features_vitals.sql"
  "sql/04_features_labs.sql"
  "sql/05_train_rows.sql"
  "sql/06_splits.sql"
  "sql/07_model_table.sql"
  "sql/08_bqml_models.sql"
  "sql/09_eval_alert_rate.sql"
  "sql/10_eval_temporal_alert_tiers.sql"
  "sql/11_eval_first_crossing_cooldown.sql"
)

echo "Checking required documentation files..."
for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || { echo "Missing required file: $file" >&2; exit 1; }
done

echo "Checking SQL pipeline files..."
for file in "${required_sql[@]}"; do
  [[ -f "$file" ]] || { echo "Missing SQL file: $file" >&2; exit 1; }
done

echo "Checking PROJECT_ID placeholders in SQL..."
for file in "${required_sql[@]}"; do
  if ! grep -q '{{PROJECT_ID}}' "$file"; then
    echo "Expected placeholder {{PROJECT_ID}} not found in $file" >&2
    exit 1
  fi
done

echo "Checking README references..."
grep -q 'docs/reproducibility.md' README.md || {
  echo "README is missing reproducibility doc reference" >&2
  exit 1
}
grep -q 'docs/decision_log.md' README.md || {
  echo "README is missing decision log reference" >&2
  exit 1
}
grep -q 'docs/reviewer_guide.md' README.md || {
  echo "README is missing reviewer guide reference" >&2
  exit 1
}
grep -q 'docs/validation_checklist.md' README.md || {
  echo "README is missing validation checklist reference" >&2
  exit 1
}
grep -q 'docs/change_policy.md' README.md || {
  echo "README is missing change policy reference" >&2
  exit 1
}
grep -q 'artifacts/README.md' README.md || {
  echo "README is missing proof-artifacts reference" >&2
  exit 1
}
grep -q 'make smoke' README.md || {
  echo "README is missing smoke-check instruction" >&2
  exit 1
}

echo "Checking doc cross-references..."
grep -q 'RUN.md' CASE_STUDY.md || {
  echo "CASE_STUDY.md should reference RUN.md" >&2
  exit 1
}
grep -q 'bqml_lr_v3' docs/results.md || {
  echo "docs/results.md should reference final model artifact" >&2
  exit 1
}
grep -q 'preds_test_v3' docs/results.md || {
  echo "docs/results.md should reference prediction artifact" >&2
  exit 1
}
grep -q 'sql/08_bqml_models.sql' docs/methodology.md || {
  echo "docs/methodology.md should reference final model definition" >&2
  exit 1
}
grep -q 'docs/change_policy.md' docs/reproducibility.md || {
  echo "docs/reproducibility.md should reference change policy" >&2
  exit 1
}
grep -q 'docs/validation_checklist.md' docs/reviewer_guide.md || {
  echo "docs/reviewer_guide.md should reference validation checklist" >&2
  exit 1
}
grep -q 'sql/02_labels.sql' docs/change_policy.md || {
  echo "docs/change_policy.md should enumerate sensitive SQL files" >&2
  exit 1
}

echo "Checking SQL numbering sequence..."
expected=1
for file in sql/*.sql; do
  number="${file#sql/}"
  number="${number%%_*}"
  if [[ "$number" != "$(printf "%02d" "$expected")" ]]; then
    echo "Unexpected SQL numbering sequence at $file" >&2
    exit 1
  fi
  expected=$((expected + 1))
done

echo "Smoke check passed."
