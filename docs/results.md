# Results — 2.0.0-pit

The executed final model is `bqml_lr_v4_pit`, using point-in-time lab availability
and the explicit hospital-validation set. Its held-out predictions are
`preds_test_v4_pit`. The original `bqml_lr_v3` and `preds_test_v3` are preserved.
New exports live in `artifacts/reference_run_v4_pit/`; historical exports remain
in `artifacts/reference_run/`. Exact queries, job IDs, model metadata, and all
old/new comparisons are in [the version audit](../audit/2026-09-05/pit_v4/REPORT.md).

| Metric | Original v3 | PIT + CUSTOM final |
|---|---:|---:|
| Cohort stays | 177,418 | 177,418 |
| Labeled stays / proxy-positive stays | 171,833 / 1,401 | 171,833 / 1,401 |
| Train / validation / test hospitals | 135 / 42 / 31 | 135 / 42 / 31 |
| Held-out patient-hours / positive windows | 2,078,011 / 310 | 2,078,011 / 310 |
| Raw global top-0.5% alerts / TP | 10,391 / 21 | 10,391 / 36 |
| PPV | 0.2021% | 0.3465% |
| Positive-window recall | 6.77% | 11.61% |
| Pooled enrichment | 13.55x | **23.22x** |
| 95% hospital-cluster enrichment CI | 7.20–27.03 | **11.45–41.53** |
| Within-hospital AUROC, row-weighted / median | 0.6110 / 0.6887 | **0.7348 / 0.7827** |
| Within-hospital AP, median | 0.1092% | 0.1294% |
| Positive-alert hospitals | 7/31 | **9/31** |
| Hospital-mix expected TP | 1.1794 | 1.4433 |
| Observed / hospital-mix expected | 17.81x | 24.94x |
| Global BQML ROC-AUC | 0.6377 | 0.7292 |
| Held-out log loss | 0.002723 | **0.007776** |
| Constant training-prevalence log loss | 0.001502 | 0.001502 |
| First crossing: alerts / TP / PPV | 3,350 / 8 / 0.2388% | 2,040 / 8 / 0.3922% |
| 12h quiet-period debounce: alerts / TP / PPV | 2,650 / 7 / 0.2642% | 1,596 / 8 / 0.5013% |

The new data show within-hospital ranking signal for a documentation proxy:
19/21 evaluable hospitals have AUROC above 0.5, and observed positive alerts
exceed the hospital-mix expectation by 24.94x. This remains sparse evidence:
36 positive windows from 22 stays, concentrated in nine hospitals. It is not an
adjudicated cardiac-arrest endpoint or evidence of clinical benefit.

The base rate is **310/2,078,011 patient-hours = 0.014918%**, not stay prevalence.
The 0.5% policy is applied globally to the complete test corpus, not separately
within hospitals. Within-hospital AUROC/AP summaries use the 21 hospitals with
both classes. The full [hospital comparison](../audit/2026-09-05/pit_v4/HOSPITAL_COMPARISON.md)
reports every hospital, including undefined metrics. The bootstrap samples
31 whole hospitals with replacement 100,000 times, seed 20260905, keeping
observed alert memberships fixed. Its wide CI does not include retraining or
establish statistical significance of the old/new difference.

**Log loss worsened and is 5.18 times the constant training-prevalence baseline.**
It measures probabilistic prediction quality, not ranking alone. This refutes a
claim of superior absolute probability estimates; it does not refute the
independently measured ranking improvement.

Q1 measured **574,482 exposed historical feature rows**, including 106,328 test
rows and 35 positive test windows, before regeneration. The corrected features
remove exactly those contributions without changing cohort rows, labels, split
assignments, or vital features. No contributing numeric lab records had unknown
revision offsets; the explicit NULL policy excludes records with unknown
availability.

The fixed final model uses all 444 positive hospital-validation windows and
completed nine iterations. The prespecified same-feature AUTO_SPLIT control
reserved only four positives, completed 18 iterations, and selected 38 TP
(24.51x). It was not substituted for the final model. No threshold was tuned.
See the audit for all coefficients and actual BQML split counts.

The canonical persistence-tier query and its assertion passed on the new run;
new [tier aggregates](../audit/2026-09-05/pit_v4/tier_metrics.csv) replace no
historical defective tier claims. The raw enrichment headline is independent
of first crossing, debouncing, or persistence tiers.

An additional reconciliation found 7,823 rows (1,469 test rows, including one
positive window) with last-lab changes outside Q1 exposure. All were explained
by the deterministic highest-lab-ID draw-time tie rule already present in SQL
before this pass. The old/new comparison therefore includes that inherited
change as well as PIT availability and validation; it is not a pure estimate
of the availability correction alone. The same-feature control isolates the
validation-split comparison.
