## Results Summary

The final vitals + labs model demonstrates stable generalization across held-out
hospitals.

At a 0.5% alert rate (≈1 alert per 200 patient-hours), the model identifies
~18× more true cardiac arrest events than random selection using only routinely
available ICU data.

Trend features were evaluated but did not provide additional lift beyond lab
information.

These summary numbers refer to the final BigQuery ML model
`{{PROJECT_ID}}.icu_ml.bqml_lr_v3` and the held-out prediction table
`{{PROJECT_ID}}.icu_ml.preds_test_v3`.

The canonical evaluation queries are:

- `sql/09_eval_alert_rate.sql` for precision at the top 0.5% alert rate
- `sql/10_eval_temporal_alert_tiers.sql` for persistence-tier analysis
- `sql/11_eval_first_crossing_cooldown.sql` for first-crossing cooldown analysis
