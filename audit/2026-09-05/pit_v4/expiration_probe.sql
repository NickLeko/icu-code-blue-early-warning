-- Capability check only: no source data; expires after one hour if permitted.
-- Tests whether a table-specific expiration avoids changing dataset defaults.
CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.icu_ml.pit_v4_capability_probe`
OPTIONS (expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR))
AS SELECT 1 AS capability_probe;
