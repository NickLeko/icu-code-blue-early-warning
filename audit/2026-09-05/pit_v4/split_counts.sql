SELECT split, COUNT(*) AS n_rows, SUM(y) AS positive_windows, COUNT(DISTINCT hospitalid) AS hospitals FROM `{{PROJECT_ID}}.icu_ml.model_table_v4_pit` GROUP BY split ORDER BY split;
