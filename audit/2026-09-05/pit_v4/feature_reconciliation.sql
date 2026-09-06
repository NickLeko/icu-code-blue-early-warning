-- Independent count-removal reconciliation against pre-fix Q1 exposure.
SELECT COALESCE(o.split,n.split) AS split, COALESCE(o.y,n.y) AS y,
 COUNT(*) AS n_rows,
 COUNTIF(o.patientunitstayid IS NULL OR n.patientunitstayid IS NULL) AS missing_row_keys,
 COUNTIF(o.y IS DISTINCT FROM n.y OR o.hospitalid IS DISTINCT FROM n.hospitalid OR o.split IS DISTINCT FROM n.split) AS label_or_split_changes,
 COUNTIF(o.lactate_n_6h != n.lactate_n_6h OR o.ph_n_6h != n.ph_n_6h OR o.k_n_6h != n.k_n_6h OR o.creat_n_6h != n.creat_n_6h OR o.hgb_n_6h != n.hgb_n_6h OR o.wbc_n_6h != n.wbc_n_6h) AS rows_with_changed_lab_counts,
 COUNTIF(n.lactate_n_6h > o.lactate_n_6h OR n.ph_n_6h > o.ph_n_6h OR n.k_n_6h > o.k_n_6h OR n.creat_n_6h > o.creat_n_6h OR n.hgb_n_6h > o.hgb_n_6h OR n.wbc_n_6h > o.wbc_n_6h) AS rows_with_increased_lab_counts,
 SUM((o.lactate_n_6h-n.lactate_n_6h) + (o.ph_n_6h-n.ph_n_6h) + (o.k_n_6h-n.k_n_6h) + (o.creat_n_6h-n.creat_n_6h) + (o.hgb_n_6h-n.hgb_n_6h) + (o.wbc_n_6h-n.wbc_n_6h)) AS lab_window_pairs_removed,
 COUNTIF(o.hr_mean_6h IS DISTINCT FROM n.hr_mean_6h OR o.hr_min_6h IS DISTINCT FROM n.hr_min_6h OR o.hr_max_6h IS DISTINCT FROM n.hr_max_6h OR o.hr_n_6h IS DISTINCT FROM n.hr_n_6h OR o.rr_mean_6h IS DISTINCT FROM n.rr_mean_6h OR o.rr_min_6h IS DISTINCT FROM n.rr_min_6h OR o.rr_max_6h IS DISTINCT FROM n.rr_max_6h OR o.rr_n_6h IS DISTINCT FROM n.rr_n_6h OR o.sao2_mean_6h IS DISTINCT FROM n.sao2_mean_6h OR o.sao2_min_6h IS DISTINCT FROM n.sao2_min_6h OR o.sao2_n_6h IS DISTINCT FROM n.sao2_n_6h OR o.temp_mean_6h IS DISTINCT FROM n.temp_mean_6h OR o.temp_n_6h IS DISTINCT FROM n.temp_n_6h OR o.sbp_mean_6h IS DISTINCT FROM n.sbp_mean_6h OR o.sbp_min_6h IS DISTINCT FROM n.sbp_min_6h OR o.sbp_n_6h IS DISTINCT FROM n.sbp_n_6h OR o.map_mean_6h IS DISTINCT FROM n.map_mean_6h OR o.map_min_6h IS DISTINCT FROM n.map_min_6h OR o.map_n_6h IS DISTINCT FROM n.map_n_6h) AS rows_with_changed_vitals
FROM `{{PROJECT_ID}}.icu_ml.model_table_v3` o
FULL OUTER JOIN `{{PROJECT_ID}}.icu_ml.model_table_v4_pit` n
 USING(patientunitstayid,prediction_time_min)
GROUP BY split,y ORDER BY split,y;
