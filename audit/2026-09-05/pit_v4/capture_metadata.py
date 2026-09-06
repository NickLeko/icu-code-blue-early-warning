"""Read-only output/source metadata inventory for the completed PIT run."""
import json,subprocess,urllib.request,os
from pathlib import Path
root=Path(__file__).resolve().parent
p='citric-glow-485600-f4'
token=subprocess.run(['gcloud','auth','application-default','print-access-token'],capture_output=True,text=True,check=True,env=dict(os.environ,CLOUDSDK_CORE_DISABLE_FILE_LOGGING='true')).stdout.strip()
def get(url):
 req=urllib.request.Request(url,headers={'Authorization':'Bearer '+token})
 with urllib.request.urlopen(req,timeout=45) as r:return json.load(r)
base='https://bigquery.googleapis.com/bigquery/v2/projects/'
objects={}
for t in ['cohort_v1','labels_v2','features_v2','split_hospital_v1','features_v3','model_table_v3','preds_test_v3','features_v4_pit','train_rows_v4_pit','model_table_v4_pit','preds_test_v4_pit','preds_test_v4_pit_autosplit_control']:
 d=get(base+p+'/datasets/icu_ml/tables/'+t);objects[t]=d
for t in ['lab','patient']:
 objects['source_'+t]=get(base+'physionet-data/datasets/eicu_crd/tables/'+t)
objects['original_model']=get(base+p+'/datasets/icu_ml/models/bqml_lr_v3')
billing=get('https://cloudbilling.googleapis.com/v1/projects/'+p+'/billingInfo')
objects['billing']={k:billing.get(k) for k in ['projectId','billingEnabled']}
(root/'jobs/metadata_after.json').write_text(json.dumps(objects,indent=2))
print(json.dumps({k:{x:v.get(x) for x in ['numRows','lastModifiedTime','billingEnabled']} for k,v in objects.items()}))
