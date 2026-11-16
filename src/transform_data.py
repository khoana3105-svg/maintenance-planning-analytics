import pandas as pd


def transform(clean):
    result={k:v.copy() for k,v in clean.items()}
    for name,cols in [('maintenance_records',['Date']),('pm_schedule',['Due_Date','Completed_Date'])]:
        for c in cols:
            result[name][c]=pd.to_datetime(result[name][c],errors='coerce').dt.strftime('%Y-%m-%d %H:%M:%S' if c=='Date' else '%Y-%m-%d').fillna('')
    return result


def pm_alert(status,due,reporting_date,warning_days=7):
    if status in ['Completed','Cancelled']:return status
    days=(pd.Timestamp(due)-pd.Timestamp(reporting_date)).days
    return 'Overdue' if days<0 else 'Due Soon' if days<=warning_days else 'Upcoming'
