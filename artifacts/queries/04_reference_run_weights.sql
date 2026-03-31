-- Reviewer-facing model weights for the published final model.

SELECT
  processed_input,
  weight
FROM ML.WEIGHTS(MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`)
ORDER BY ABS(weight) DESC, processed_input;
