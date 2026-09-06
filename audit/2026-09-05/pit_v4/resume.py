"""Resume fixed PIT stages after billing is enabled. Stops on any failed job/check.

No model/threshold selection. Reuses completed idempotent job IDs. Exact job
outputs are captured by bq_job.py; patient-level data are never downloaded.
"""
import json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
RUNNER=ROOT/'bq_job.py'
def run(action,name,sql=None,maxbytes=None):
 cmd=[sys.executable,str(RUNNER),action,'--name',name]
 if sql:cmd+=['--sql',str(sql)]
 if maxbytes:cmd+=['--max-bytes',str(maxbytes)]
 r=subprocess.run(cmd,cwd=REPO,capture_output=True,text=True)
 if r.returncode:
  print(r.stdout+r.stderr,flush=True);raise SystemExit(r.returncode)
 return json.loads(r.stdout)
def collect(name):
 while True:
  r=run('collect',name)
  if r.get('state')=='DONE':
   print(json.dumps(r),flush=True);return r
  time.sleep(20)
def stage(name,sql,maxbytes=None):
 print(json.dumps(run('submit',name,sql,maxbytes)),flush=True)
 return collect(name)
def decode(name):
 d=json.loads((ROOT/'jobs'/f'{name}_result.json').read_text())
 return [{f['name']:c['v'] for f,c in zip(d['schema']['fields'],r['f'])} for r in d.get('rows',[])]
collect('features_billing_enabled')
stage('train_rows',REPO/'sql/05_train_rows.sql')
stage('model_table',REPO/'sql/07_model_table.sql')
stage('feature_reconciliation',ROOT/'feature_reconciliation.sql')
q=json.loads((ROOT/'q1_reference_exposure_result.json').read_text())
expected={(r['f'][0]['v'],r['f'][1]['v']):r for r in q['rows']}
for r in decode('feature_reconciliation'):
 for key in ['missing_row_keys','label_or_split_changes','rows_with_increased_lab_counts','rows_with_changed_vitals']:
  assert int(r[key])==0,(key,r)
 e=expected[(r['split'],r['y'])]
 ef={f['name']:c['v'] for f,c in zip(q['schema']['fields'],e['f'])}
 assert int(r['rows_with_changed_lab_counts'])==int(ef['windows_with_future_entered_value']),r
 assert int(r['lab_window_pairs_removed'])==int(ef['future_entered_lab_window_pairs']),r
print('Q1 reconciliation passed for every split/label stratum.',flush=True)
stage('split_counts',ROOT/'split_counts.sql')
for name,sql in [('model_final',REPO/'sql/08_bqml_models.sql'),('model_control',ROOT/'control_model.sql')]:
 print(json.dumps(run('dry',name,sql,200000000000)),flush=True)
 print(json.dumps(run('submit',name,sql,200000000000)),flush=True)
for name in ['model_final','model_control']:collect(name)
for name,model in [('new_model_metadata','bqml_lr_v4_pit'),('control_model_metadata','bqml_lr_v4_pit_autosplit_control')]:
 subprocess.run([sys.executable,str(RUNNER),'metadata','--object','models/'+model,'--name',name],check=True)
# A separate metadata inspection queries temporary split tables before expiry.
stage('predictions_final',REPO/'sql/09_eval_alert_rate.sql')
stage('predictions_control',ROOT/'control_predictions.sql')
tasks=[('q6_new',ROOT/'q6_new.sql'),('within_new',ROOT/'within_new.sql'),('integrity_new',ROOT/'integrity_new.sql')]
for p in sorted((REPO/'artifacts/queries').glob('*.sql')):tasks.append(('export_'+p.stem,p))
for name in ['model_comparison','probability_baseline','weight_comparison']:
 p=ROOT/(name+'.sql')
 if p.exists():tasks.append((name,p))
for name,p in tasks:print(json.dumps(run('submit',name,p)),flush=True)
for name,p in tasks:collect(name)
print('Regeneration and aggregate jobs completed.',flush=True)
