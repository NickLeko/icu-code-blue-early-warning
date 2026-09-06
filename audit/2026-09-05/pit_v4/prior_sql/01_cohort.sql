-- 01_cohort.sql
-- Build the base cohort (adult ICU stays) with minimum ICU length of stay.
-- Requires PhysioNet eICU-CRD v2.0 BigQuery access.
-- Output: `{{PROJECT_ID}}.icu_ml.cohort_v1`

CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.cohort_v1` AS
SELECT
  p.patientunitstayid,
  p.uniquepid,
  p.patienthealthsystemstayid,
  p.hospitalid,
  p.gender,
  SAFE_CAST(p.age AS FLOAT64) AS age,
  p.unitadmitsource,
  p.unittype,
  p.unitvisitnumber,
  p.unitdischargeoffset,          -- minutes from ICU admit
  p.hospitaldischargeoffset       -- minutes from hospital admit
FROM `physionet-data.eicu_crd.patient` p
WHERE SAFE_CAST(p.age AS FLOAT64) BETWEEN 18 AND 120
  AND p.unitdischargeoffset IS NOT NULL
  AND p.unitdischargeoffset >= 360;  -- at least 6 hours in ICU

