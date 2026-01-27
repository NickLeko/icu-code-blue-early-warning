## Methodology

### Cohort
Adult ICU stays (age 18–120) with ≥6 hours ICU length of stay.

### Label Construction
Cardiac arrest events identified using treatment and diagnosis records
containing CPR, defibrillation, ACLS, or code-blue terminology.
To reduce contamination from pre-ICU events, labels occurring within the first
6 hours of ICU admission were excluded.

### Temporal Alignment
All features at time t are computed using data from [t−6h, t).
Rows at or after the event time are excluded from training.

### Splitting Strategy
Hospitals are assigned to train/validation/test splits using a hash-based
partition to assess cross-institution generalization.

### Evaluation
Given extreme class imbalance, models are evaluated using ranking-based metrics,
with primary emphasis on precision at fixed alert rates rather than default
classification thresholds.
