-- DRY RUN ONLY: validates model options against existing schema. Do not submit.
-- 08_bqml_models.sql
-- PIT v4: fixed logistic-regression specification, with the explicit hospital
-- validation split used for early stopping. No test rows enter CREATE MODEL.
-- No hyperparameter sweep or threshold selection is performed.
-- Output model: `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit`

CREATE OR REPLACE MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['y'],
  l2_reg = 1.0,
  max_iterations = 50,
  data_split_method = 'CUSTOM',
  data_split_col = 'is_validation',
  early_stop = TRUE,
  min_rel_progress = 0.01
) AS
SELECT
  y,
  split = 'val' AS is_validation,  -- split column is excluded from model inputs

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
WHERE split IN ('train', 'val');

-- Note:
--   TRUE routes all validation-hospital rows to BQML evaluation; FALSE routes
--   training-hospital rows to fitting. Early stopping deliberately remains on,
--   with the prior 1% progress criterion and 50-iteration cap made explicit.

-- Optional evaluation snippets (run manually)
-- Test:
-- SELECT *
-- FROM ML.EVALUATE(
--   MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit`,
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
