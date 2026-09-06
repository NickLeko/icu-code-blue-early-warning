import argparse, json, os, subprocess, time, urllib.request, urllib.error
from pathlib import Path

PROJECT='citric-glow-485600-f4'
BASE=f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}'
p=argparse.ArgumentParser()
p.add_argument('mode',choices=['metadata','dry','query'])
p.add_argument('--sql');p.add_argument('--out',required=True)
args=p.parse_args()
token=subprocess.run(['gcloud','auth','application-default','print-access-token'],
    capture_output=True,text=True,check=True,
    env=dict(os.environ,CLOUDSDK_CORE_DISABLE_FILE_LOGGING='true')).stdout.strip()

def api(path,payload=None):
    req=urllib.request.Request(BASE+path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=50) as r:return json.load(r)
    except urllib.error.HTTPError as e:
        print(e.read().decode()[:3000]);raise SystemExit(1)

if args.mode=='metadata':
    result={}
    for table in ['preds_test_v3','cohort_v1','model_table_v3','split_hospital_v1']:
        x=api('/datasets/icu_ml/tables/'+table)
        result[table]={k:x.get(k) for k in ['id','etag','creationTime','lastModifiedTime','numRows','numBytes','schema','type']}
    Path(args.out).write_text(json.dumps(result,indent=2))
    print(json.dumps({t:{k:v[k] for k in ['numRows','numBytes','lastModifiedTime']} for t,v in result.items()}))
else:
    query=Path(args.sql).read_text()
    result=api('/queries',{'query':query,'useLegacySql':False,'dryRun':args.mode=='dry',
        'maximumBytesBilled':'10000000000','timeoutMs':10000,'maxResults':1000,'location':'US'})
    if args.mode=='query':
        job=result['jobReference']
        while not result.get('jobComplete'):
            print('Waiting for read-only job '+job['jobId'],flush=True)
            result=api('/queries/'+job['jobId']+'?location=US&timeoutMs=10000&maxResults=1000')
        if result.get('pageToken'):raise RuntimeError('Unexpected pagination; do not silently truncate')
        meta=api('/jobs/'+job['jobId']+'?location=US')
        result['auditJobStatistics']=meta.get('statistics')
    Path(args.out).write_text(json.dumps(result,indent=2))
    if args.mode=='dry': print(json.dumps({k:result.get(k) for k in ['totalBytesProcessed','jobComplete','errors']}))
    else:
        names=[f['name'] for f in result['schema']['fields']]
        rows=[{k:v.get('v') for k,v in zip(names,r['f'])} for r in result.get('rows',[])]
        print(json.dumps({'jobReference':result['jobReference'],'totalRows':result.get('totalRows'),'rows':rows}))
