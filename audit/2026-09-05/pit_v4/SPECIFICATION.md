# PIT v4 specification fixed before regenerated outcomes

Release: `2.0.0-pit`; BigQuery suffix `v4_pit` (historical `v4` already exists).

- Preserve the existing cohort, labels, hourly grid, hospital assignments,
  feature list, L2=1, maximum 50 iterations, and global `NTILE(200)=1` policy.
- Keep specimen draw time in `[t-360,t)`; require both draw and revised-entry
  timestamps, and `GREATEST(draw, revised-entry) < t`. NULL revision timestamps
  exclude the lab record. Availability is unknown, not assumed at draw time.
- "Last" means latest draw among available records, ties broken by lab ID.
  This does not reconstruct prior versions of a later-revised result.
- Train the released model using `DATA_SPLIT_METHOD='CUSTOM'`, boolean
  `is_validation=(split='val')`, input rows restricted to train/val.
  `EARLY_STOP=TRUE`, `MIN_REL_PROGRESS=0.01` are deliberate settings, retaining
  the prior progress criterion. Test never enters CREATE MODEL.
- One diagnostic control trains on the same PIT features using the prior
  AUTO_SPLIT/early-stop behavior. It is not a candidate for selection as the
  released model. Its purpose is to distinguish the validation-split effect
  from the feature correction; no parameter or policy sweep is performed.
- Retain age eligibility to isolate the information-boundary correction:
  nonnumeric ages, including top-coded '> 89', remain excluded and are now
  documented. No unit-type filter is added; documentation must reflect that.
- Base LOS eligibility remains six hours; modeled rows require at least eight
  hours due to the existing future-discharge-bounded two-hour horizon.
- Before any regeneration, execute Q1 against original v3 model rows. Preserve
  its raw aggregate response and job metadata regardless of new performance.
- Repeat Q6, exact tie-aware hospital AUROC/AP, and paired 100,000-resample
  hospital bootstrap (seed 20260905) using fixed observed alert membership in
  each version. Report old versus new, including concentration and uncertainty.
- Preserve original BigQuery v3/v4 objects and original aggregate exports.
  New results, source metadata, exact SQL hashes and job IDs are separate.
