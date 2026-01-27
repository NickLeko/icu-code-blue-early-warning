## Reproducibility

After obtaining PhysioNet access and enabling BigQuery:

1. Replace `{{PROJECT_ID}}` in all SQL files with your GCP project ID
2. Run SQL files in order:

01_cohort.sql  
02_labels.sql  
03_features_vitals.sql  
04_features_labs.sql  
05_train_rows.sql  
06_splits.sql  
07_model_table.sql  
08_bqml_models.sql  
09_eval_alert_rate.sql

Expected runtime: several minutes per step depending on quota.
