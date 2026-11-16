"""Independent reconciliation of actual DAX query output against validated source rows."""
import json
import math
from pathlib import Path
import pandas as pd
from src.config import FILES, ROOT
from src.validate_data import validate

raw={k:pd.read_csv(ROOT/'data/raw'/f'{k}.csv',dtype=str,keep_default_na=False) for k in FILES}
good,_=validate(raw)
events=good['maintenance_records'];pm=good['pm_schedule']
events['Month']=pd.to_datetime(events.Date).dt.strftime('%Y-%m')
pm['Month']=pd.to_datetime(pm.Due_Date).dt.strftime('%Y-%m')
actual=json.loads((ROOT/'tests/powerbi_machine_month.json').read_text(encoding='utf-8-sig'))
assert len(actual)==120
checks=0
for row in actual:
    machine=row['Dim_Machine[Machine_ID]'];month=row['Dim_Date[YearMonth]']
    subset=events[(events.Machine_ID==machine)&(events.Month==month)&(events.Type=='Corrective')]
    tasks=pm[(pm.Machine_ID==machine)&(pm.Month==month)&(pm.Status!='Cancelled')]
    due=len(tasks)
    on_time=int(((tasks.Status=='Completed')&(tasks.Completed_Date<=tasks.Due_Date)).sum())
    downtime=float(subset.Downtime_Hours.sum());count=len(subset)
    expected={'Downtime':downtime,'Breakdowns':count,'MTTR':float(subset.Duration_Hours.sum())/count if count else None,
              'MTBF':(416-downtime)/count if count else None,'Planned':416,'PMDue':due,'OnTime':on_time,'Compliance':on_time/due if due else None}
    for name,value in expected.items():
        observed=row[f'[{name}]']
        assert (observed is None and value is None) or (observed is not None and value is not None and math.isclose(observed,value,abs_tol=1e-8)),(machine,month,name,value,observed)
        checks+=1
edges=json.loads((ROOT/'tests/powerbi_edges.json').read_text(encoding='utf-8-sig'))[0]
assert edges['[Machines]']==20 and edges['[Events]']==403 and edges['[PM]']==240 and edges['[Days]']==184
assert edges['[NoFailureMTTR]'] is None and edges['[NoFailureMTBF]'] is None
summary={'machine_month_combinations':len(actual),'independent_metric_checks':checks,'all_passed':True,'edge_cases':'Counts and no-failure MTTR/MTBF passed'}
(ROOT/'tests/powerbi_reconciliation.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(summary)
