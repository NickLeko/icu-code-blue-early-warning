"""Generate transparent old/new comparisons from executed aggregate results."""
import csv,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'hospital_mix'
NEW=ROOT/'analysis'
a=json.loads((OLD/'summary.json').read_text());b=json.loads((NEW/'summary.json').read_text())
def flatten(d,prefix=''):
 out={}
 for k,v in d.items():
  key=prefix+k
  if isinstance(v,dict):out.update(flatten(v,key+'.'))
  else:out[key]=v
 return out
fa=flatten(a);fb=flatten(b)
fa['positive_window_recall']=a['TP']/a['K']
with (ROOT/'comparison.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['metric','original_v3','pit_custom_final'])
 for k in sorted(set(fa)|set(fb)):
  w.writerow([k,json.dumps(fa.get(k)),json.dumps(fb.get(k))])
old={r['hospitalid']:r for r in csv.DictReader((OLD/'per_hospital.csv').open())}
new={r['hospitalid']:r for r in csv.DictReader((NEW/'per_hospital.csv').open())}
assert old.keys()==new.keys()
cols=list(next(iter(old.values())))
with (ROOT/'per_hospital_comparison.csv').open('w',newline='') as f:
 w=csv.writer(f);w.writerow(['hospitalid']+[s+'_'+k for k in cols if k!='hospitalid' for s in ['old','new']])
 for h in old:w.writerow([h]+[d[h].get(k) for k in cols if k!='hospitalid' for d in [old,new]])

def fmt(x,n=4):return 'undefined' if x is None or x=='' else f'{float(x):.{n}f}'
def pct(x,n=4):return 'undefined' if x is None or x=='' else f'{100*float(x):.{n}f}%'
lines=['# Hospital comparison: original v3 versus PIT + CUSTOM',
 '', 'All policies select the raw global NTILE(200)=1 bucket. Hospital metrics do not allocate a new top 0.5% within each hospital.',
 '', '## Allocation and detection', '',
 '| Hospital | Rows (both) | Positives (both) | Base % (both) | Alerts old → new | TP old → new | PPV % old → new | Within enrichment old → new |',
 '|---|---:|---:|---:|---:|---:|---:|---:|']
for h,o in old.items():
 n=new[h];assert(o['n'],o['k'])==(n['n'],n['k'])
 lines.append(f"| {h} | {int(o['n']):,} | {o['k']} | {pct(o['prevalence'],5)} | {o['a']} → {n['a']} | {o['tp']} → {n['tp']} | {pct(o['ppv'],5)} → {pct(n['ppv'],5)} | {fmt(o['within_hospital_enrichment'],2)} → {fmt(n['within_hospital_enrichment'],2)} |")
lines+=['','## Ranking and concentration', '',
 '| Hospital | AUROC old → new | AP % old → new | Row share % (both) | Alert share % old → new |',
 '|---|---:|---:|---:|---:|']
for h,o in old.items():
 n=new[h]
 lines.append(f"| {h} | {fmt(o['auroc'])} → {fmt(n['auroc'])} | {pct(o['average_precision'],5)} → {pct(n['average_precision'],5)} | {pct(o['row_share'],3)} | {pct(o['alert_share'],3)} → {pct(n['alert_share'],3)} |")
lines+=['','Within-hospital enrichment is undefined if a hospital has no alerts or no positive windows. AUROC and AP are reported for hospitals with both classes. No undefined metric is replaced with zero. Row-weighted within enrichment uses only its explicitly counted eligible hospitals. The full CSV includes alert-to-row concentration ratios, recalls, and detected stay counts.']
(ROOT/'HOSPITAL_COMPARISON.md').write_text('\n'.join(lines)+'\n')
print('Wrote comparison.csv, per_hospital_comparison.csv, HOSPITAL_COMPARISON.md')
