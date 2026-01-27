## Methodology

### Label Construction
Cardiac arrest events were identified using diagnosis and treatment records
containing CPR, defibrillation, ACLS, or code blue terminology.
To reduce label leakage, events occurring within the first 6 hours of ICU
admission were excluded.

### Temporal Alignment
Data were aligned using minute offsets from ICU admission.
Features at time t only used data from [t-6h, t).

### Splitting Strategy
To assess generalization across institutions, hospitals were split using a
hash-based partition into train (70%), validation (15%), and test (15%) sets.

### Evaluation Strategy
Given extreme class imbalance (~0.025% event rate), evaluation focused on
precision at fixed alert rates rather than accuracy or F1 score.
