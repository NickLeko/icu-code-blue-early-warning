import json,subprocess,sys,time
from pathlib import Path
root=Path(__file__).resolve().parent
for name in ['weight_comparison','temporal_tiers','first_crossing_canonical','tier_metrics']:
 while True:
  p=subprocess.run([sys.executable,str(root/'bq_job.py'),'collect','--name',name],capture_output=True,text=True,check=True)
  d=json.loads(p.stdout)
  if d.get('state')=='DONE':
   print(json.dumps({k:v for k,v in d.items() if k!='rows'}),flush=True);break
  time.sleep(10)
