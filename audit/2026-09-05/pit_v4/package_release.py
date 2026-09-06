"""Package exact local SQL/output hashes and verify release evidence consistency."""
import csv,datetime,hashlib,json,platform
from pathlib import Path
import numpy as np
R=Path(__file__).resolve().parent;REPO=R.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dec(path):
 d=json.loads(path.read_text());return [{f['name']:c.get('v') for f,c in zip(d['schema']['fields'],r['f'])} for r in d.get('rows',[])]
summary=json.loads((R/'release_summary.json').read_text());n=summary['new']
assert (n['N'],n['K'],n['A'],n['TP'])==(2078011,310,10391,36)
assert n['hospital_cluster_bootstrap']['resamples']==100000
assert all(int(r['unexplained_feature_cells'])==0 for r in dec(R/'jobs/last_value_tie_explanation_fixed_result.json'))
tier=dec(R/'jobs/tier_metrics_result.json');assert sum(int(r['n_alerts']) for r in tier)==n['A'];assert sum(int(r['n_positive_windows']) for r in tier)==n['TP']
q1=dec(R/'q1_reference_exposure_result.json');assert sum(int(r['windows_with_future_entered_value']) for r in q1)==574482
for p in REPO.glob('audit/**/*.json'):
 d=json.loads(p.read_text())
 def check(v):
  if isinstance(v,dict):
   assert not ({'access_token','refresh_token','private_key','client_secret','billingAccountName'}&set(v)),p
   for x in v.values():check(x)
  elif isinstance(v,list):
   for x in v:check(x)
 check(d)
files=list((REPO/'sql').glob('*.sql'))+list((REPO/'artifacts/queries').glob('*.sql'))+list(R.glob('*.sql'))+list(R.glob('*.py'))+list((REPO/'artifacts/reference_run_v4_pit').glob('*.csv'))
jobs=[]
for p in sorted((R/'jobs').glob('*_submission.json')):
 submission=json.loads(p.read_text());name=p.name.removesuffix('_submission.json');jobfile=R/'jobs'/(name+'_job.json')
 job=json.loads(jobfile.read_text()) if jobfile.exists() else {}
 jobs.append({'stage':name,**submission,'state':job.get('status',{}).get('state'),
  'fatalError':job.get('status',{}).get('errorResult'),'resultFile':str((R/'jobs'/(name+'_result.json')).relative_to(REPO)) if (R/'jobs'/(name+'_result.json')).exists() else None})
manifest={'version':'2.0.0-pit','packagedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'project':'citric-glow-485600-f4','dataset':'icu_ml','location':'US',
 'environment':{'python':platform.python_version(),'numpy':np.__version__},
 'protocol':'audit/2026-09-05/pit_v4/SPECIFICATION.md',
 'sourceAndOutputMetadata':'audit/2026-09-05/pit_v4/jobs/metadata_after.json',
 'preservationChecks':'audit/2026-09-05/pit_v4/preservation_checks.json',
 'sha256':{str(p.relative_to(REPO)):sha(p) for p in sorted(files)},'jobs':jobs,
 'validation':{'boundaryFixtureCases':9,'Q1ExposedRows':574482,'testExposedRows':106328,
 'newPredictionIntegrityErrors':0,'lastValueTieCasesUnexplained':0,'originalObjectsPreserved':True,
 'originalBootstrapExactlyReproduced':True,'tierCountsReconcile':True},
 'limitations':['Conditional fixed-policy hospital bootstrap; no retraining uncertainty.',
 'Historical-to-new comparison includes inherited deterministic last-value tie-breaking.',
 'Exact optimizer stopping reason is not exposed by metadata.',
 'Documentation proxy and future-discharge-conditioned grid remain.']}
(R/'RUN_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
(REPO/'artifacts/reference_run_v4_pit/README.md').write_text('''# Point-in-time corrected reference run — 2.0.0-pit

Executed in BigQuery using `bqml_lr_v4_pit` and `preds_test_v4_pit`.

The five CSVs are direct aggregate exports from `artifacts/queries/`.
Pooled enrichment is 23.223694x (95% hospital-cluster CI 11.452149–41.533945),
with 10,391 alerts, 36 true-positive proxy windows, 0.346454% PPV, and 11.612903%
positive-window recall. Within-hospital AUROC is 0.734822 row-weighted and
0.782711 median; positive alerts occur in 9/31 test hospitals. Log loss is
0.007776029, worse than the constant training-prevalence baseline 0.001502385.

Full old/new results, per-hospital AUROC/AP, policy results, Q1 exposure, exact
query hashes, job IDs, source metadata and known limitations are in
[`audit/2026-09-05/pit_v4/`](../../audit/2026-09-05/pit_v4/REPORT.md).
[`RUN_MANIFEST.json`](../../audit/2026-09-05/pit_v4/RUN_MANIFEST.json) binds the SQL
and output hashes. Original exports remain in `../reference_run/`.

The endpoint is a documentation proxy, not adjudicated cardiac arrest. No
patient-level rows are included. The numerical alert cutoff follows the same
fixed global percentile rule; it was not tuned against held-out outcomes.
''')
print('Release evidence checks passed; wrote RUN_MANIFEST.json and bundle README.')
