-- Execute the production predicates on adversarial timestamp boundaries.
ASSERT (
  WITH cases AS (
    SELECT * FROM UNNEST([
      STRUCT('known_before' AS name,600 AS t,590 AS draw,595 AS revision,TRUE AS expected),
      STRUCT('revision_in_future',600,590,660,FALSE),
      STRUCT('revision_at_prediction',600,590,600,FALSE),
      STRUCT('unknown_revision',600,590,CAST(NULL AS INT64),FALSE),
      STRUCT('draw_in_future_revision_earlier',600,610,590,FALSE),
      STRUCT('draw_at_prediction',600,600,590,FALSE),
      STRUCT('lookback_lower_inclusive',600,240,590,TRUE),
      STRUCT('too_old_draw_recent_revision',600,239,590,FALSE),
      STRUCT('earlier_revision_known_draw',600,590,580,TRUE)
    ])
  ), evaluated AS (
    SELECT *, IFNULL(draw >= t-360 AND draw < t AND revision IS NOT NULL
      AND GREATEST(draw,revision) < t,FALSE) AS actual
    FROM cases
  )
  SELECT COUNT(*)=9 AND COUNTIF(actual!=expected)=0 FROM evaluated
) AS 'PIT availability boundary fixture failed';
SELECT 9 AS boundary_cases_passed;
