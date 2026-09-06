-- Actual BQML AUTO_SPLIT temporary tables.
SELECT 'train' AS split,COUNT(*) AS n_rows,SUM(y) AS positive_windows FROM `citric-glow-485600-f4._36bcb2cf34934f993413629ae0991d97aa09a6a7.anon270910ae_5975_42d9_8377_745041385bfc_imported_data_split_training_data`
UNION ALL
SELECT 'eval' AS split,COUNT(*) AS n_rows,SUM(y) AS positive_windows FROM `citric-glow-485600-f4._36bcb2cf34934f993413629ae0991d97aa09a6a7.anon270910ae_5975_42d9_8377_745041385bfc_imported_data_split_eval_data`;
