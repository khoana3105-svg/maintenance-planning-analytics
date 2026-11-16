"""Synthetic scenarios, seed 42. New output folders only; raw inputs never overwritten."""
import argparse
import calendar
import random
from pathlib import Path
from datetime import date, timedelta
import pandas as pd
from .config import ROOT, FILES


def generate(output: Path, seed=42):
    output.mkdir(parents=True, exist_ok=False)
    rng = random.Random(seed)
    machines, events, pm = [], [], []
    for i in range(1, 21):
        machine = f'M{i:03d}'
        line = f'L{(i-1)//5+1:02d}'
        machines.append([machine, f'Synthetic machine {i:02d}', line, 'High' if i <= 5 else 'Medium'])
        for month in range(5, 11):
            # Deliberate teaching scenarios, not empirical evidence about PM effects.
            count = (5 if i == 3 else 1 + (month-5)//2 if line == 'L01' else 1)
            for k in range(count):
                day = 2 + k*4
                duration = round(rng.uniform(1, 3) * (2 if i == 3 else 1), 2)
                downtime = round(duration + rng.uniform(.2, 1), 2)
                mode = 'Bearing wear' if i == 3 else rng.choice(['Sensor alignment', 'Air leak', 'Electrical fault'])
                events.append([f'MT-{len(events)+1:04d}',machine,f'2026-{month:02d}-{day:02d} 08:00:00','Corrective',mode,duration,downtime,'Completed'])
            # Daily/weekly/monthly are schedule categories; one task is one due occurrence.
            kinds=['Daily check','Weekly lubrication','Monthly inspection']
            for k, kind in enumerate([kinds[(month-5)%3],kinds[(month-4)%3]]):
                due = date(2026, month, 22+k)
                late = line == 'L01' and month >= 7 and k != 0
                completed = due + timedelta(days=3 if late else -1)
                status = 'Planned' if late and month == 10 else 'Completed'
                pm.append([f'PM-{len(pm)+1:04d}',machine,kind,str(due),str(completed) if status=='Completed' else '',status])
                if status == 'Completed':
                    events.append([f'MT-{len(events)+1:04d}',machine,f'{completed} 14:00:00','Preventive','',round(rng.uniform(.3,1),2),0,'Completed'])
    frames={key:pd.DataFrame(rows,columns=FILES[key]) for key,rows in [('machines',machines),('maintenance_records',events),('pm_schedule',pm)]}
    # Append known invalid fixtures: 4% of the final source population (approximately).
    base=sum(len(df) for df in frames.values())
    dirty=[]
    for i in range(round(base*.04/.96)):
        row=frames['maintenance_records'].iloc[i].copy()
        row['Maintenance_ID']=f'INVALID-{i:03d}'
        error=i%5
        if error==0: row['Duration_Hours']=-1
        elif error==1: row['Machine_ID']='M999'
        elif error==2: row['Date']='invalid-date'
        elif error==3: row['Downtime_Hours']=-5
        else: row=frames['maintenance_records'].iloc[i].copy()
        dirty.append(row)
    frames['maintenance_records']=pd.concat([frames['maintenance_records'],pd.DataFrame(dirty)],ignore_index=True)
    for key,df in frames.items():df.to_csv(output/f'{key}.csv',index=False,encoding='utf-8-sig')
    (output/'SYNTHETIC.txt').write_text('Fully synthetic. Seed 42. May-Oct 2026. Scenarios intentionally designed; no causal claims.\n',encoding='utf-8')
    return {k:len(v) for k,v in frames.items()}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    print(generate(p.parse_args().output))
