### `sql/06_splits.sql`

Hospital-level split (hash-based) so your evaluation generalizes across institutions.

```sql
-- 06_splits.sql
-- Create a hospital-level train/val/test split for honest generalization.
-- Output: `{{PROJECT_ID}}.icu_ml.split_hospital_v1`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.split_hospital_v1` AS
WITH hosp AS (
  SELECT DISTINCT hospitalid
  FROM `{{PROJECT_ID}}.icu_ml.cohort_v1`
),
hashed AS (
  SELECT
    hospitalid,
    MOD(ABS(FARM_FINGERPRINT(CAST(hospitalid AS STRING))), 100) AS bucket
  FROM hosp
)
SELECT
  hospitalid,
  CASE
    WHEN bucket < 70 THEN 'train'
    WHEN bucket < 85 THEN 'val'
    ELSE 'test'
  END AS split
FROM hashed;

-- Optional sanity check (run manually)
-- SELECT split, COUNT(*) AS n_hospitals
-- FROM `{{PROJECT_ID}}.icu_ml.split_hospital_v1`
-- GROUP BY split
-- ORDER BY split;
```

