-- 07_model_table.sql
-- Assemble model-ready table with hospital-level split labels.
-- Output: `{{PROJECT_ID}}.icu_ml.model_table_v3`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.model_table_v3` AS
SELECT
  tr.*,
  c.hospitalid,
  s.split
FROM `{{PROJECT_ID}}.icu_ml.train_rows_v3` tr
JOIN `{{PROJECT_ID}}.icu_ml.cohort_v1` c
  USING (patientunitstayid)
JOIN `{{PROJECT_ID}}.icu_ml.split_hospital_v1` s
  USING (hospitalid);

-- Optional sanity check (avoid alias "rows" because BigQuery can treat ROWS as reserved)
-- SELECT split, COUNT(*) AS n, SUM(y) AS n_pos
-- FROM `{{PROJECT_ID}}.icu_ml.model_table_v3`
-- GROUP BY split
-- ORDER BY split;

