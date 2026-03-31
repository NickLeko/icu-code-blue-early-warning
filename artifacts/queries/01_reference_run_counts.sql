-- Aggregate-only cohort, label, split, and row counts for a completed run.

WITH cohort AS (
  SELECT COUNT(*) AS cohort_stays
  FROM `{{PROJECT_ID}}.icu_ml.cohort_v1`
),
proxy_labels AS (
  SELECT
    COUNT(*) AS labeled_stays,
    COUNTIF(event_offset_min IS NOT NULL) AS positive_proxy_stays,
    SAFE_DIVIDE(COUNTIF(event_offset_min IS NOT NULL), COUNT(*)) AS positive_proxy_stay_prevalence
  FROM `{{PROJECT_ID}}.icu_ml.labels_v2`
),
row_labels AS (
  SELECT
    COUNT(*) AS train_rows,
    COUNTIF(y = 1) AS positive_rows,
    SAFE_DIVIDE(COUNTIF(y = 1), COUNT(*)) AS positive_row_prevalence
  FROM `{{PROJECT_ID}}.icu_ml.train_rows_v3`
),
split_hospitals AS (
  SELECT
    split,
    COUNT(*) AS n_hospitals
  FROM `{{PROJECT_ID}}.icu_ml.split_hospital_v1`
  GROUP BY split
),
split_rows AS (
  SELECT
    split,
    COUNT(*) AS n_rows,
    COUNTIF(y = 1) AS n_positive_rows,
    SAFE_DIVIDE(COUNTIF(y = 1), COUNT(*)) AS row_prevalence
  FROM `{{PROJECT_ID}}.icu_ml.model_table_v3`
  GROUP BY split
)
SELECT
  'cohort' AS metric_group,
  NULL AS split,
  'cohort_stays' AS metric,
  CAST(cohort_stays AS FLOAT64) AS value,
  'cohort_v1' AS source
FROM cohort

UNION ALL

SELECT
  'labels',
  NULL,
  'labeled_stays',
  CAST(labeled_stays AS FLOAT64),
  'labels_v2'
FROM proxy_labels

UNION ALL

SELECT
  'labels',
  NULL,
  'positive_proxy_stays',
  CAST(positive_proxy_stays AS FLOAT64),
  'labels_v2'
FROM proxy_labels

UNION ALL

SELECT
  'labels',
  NULL,
  'positive_proxy_stay_prevalence',
  positive_proxy_stay_prevalence,
  'labels_v2'
FROM proxy_labels

UNION ALL

SELECT
  'rows',
  NULL,
  'train_rows',
  CAST(train_rows AS FLOAT64),
  'train_rows_v3'
FROM row_labels

UNION ALL

SELECT
  'rows',
  NULL,
  'positive_rows',
  CAST(positive_rows AS FLOAT64),
  'train_rows_v3'
FROM row_labels

UNION ALL

SELECT
  'rows',
  NULL,
  'positive_row_prevalence',
  positive_row_prevalence,
  'train_rows_v3'
FROM row_labels

UNION ALL

SELECT
  'split_hospitals',
  split,
  'n_hospitals',
  CAST(n_hospitals AS FLOAT64),
  'split_hospital_v1'
FROM split_hospitals

UNION ALL

SELECT
  'split_rows',
  split,
  'n_rows',
  CAST(n_rows AS FLOAT64),
  'model_table_v3'
FROM split_rows

UNION ALL

SELECT
  'split_rows',
  split,
  'n_positive_rows',
  CAST(n_positive_rows AS FLOAT64),
  'model_table_v3'
FROM split_rows

UNION ALL

SELECT
  'split_rows',
  split,
  'row_prevalence',
  row_prevalence,
  'model_table_v3'
FROM split_rows

ORDER BY metric_group, split, metric;
