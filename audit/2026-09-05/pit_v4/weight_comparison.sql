WITH original AS (
 SELECT processed_input,weight FROM ML.WEIGHTS(MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v3`)
), control AS (
 SELECT processed_input,weight FROM ML.WEIGHTS(MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit_autosplit_control`)
), final AS (
 SELECT processed_input,weight FROM ML.WEIGHTS(MODEL `{{PROJECT_ID}}.icu_ml.bqml_lr_v4_pit`)
)
SELECT COALESCE(o.processed_input,c.processed_input,f.processed_input) AS feature,
 o.weight AS old_weight,c.weight AS pit_auto_weight,f.weight AS pit_custom_weight,
 f.weight-c.weight AS custom_minus_auto_weight
FROM original o FULL OUTER JOIN control c USING(processed_input)
FULL OUTER JOIN final f USING(processed_input)
ORDER BY feature;
