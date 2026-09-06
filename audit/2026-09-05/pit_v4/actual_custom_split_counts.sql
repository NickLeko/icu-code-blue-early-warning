-- BQML temporary split tables from the completed model metadata.
SELECT 'train' AS split,COUNT(*) AS n_rows,SUM(y) AS positive_windows FROM `citric-glow-485600-f4._36bcb2cf34934f993413629ae0991d97aa09a6a7.anonfb7ffe24_c973_4e78_9bd8_a1bd0a22ddfa_imported_data_split_training_data`
UNION ALL
SELECT 'val' AS split,COUNT(*) AS n_rows,SUM(y) AS positive_windows FROM `citric-glow-485600-f4._36bcb2cf34934f993413629ae0991d97aa09a6a7.anonfb7ffe24_c973_4e78_9bd8_a1bd0a22ddfa_imported_data_split_eval_data`;
