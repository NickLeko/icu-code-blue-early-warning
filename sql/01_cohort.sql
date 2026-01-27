-- 01_cohort.sql
-- Build ICU stay cohort
-- Output: {{PROJECT_ID}}.icu_ml.cohort_v1

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.cohort_v1` AS
SELECT
  patientunitstayid,
  uniquepid,
  patienthealthsystemstayid,
  hospitalid,
  gender,
  SAFE_CAST(age AS FLOAT64) AS age,
  unitadmitsource,
  unittype,
  unitvisitnumber,
  unitdischargeoffset,
  hospitaldischargeoffset
FROM `physionet-data.eicu_crd.patient`
WHERE SAFE_CAST(age AS FLOAT64) BETWEEN 18 AND 120
  AND unitdischargeoffset >= 360;

