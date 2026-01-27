-- 02_labels.sql
-- Build event labels (documented CPR / code-blue-like events).
-- Uses treatment (high-specificity) + diagnosis (supporting) signals.
-- Applies a minimum lead-time filter to reduce pre-ICU / ED documentation artifacts.
-- Output: `{{PROJECT_ID}}.icu_ml.labels_v2`

-- (A) Diagnosis-based candidate events
CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.event_dx_v1` AS
SELECT
  patientunitstayid,
  MIN(diagnosisoffset) AS event_offset_min,
  'diagnosis' AS source
FROM `physionet-data.eicu_crd.diagnosis`
WHERE diagnosisoffset IS NOT NULL
  AND (
    LOWER(diagnosisstring) LIKE '%cardiac arrest%'
    OR LOWER(diagnosisstring) LIKE '%cardiorespiratory arrest%'
    OR LOWER(diagnosisstring) LIKE '%asystol%'
    OR LOWER(diagnosisstring) LIKE '%ventricular fibrillation%'
    OR LOWER(diagnosisstring) LIKE '%ventricular tachycardia%'
    OR LOWER(diagnosisstring) LIKE '%vfib%'
    OR LOWER(diagnosisstring) LIKE '%vtach%'
  )
GROUP BY patientunitstayid;

-- (B) Treatment-based candidate events (more specific than diagnosis)
CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.event_tx_v2` AS
SELECT
  patientunitstayid,
  MIN(treatmentoffset) AS event_offset_min,
  'treatment' AS source
FROM `physionet-data.eicu_crd.treatment`
WHERE treatmentoffset IS NOT NULL
  AND (
    LOWER(treatmentstring) LIKE '%cpr%'
    OR LOWER(treatmentstring) LIKE '%cardiopulmonary resuscitation%'
    OR LOWER(treatmentstring) LIKE '%defibrillat%'
    OR LOWER(treatmentstring) LIKE '%acls%'
    OR LOWER(treatmentstring) LIKE '%code blue%'
  )
GROUP BY patientunitstayid;

-- (C) Final label per ICU stay: earliest event from dx/tx, with lead-time filter >= 6h
CREATE OR REPLACE TABLE `{{PROJECT_ID}}.icu_ml.labels_v2` AS
SELECT
  c.patientunitstayid,
  MIN(e.event_offset_min) AS event_offset_min
FROM `{{PROJECT_ID}}.icu_ml.cohort_v1` c
LEFT JOIN (
  SELECT patientunitstayid, event_offset_min FROM `{{PROJECT_ID}}.icu_ml.event_dx_v1`
  UNION ALL
  SELECT patientunitstayid, event_offset_min FROM `{{PROJECT_ID}}.icu_ml.event_tx_v2`
) e
ON c.patientunitstayid = e.patientunitstayid
GROUP BY c.patientunitstayid
HAVING event_offset_min IS NULL OR event_offset_min >= 360;

-- Optional sanity check (run manually; not required for pipeline)
-- SELECT
--   COUNT(*) AS n_stays,
--   COUNTIF(event_offset_min IS NOT NULL) AS n_positive_stays,
--   SAFE_DIVIDE(COUNTIF(event_offset_min IS NOT NULL), COUNT(*)) AS prevalence,
--   APPROX_QUANTILES(event_offset_min, 10)[OFFSET(5)] AS median_event_min
-- FROM `{{PROJECT_ID}}.icu_ml.labels_v2`;

