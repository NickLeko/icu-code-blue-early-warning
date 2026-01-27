-- 08_bqml_models.sql
-- Train the final BigQuery ML logistic regression model (vitals + labs).
-- Output model: `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`

CREATE OR REPLACE MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['y'],
  l2_reg = 1.0,
  max_iterations = 50
) AS
SELECT
  y,

  -- vitals
  hr_mean_6h, hr_min_6h, hr_max_6h, hr_n_6h,
  rr_mean_6h, rr_min_6h, rr_max_6h, rr_n_6h,
  sao2_mean_6h, sao2_min_6h, sao2_n_6h,
  temp_mean_6h, temp_n_6h,
  sbp_mean_6h, sbp_min_6h, sbp_n_6h,
  map_mean_6h, map_min_6h, map_n_6h,

  -- labs
  lactate_mean_6h, lactate_min_6h, lactate_max_6h, lactate_n_6h, lactate_last_6h,
  ph_mean_6h, ph_min_6h, ph_max_6h, ph_n_6h, ph_last_6h,
  k_mean_6h, k_min_6h, k_max_6h, k_n_6h, k_last_6h,
  creat_mean_6h, creat_min_6h, creat_max_6h, creat_n_6h, creat_last_6h,
  hgb_mean_6h, hgb_min_6h, hgb_max_6h, hgb_n_6h, hgb_last_6h,
  wbc_mean_6h, wbc_min_6h, wbc_max_6h, wbc_n_6h, wbc_last_6h

FROM `{{PROJECT_ID}}.icu_ml.model_table_v3`
WHERE split = 'train';

-- Optional evaluation snippets (run manually)
-- Test:
-- SELECT *
-- FROM ML.EVALUATE(
--   MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`,
--   (
--     SELECT
--       y,
--       hr_mean_6h, hr_min_6h, hr_max_6h, hr_n_6h,
--       rr_mean_6h, rr_min_6h, rr_max_6h, rr_n_6h,
--       sao2_mean_6h, sao2_min_6h, sao2_n_6h,
--       temp_mean_6h, temp_n_6h,
--       sbp_mean_6h, sbp_min_6h, sbp_n_6h,
--       map_mean_6h, map_min_6h, map_n_6h,
--       lactate_mean_6h, lactate_min_6h, lactate_max_6h, lactate_n_6h, lactate_last_6h,
--       ph_mean_6h, ph_min_6h, ph_max_6h, ph_n_6h, ph_last_6h,
--       k_mean_6h, k_min_6h, k_max_6h, k_n_6h, k_last_6h,
--       creat_mean_6h, creat_min_6h, creat_max_6h, creat_n_6h, creat_last_6h,
--       hgb_mean_6h, hgb_min_6h, hgb_max_6h, hgb_n_6h, hgb_last_6h,
--       wbc_mean_6h, wbc_min_6h, wbc_max_6h, wbc_n_6h, wbc_last_6h
--     FROM `{{PROJECT_ID}}.icu_ml.model_table_v3`
--     WHERE split = 'test'
--   )
-- );

