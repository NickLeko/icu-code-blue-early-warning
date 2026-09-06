"""Explicit BigQuery job runner for the authorized PIT v4 regeneration.

No credentials are stored. Uses existing ADC, records SQL hashes/job metadata.
Submit/collect are separate so long training does not block audit progress.
"""
import argparse,datetime,hashlib,json,os,subprocess,urllib.request,urllib.error
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PROJECT='citric-glow-485600-f4'
BASE=f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}'
p=argparse.ArgumentParser()
p.add_argument('action',choices=['dry','submit','collect','metadata','inventory'])
p.add_argument('--sql');p.add_argument('--name');p.add_argument('--object')
p.add_argument('--max-bytes',default='50000000000')
args=p.parse_args()
token=subprocess.run(['gcloud','auth','application-default','print-access-token'],
    capture_output=True,text=True,check=True,
    env=dict(os.environ,CLOUDSDK_CORE_DISABLE_FILE_LOGGING='true')).stdout.strip()

def api(path,data=None,allow_conflict=False):
    req=urllib.request.Request(BASE+path,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=45) as r:return json.load(r)
    except urllib.error.HTTPError as e:
        if allow_conflict and e.code==409:return None
        print(e.read().decode()[:3000]);raise SystemExit(1)

jobs=ROOT/'jobs';jobs.mkdir(exist_ok=True)
if args.action=='metadata':
    result=api('/datasets/icu_ml/'+args.object)
    (jobs/(args.name+'.json')).write_text(json.dumps(result,indent=2))
    print(json.dumps({k:result.get(k) for k in ['id','modelReference','etag','numRows','numBytes','lastModifiedTime']}))
elif args.action=='inventory':
    out={kind:api('/datasets/icu_ml/'+kind+'?maxResults=1000') for kind in ['tables','models']}
    (jobs/'inventory.json').write_text(json.dumps(out,indent=2))
    print(json.dumps({'tables':[x['tableReference']['tableId'] for x in out['tables'].get('tables',[])],
        'models':[x['modelReference']['modelId'] for x in out['models'].get('models',[])]}))
elif args.action in ['dry','submit']:
    sql=Path(args.sql).read_text().replace('{{PROJECT_ID}}',PROJECT)
    if args.action=='submit' and 'DRY RUN ONLY' in sql:
        raise SystemExit('Refusing to submit a dry-run-only schema probe.')
    digest=hashlib.sha256(sql.encode()).hexdigest()
    jobid='codex_icu_pit_v4_20260905_'+args.name+'_'+digest[:12]
    config={'query':{'query':sql,'useLegacySql':False,'maximumBytesBilled':args.max_bytes},
            'labels':{'run':'pit_v4_20260905','stage':args.name.lower()}}
    if args.action=='dry':config['dryRun']=True
    payload={'jobReference':{'projectId':PROJECT,'jobId':jobid,'location':'US'},'configuration':config}
    result=api('/jobs',payload,allow_conflict=args.action=='submit')
    if result is None:result=api('/jobs/'+jobid+'?location=US')
    if args.action=='dry':
        (jobs/(args.name+'_dry.json')).write_text(json.dumps(result,indent=2))
        print(json.dumps({'name':args.name,'statistics':result.get('statistics'),'status':result.get('status')}))
    else:
        record={'jobReference':result['jobReference'],'sqlFile':str(Path(args.sql).resolve()),
                'querySha256':digest,'submittedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()}
        (jobs/(args.name+'_submission.json')).write_text(json.dumps(record,indent=2))
        print(json.dumps({'name':args.name,'jobReference':result['jobReference'],'status':result.get('status')}))
        if result.get('status',{}).get('errorResult'):
            (jobs/(args.name+'_job.json')).write_text(json.dumps(result,indent=2))
            raise SystemExit(1)
elif args.action=='collect':
    ref=json.loads((jobs/(args.name+'_submission.json')).read_text())['jobReference']
    job=api('/jobs/'+ref['jobId']+'?location=US')
    (jobs/(args.name+'_job.json')).write_text(json.dumps(job,indent=2))
    if job['status']['state']!='DONE':print(json.dumps({'name':args.name,'status':job['status']}));raise SystemExit(0)
    if job['status'].get('errorResult'):print(json.dumps(job['status']));raise SystemExit(1)
    result=api('/queries/'+ref['jobId']+'?location=US&maxResults=1000')
    while result.get('pageToken'):
        page=api('/queries/'+ref['jobId']+'?location=US&maxResults=1000&pageToken='+result['pageToken'])
        result.setdefault('rows',[]).extend(page.get('rows',[]));result['pageToken']=page.get('pageToken')
    result['auditJobStatistics']=job.get('statistics')
    (jobs/(args.name+'_result.json')).write_text(json.dumps(result,indent=2))
    fields=result.get('schema',{}).get('fields',[])
    rows=[{f['name']:x.get('v') for f,x in zip(fields,r['f'])} for r in result.get('rows',[])]
    print(json.dumps({'name':args.name,'state':'DONE','totalRows':result.get('totalRows'),'rows':rows[:50],
        'totalBytesProcessed':job.get('statistics',{}).get('totalBytesProcessed')}))
