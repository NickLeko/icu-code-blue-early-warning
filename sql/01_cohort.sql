-- 01_cohort.sql
-- Base cohort: eICU unit stays with numeric age 18-120 and LOS >= 6h.
-- Top-coded '> 89' and other nonnumeric/missing ages are excluded by SAFE_CAST.
-- Unit type is not filtered; this is not an enforced ICU-only subset.
-- The later discharge-bounded grid requires LOS >= 8h to produce a row.
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
  p.hospitaldischargeoffset       -- minutes from ICU/unit admit
FROM `physionet-data.eicu_crd.patient` p
WHERE SAFE_CAST(p.age AS FLOAT64) BETWEEN 18 AND 120
  AND p.unitdischargeoffset IS NOT NULL
  AND p.unitdischargeoffset >= 360;  -- at least 6 hours in ICU
