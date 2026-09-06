-- Check inherited deterministic last-value tie-breaking outside Q1 exposure.
SELECT o.split,o.y,COUNTIF(o.lactate_n_6h=n.lactate_n_6h AND o.ph_n_6h=n.ph_n_6h AND o.k_n_6h=n.k_n_6h AND o.creat_n_6h=n.creat_n_6h AND o.hgb_n_6h=n.hgb_n_6h AND o.wbc_n_6h=n.wbc_n_6h) AS unchanged_count_rows,
COUNTIF((o.lactate_n_6h=n.lactate_n_6h AND o.ph_n_6h=n.ph_n_6h AND o.k_n_6h=n.k_n_6h AND o.creat_n_6h=n.creat_n_6h AND o.hgb_n_6h=n.hgb_n_6h AND o.wbc_n_6h=n.wbc_n_6h) AND (o.lactate_last_6h IS DISTINCT FROM n.lactate_last_6h OR o.ph_last_6h IS DISTINCT FROM n.ph_last_6h OR o.k_last_6h IS DISTINCT FROM n.k_last_6h OR o.creat_last_6h IS DISTINCT FROM n.creat_last_6h OR o.hgb_last_6h IS DISTINCT FROM n.hgb_last_6h OR o.wbc_last_6h IS DISTINCT FROM n.wbc_last_6h)) AS last_value_changes_outside_Q1
FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` o
JOIN `{{PROJECT_ID}}.icu_ml.model_table_v4_pit` n USING(patientunitstayid,prediction_time_min)
GROUP BY o.split,o.y ORDER BY o.split,o.y;
