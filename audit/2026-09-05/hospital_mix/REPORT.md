# Hospital-mix audit: executed results

Executed 2026-09-05 on existing BigQuery tables in `citric-glow-485600-f4.icu_ml` (US). Authenticated using the existing application-default credentials; the initial DNS failure was resolved by executing outside the network sandbox. No new credentials were required. No training, prediction generation, table replacement, or pipeline editing occurred. Source-table metadata before and after is identical for all four checked tables. These are newly executed read-only diagnostic results, not simulated results or regenerated model outputs.

**Finding:** Hospital mix does not explain the 13.55× pooled enrichment. Holding alert allocation by hospital fixed, random selection within each hospital predicts only 1.1794 positive windows; the model selected 21, or 17.81× that expectation. Its allocation actually lowers the expected positive rate relative to uniform patient-hour selection. Within-hospital ranking signal exists for this retrospective documentation proxy, but performance is heterogeneous: only seven hospitals produce any positive alerts, the median top-cutoff within-hospital lift is zero, and the row-weighted within-hospital AUROC is 0.611. This supports an overall within-hospital signal, not reliable performance in every hospital or established clinical early warning.

## 1. Executed Q6 and exact decomposition

| Quantity | Result |
|---|---:|
| Test patient-hour rows | 2,078,011 |
| Positive windows | 310 |
| Alerts | 10,391 |
| Observed positive alerts | 21 |
| Pooled prevalence | 0.0149181% |
| Alert PPV | 0.2020980% |
| Pooled enrichment | 13.547155× |
| Expected positives under uniform row selection | 1.550140976 |
| Expected positives with observed hospital allocation | **1.179374062** |
| Observed / hospital-mix expectation | **17.80605550×** |
| Hospital-mix enrichment factor | **0.760817293×** |

Let `N_h,K_h,A_h,T_h` denote hospital rows, positives, allocated alerts, and true-positive windows. The null expectation is `E = Σ A_h K_h/N_h`. The exact multiplicative decomposition is:

`pooled lift = [(E/A)/(K/N)] × [T/E] = 0.760817293 × 17.80605550 = 13.54715495`.

Hospital allocation alone would reduce enrichment below one. It does not produce the 13.55× result. This comparator preserves allocation but randomizes which patient-hours are selected within each hospital; it is not a clinical-standard-of-care comparator or a causal analysis.

**Volume-weighted within-hospital lift:** `Σ N_h L_h / Σ N_h = 20.2531×`, where `L_h=(T_h/A_h)/(K_h/N_h)`. This row-volume weighting includes the **19 hospitals with A_h>0 and K_h>0**, covering 1,971,463 rows (94.8726% of test rows). Ten zero-positive hospitals and two positive hospitals with no alerts have undefined lift and are excluded, not assigned zero. Among those 19 defined values, 12 are zero and seven exceed one; the median is zero. The alert-volume-weighted average over defined hospitals is 15.4421×. Neither arithmetic average is identical to the exact `T/E` decomposition, whose weights are hospital expected-positive counts.

Thus the evidence is not the “pooled lift but within-hospital average near one” pattern. Nor does it show strong top-cutoff lift in most hospitals: successful detections are concentrated in a minority.

## 2. Alert concentration

The five largest alert allocations are:

| Hospital | Alerts | Share of all alerts | Share of all rows | Alert-share / row-share | Base prevalence |
|---|---:|---:|---:|---:|---:|
| 443 | 3,874 | 37.282% | 14.211% | 2.623× | 0.003725% |
| 73 | 1,680 | 16.168% | 20.456% | 0.790× | 0.015762% |
| 252 | 1,435 | 13.810% | 10.852% | 1.273× | 0.028825% |
| 300 | 1,200 | 11.548% | 11.947% | 0.967× | 0.004834% |
| 318 | 773 | 7.439% | 3.286% | 2.264× | 0.002929% |

These five receive **86.2477% of alerts for 60.7516% of rows**. The three largest receive 67.2601% of alerts for 45.5189% of rows. Hospital 443, the largest recipient, has prevalence about one-quarter of pooled prevalence and within-hospital AUROC 0.5008; hospital 300 has AUROC 0.2820 and no true-positive alerts. This is substantial inefficient allocation, not concentration in high-prevalence hospitals.

Define high prevalence explicitly as `K_h/N_h > 310/2078011`. Those **12 hospitals contain 50.8273% of rows and 249/310 positives but receive only 3,973 alerts (38.2350%)**. Alert-allocation-weighted hospital prevalence is 0.0113500%, below the population row prevalence of 0.0149181%. Zero-positive hospitals receive 90 alerts.

## 3. Variance and confidence intervals

- **31** assigned test hospitals; all 31 contribute prediction rows.
- **7** hospitals receive zero alerts: 93, 136, 156, 342, 399, 414, 447.
- **10** hospitals have zero positive windows: 83, 93, 108, 136, 156, 212, 262, 310, 342, 447.
- **7** hospitals contribute the 21 true-positive windows, representing **14 distinct proxy-positive stays**. There are 160 distinct stays with positive evaluation windows. These remain documentation proxies, not adjudicated arrests.
- Pooled enrichment: **13.55×; 95% hospital-cluster percentile bootstrap CI 7.20×–27.03×**.
- Hospital-mix-adjusted observed/expected ratio: **17.81×; 95% hospital-cluster bootstrap CI 10.07×–33.65×**.

Method: 100,000 paired resamples, each drawing 31 hospitals uniformly with replacement, NumPy `default_rng` seed 20260905. Sum each sampled hospital's complete `(N_h,K_h,A_h,T_h,E_h)` vector and recompute the ratios. Repeated patient-hours remain together inside the hospital cluster. There were no undefined-ratio replicates; 35 replicates had zero true positives and were retained as zero, not dropped.

**Estimand:** These intervals are conditional on the stored fitted model and observed global-policy alert membership. They do not retrain, reselect a cutoff, or rerank duplicated hospitals at exactly 0.5% in every replicate; the replicate alert fraction can vary. This is cluster uncertainty for the observed policy, not uncertainty of the entire model-development procedure. Thirty-one clusters and seven contributing hospitals limit precision; the intervals do not address endpoint validity or availability leakage.

## 4. Within-hospital ranking sanity check

Computed directly from stored scores. AUROC awards half credit for ties; average precision is the stepwise precision-recall sum with tied scores processed together, not trapezoidal PR-AUC. Both metrics are undefined for the ten hospitals with no positives and reported as missing. All 21 positive hospitals also have negative rows.

| Metric across the 21 positive hospitals | Minimum | Q1 | Median | Q3 | Maximum |
|---|---:|---:|---:|---:|---:|
| AUROC | 0.2820 | 0.5426 | **0.6887** | 0.8694 | 0.9990 |
| Average precision, % | 0.00345 | 0.06268 | **0.10919** | 0.25387 | 8.11688 |
| AP / hospital prevalence | 0.713× | 2.091× | **5.910×** | 21.399× | 721.956× |

- 19/21 AUROCs exceed 0.5; 13/21 are at least 0.6.
- Row-volume-weighted within-hospital AUROC is **0.6110**.
- Hospitals below 0.5: **123 (0.4874)** and **300 (0.2820)**.
- Hospital 443 is effectively chance at **0.5008**, despite the largest alert allocation.
- Hospital 67's 0.9990 AUROC and 8.1169% AP rely on only **two positive windows from one stay**. Other tiny positive counts likewise make extreme per-hospital point estimates unstable. An AUROC merely above 0.5 is not evidence of statistically established skill in that hospital.

The distribution is not uniformly near chance, but an unweighted median alone would conceal weaker performance in large hospitals. Absolute precision remains low.

## 5. Complete hospital-level results

“—” denotes an undefined ratio/metric, not zero. PPV is undefined with zero alerts; lift is undefined with zero alerts or zero prevalence; ranking metrics here are undefined with zero positives. Percent columns contain percentages, not fractions. `per_hospital.csv` preserves full precision and adds expected positives and relative allocation.

| Hospital | Rows | Positive windows | Base % | Alerts | TP | PPV % | Within lift | Row share % | Alert share % | AUROC | AP % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 67 | 17,789 | 2 | 0.01124 | 66 | 2 | 3.03030 | 269.53 | 0.856 | 0.635 | 0.9990 | 8.11688 |
| 73 | 425,080 | 67 | 0.01576 | 1,680 | 6 | 0.35714 | 22.66 | 20.456 | 16.168 | 0.6534 | 1.13018 |
| 83 | 2,340 | 0 | 0.00000 | 7 | 0 | 0.00000 | — | 0.113 | 0.067 | — | — |
| 93 | 2,286 | 0 | 0.00000 | 0 | 0 | — | — | 0.110 | 0.000 | — | — |
| 108 | 12,899 | 0 | 0.00000 | 31 | 0 | 0.00000 | — | 0.621 | 0.298 | — | — |
| 123 | 8,360 | 4 | 0.04785 | 1 | 0 | 0.00000 | 0.00 | 0.402 | 0.010 | 0.4874 | 0.04811 |
| 136 | 65 | 0 | 0.00000 | 0 | 0 | — | — | 0.003 | 0.000 | — | — |
| 155 | 32,711 | 15 | 0.04586 | 48 | 0 | 0.00000 | 0.00 | 1.574 | 0.462 | 0.5497 | 0.20977 |
| 156 | 198 | 0 | 0.00000 | 0 | 0 | — | — | 0.010 | 0.000 | — | — |
| 171 | 62,074 | 28 | 0.04511 | 111 | 3 | 2.70270 | 59.92 | 2.987 | 1.068 | 0.5905 | 0.82363 |
| 176 | 151,758 | 34 | 0.02240 | 407 | 0 | 0.00000 | 0.00 | 7.303 | 3.917 | 0.5426 | 0.03255 |
| 180 | 29,403 | 2 | 0.00680 | 23 | 0 | 0.00000 | 0.00 | 1.415 | 0.221 | 0.9516 | 0.10582 |
| 208 | 178,578 | 20 | 0.01120 | 279 | 2 | 0.71685 | 64.01 | 8.594 | 2.685 | 0.7159 | 0.25387 |
| 212 | 818 | 0 | 0.00000 | 6 | 0 | 0.00000 | — | 0.039 | 0.058 | — | — |
| 227 | 74,976 | 14 | 0.01867 | 198 | 0 | 0.00000 | 0.00 | 3.608 | 1.905 | 0.7395 | 0.11035 |
| 244 | 58,042 | 8 | 0.01378 | 30 | 0 | 0.00000 | 0.00 | 2.793 | 0.289 | 0.8628 | 0.34990 |
| 245 | 26,795 | 2 | 0.00746 | 20 | 0 | 0.00000 | 0.00 | 1.289 | 0.192 | 0.5140 | 0.01140 |
| 252 | 225,499 | 65 | 0.02882 | 1,435 | 4 | 0.27875 | 9.67 | 10.852 | 13.810 | 0.6887 | 0.10919 |
| 262 | 5,812 | 0 | 0.00000 | 3 | 0 | 0.00000 | — | 0.280 | 0.029 | — | — |
| 300 | 248,260 | 12 | 0.00483 | 1,200 | 0 | 0.00000 | 0.00 | 11.947 | 11.548 | 0.2820 | 0.00345 |
| 310 | 52,356 | 0 | 0.00000 | 43 | 0 | 0.00000 | — | 2.520 | 0.414 | — | — |
| 318 | 68,276 | 2 | 0.00293 | 773 | 0 | 0.00000 | 0.00 | 3.286 | 7.439 | 0.8860 | 0.06268 |
| 342 | 6,203 | 0 | 0.00000 | 0 | 0 | — | — | 0.299 | 0.000 | — | — |
| 399 | 13,609 | 4 | 0.02939 | 0 | 0 | — | — | 0.655 | 0.000 | 0.8694 | 0.18041 |
| 402 | 15,265 | 2 | 0.01310 | 63 | 0 | 0.00000 | 0.00 | 0.735 | 0.606 | 0.8551 | 0.06685 |
| 414 | 8,842 | 2 | 0.02262 | 0 | 0 | — | — | 0.426 | 0.000 | 0.9256 | 0.22188 |
| 433 | 10,937 | 5 | 0.04572 | 11 | 0 | 0.00000 | 0.00 | 0.526 | 0.106 | 0.5078 | 0.09560 |
| 443 | 295,309 | 11 | 0.00372 | 3,874 | 2 | 0.05163 | 13.86 | 14.211 | 37.282 | 0.5008 | 0.01115 |
| 445 | 14,513 | 6 | 0.04134 | 6 | 0 | 0.00000 | 0.00 | 0.698 | 0.058 | 0.6804 | 0.08295 |
| 447 | 1,120 | 0 | 0.00000 | 0 | 0 | — | — | 0.054 | 0.000 | — | — |
| 459 | 27,838 | 5 | 0.01796 | 76 | 2 | 2.63158 | 146.52 | 1.340 | 0.731 | 0.8785 | 4.13331 |

## 6. Integrity, provenance and reproduction

Read-only Q6 job: `job_yqYWr2Nm8Y1xyJgVj_DbcKCPitCC`.

Read-only integrity job: `job_7xyYlbrpzV0NybAV6RFz8PPd7XgS`.

Read-only AUROC/AP job: `job_MQB7xNoPQHuFXcXXCndy3AG3b52P`.

All three job records report `statementType=SELECT` and `cacheHit=false`. Prediction/test keys match exactly; no duplicate prediction/test keys, duplicate cohort keys, label disagreements, bad scores, invalid labels, or prediction hospitals outside the test split were found. The 31 assigned test hospitals all have predictions. The table metadata did not change across execution. SQL, aggregate API responses with job statistics, metadata, CSV, and the bootstrap script are saved alongside this report. No patient-level rows or credentials are exported.

Files:

- `q6.sql`: the requested Q6, unchanged except project substitution.
- `within_hospital.sql`: exact score-tie-aware ranking metrics.
- `integrity.sql`: join/key/label/split checks.
- `*_result.json`: executed aggregate responses and job statistics.
- `metadata_before.json`, `metadata_after.json`: source object binding.
- `per_hospital.csv`, `summary.json`: derived descriptive results.
- `analyze.py`: reproduces CSV, distributions, and cluster intervals from real aggregate responses; run `python3 analyze.py` (requires NumPy).
- `bq_read.py`: read-only API runner using existing application-default credentials; `dry` validates and estimates scans; `query` executes the supplied SELECT. It contains no embedded credentials.

The analysis rejects hospital mix as the explanation for the pooled uplift. An honest headline is: **“Retrospective documentation-proxy ranking: 13.55× pooled enrichment (hospital-cluster 95% CI 7.20–27.03), with 17.81× observed/expected yield after accounting for hospital allocation; performance varies substantially across hospitals.”** This finding does not repair or validate the separate temporal and clinical-endpoint issues recorded in the original audit.
