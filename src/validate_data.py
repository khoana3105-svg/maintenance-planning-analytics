"""First occurrence wins for duplicate IDs; originals and rejection reasons retained."""
import json
import math
import pandas as pd
from .config import FILES, START, END


def validate(raw):
    clean, rejected = {}, []
    for name, columns in FILES.items():
        if name not in raw or set(columns)-set(raw[name].columns):
            raise ValueError(f'{name}: missing source or required columns')
        rows, seen = [], set()
        key=columns[0]
        for index, source in raw[name].iterrows():
            item={c:str(source[c]).strip() if pd.notna(source[c]) else '' for c in columns}
            errors=[]
            required=columns if name=='machines' else [c for c in columns if c not in ['Failure_Mode','Completed_Date']]
            for c in required:
                if not item[c]:errors.append(f'{c}: required')
            if item[key] in seen:errors.append(f'{key}: duplicate (first occurrence retained)')
            seen.add(item[key])
            if name=='machines':
                if item['Criticality'] not in ['High','Medium','Low']:errors.append('Criticality: invalid')
            else:
                if item['Machine_ID'] not in set(clean['machines']['Machine_ID']):errors.append('Machine_ID: unknown')
                date_col='Date' if name=='maintenance_records' else 'Due_Date'
                timestamp=pd.to_datetime(item[date_col],errors='coerce')
                if pd.isna(timestamp):errors.append(f'{date_col}: invalid date')
                elif not START<=str(timestamp.date())<=END:errors.append(f'{date_col}: outside simulation period')
                if name=='maintenance_records':
                    if item['Type'] not in ['Preventive','Corrective','Inspection']:errors.append('Type: invalid')
                    if item['Status']!='Completed':errors.append('Status: only completed maintenance events are supported')
                    for c in ['Duration_Hours','Downtime_Hours']:
                        try:
                            number=float(item[c])
                            if not math.isfinite(number) or number<0:raise ValueError()
                            item[c]=number
                        except (ValueError,TypeError):errors.append(f'{c}: finite non-negative number required')
                    if item['Type']=='Corrective' and not item['Failure_Mode']:errors.append('Failure_Mode: required for corrective failure')
                    if item['Type']!='Corrective' and item['Downtime_Hours']!=0:errors.append('Downtime_Hours: only unplanned corrective downtime supported')
                else:
                    if item['Status'] not in ['Planned','Completed','Cancelled']:errors.append('Status: invalid')
                    completion=pd.to_datetime(item['Completed_Date'],errors='coerce')
                    if item['Status']=='Completed':
                        if pd.isna(completion):errors.append('Completed_Date: required valid date')
                        elif str(completion.date())>END:errors.append('Completed_Date: after observation cutoff')
                    elif item['Completed_Date']:errors.append('Completed_Date: only Completed tasks may have a value')
            if errors:
                rejected.append({'Source':name,'Source_Row':index+2,'Record_ID':item[key], 'Reason':'; '.join(errors),'Raw_Record':json.dumps(source.to_dict(),ensure_ascii=False,default=str)})
            else:rows.append(item)
        clean[name]=pd.DataFrame(rows,columns=columns)
    return clean,pd.DataFrame(rejected,columns=['Source','Source_Row','Record_ID','Reason','Raw_Record'])
