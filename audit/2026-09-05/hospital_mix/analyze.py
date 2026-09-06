"""Analyze executed BigQuery aggregate exports; never trains or scores a model.

Requires numpy. Run in this directory with: python3 analyze.py
Bootstrap unit: hospital; observed global-policy alert membership is held fixed.
"""
import csv
import json
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parent

def decode(name):
    data=json.loads((ROOT/name).read_text())
    fields=data['schema']['fields']
    rows=[]
    for r in data.get('rows',[]):
        out={}
        for f,x in zip(fields,r['f']):
            v=x.get('v')
            out[f['name']]=None if v is None else int(v) if f['type']=='INTEGER' else float(v) if f['type']=='FLOAT' else v
        rows.append(out)
    assert len(rows)==int(data['totalRows'])
    return rows

rows=decode('q6_result.json')
within={r['hospitalid']:r for r in decode('within_result.json')}
integrity=decode('integrity_result.json')[0]
assert integrity['assigned_test_hospitals']==integrity['test_hospitals_with_predictions']==31
assert all(v==0 for k,v in integrity.items() if k not in ['assigned_test_hospitals','test_hospitals_with_predictions'])
N=sum(r['n'] for r in rows);K=sum(r['k'] for r in rows)
A=sum(r['a'] for r in rows);T=sum(r['tp'] for r in rows)
assert (N,K,A,T)==(2078011,310,10391,21)
p=K/N; E=sum(r['a']*r['k']/r['n'] for r in rows)
for r in rows:
    m=within[r['hospitalid']]
    assert (m['n'],m['k'])==(r['n'],r['k'])
    r['row_share']=r['n']/N;r['alert_share']=r['a']/A
    r['allocation_relative_to_row_share']=r['alert_share']/r['row_share']
    r['within_hospital_enrichment']=r['ppv']/r['prevalence'] if r['a'] and r['k'] else None
    r['auroc']=m['auroc'];r['average_precision']=m['average_precision']
    r['ap_over_prevalence']=m['average_precision']/r['prevalence'] if r['k'] else None

def dist(values):
    x=np.array(values,dtype=float)
    return dict(zip(['min','q1','median','q3','max'],map(float,np.quantile(x,[0,.25,.5,.75,1]))))

eligible=[r for r in rows if r['within_hospital_enrichment'] is not None]
positive=[r for r in rows if r['k']]
high=[r for r in rows if r['prevalence']>p]
top=sorted(rows,key=lambda r:r['a'],reverse=True)
stats={
    'project':'citric-glow-485600-f4','N':N,'K':K,'A':A,'TP':T,
    'prevalence':p,'ppv':T/A,'pooled_enrichment':(T/A)/p,
    'expected_tp_hospital_mix':E,'observed_over_hospital_mix_expected':T/E,
    'expected_tp_uniform_row_selection':A*p,'hospital_mix_enrichment_factor':(E/A)/p,
    'allocation_weighted_hospital_prevalence':E/A,
    'test_hospitals':len(rows),'zero_alert_hospitals':sum(r['a']==0 for r in rows),
    'zero_positive_hospitals':sum(r['k']==0 for r in rows),
    'hospitals_with_positive_alert_windows':sum(r['tp']>0 for r in rows),
    'unique_detected_proxy_stays':sum(r['detected_event_stays'] for r in rows),
    'unique_proxy_stays_with_positive_rows':sum(r['event_stays_with_positive_rows'] for r in rows),
    'within_enrichment_defined_hospitals':len(eligible),
    'within_enrichment_defined_rows':sum(r['n'] for r in eligible),
    'row_volume_weighted_within_enrichment':sum(r['n']*r['within_hospital_enrichment'] for r in eligible)/sum(r['n'] for r in eligible),
    'alert_volume_weighted_within_enrichment':sum(r['a']*r['within_hospital_enrichment'] for r in eligible)/sum(r['a'] for r in eligible),
    'within_enrichment_distribution_defined':dist([r['within_hospital_enrichment'] for r in eligible]),
    'positive_hospital_auroc_distribution':dist([r['auroc'] for r in positive]),
    'positive_hospital_average_precision_distribution':dist([r['average_precision'] for r in positive]),
    'positive_hospital_ap_over_prevalence_distribution':dist([r['ap_over_prevalence'] for r in positive]),
    'row_weighted_within_hospital_auroc':sum(r['n']*r['auroc'] for r in positive)/sum(r['n'] for r in positive),
    'auroc_above_half':sum(r['auroc']>.5 for r in positive),
    'auroc_at_least_0_6':sum(r['auroc']>=.6 for r in positive),
    'auroc_below_half_hospitals':[r['hospitalid'] for r in positive if r['auroc']<.5],
    'hospitals_above_pooled_prevalence':len(high),
    'high_prevalence_row_share':sum(r['n'] for r in high)/N,
    'high_prevalence_alert_share':sum(r['a'] for r in high)/A,
    'high_prevalence_positives':sum(r['k'] for r in high),
    'high_prevalence_alerts':sum(r['a'] for r in high),
    'zero_positive_hospital_alerts':sum(r['a'] for r in rows if not r['k']),
    'top_alert_hospitals':[r['hospitalid'] for r in top[:5]],
    'top_3_alert_share':sum(r['a'] for r in top[:3])/A,
    'top_3_row_share':sum(r['n'] for r in top[:3])/N,
    'top_5_alert_share':sum(r['a'] for r in top[:5])/A,
    'top_5_row_share':sum(r['n'] for r in top[:5])/N,
}

# Paired cluster bootstrap of the observed policy: sample 31 whole hospitals
# with replacement. Repeated windows/labels/alerts within each remain together.
# This estimates cluster uncertainty conditional on the existing fitted model
# and observed global alert membership; it does not refit or rerank each draw.
B=100000;seed=20260905
rng=np.random.default_rng(seed)
w=rng.multinomial(len(rows),np.full(len(rows),1/len(rows)),size=B)
table=np.array([[r['n'],r['k'],r['a'],r['tp'],r['a']*r['k']/r['n']] for r in rows])
b=w@table
valid=(b[:,1]>0)&(b[:,2]>0)
lift=b[valid,3]*b[valid,0]/(b[valid,2]*b[valid,1])
valid_mix=b[:,4]>0
adjusted=b[valid_mix,3]/b[valid_mix,4]
stats['hospital_cluster_bootstrap']={
    'resamples':B,'seed':seed,'hospital_clusters_per_resample':len(rows),
    'method':'paired hospital percentile bootstrap; fixed observed global-policy alert membership',
    'undefined_pooled_replicates':int((~valid).sum()),
    'zero_tp_replicates':int((b[:,3]==0).sum()),
    'pooled_enrichment_95pct_CI':list(map(float,np.quantile(lift,[.025,.975]))),
    'hospital_mix_adjusted_ratio_95pct_CI':list(map(float,np.quantile(adjusted,[.025,.975]))),
    'undefined_mix_ratio_replicates':int((~valid_mix).sum())}

with (ROOT/'per_hospital.csv').open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
(ROOT/'summary.json').write_text(json.dumps(stats,indent=2)+'\n')

def fmt(v,d=4):return '—' if v is None else f'{v:.{d}f}'
lines=['| Hospital | Rows | Positive windows | Base % | Alerts | TP | PPV % | Within lift | Row share % | Alert share % | AUROC | AP % |',
       '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
for r in rows:
    lines.append(f"| {r['hospitalid']} | {r['n']:,} | {r['k']} | {100*r['prevalence']:.5f} | {r['a']:,} | {r['tp']} | {fmt(None if r['ppv'] is None else 100*r['ppv'],5)} | {fmt(r['within_hospital_enrichment'],2)} | {100*r['row_share']:.3f} | {100*r['alert_share']:.3f} | {fmt(r['auroc'])} | {fmt(None if r['average_precision'] is None else 100*r['average_precision'],5)} |")
(ROOT/'hospital_table.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(stats,indent=2))
