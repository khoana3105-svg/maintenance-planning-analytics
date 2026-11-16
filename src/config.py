from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
START = '2026-05-01'
END = '2026-10-31'
REPORTING_DATE = END
FILES = {
    'machines': ['Machine_ID', 'Machine_Name', 'Line_ID', 'Criticality'],
    'maintenance_records': ['Maintenance_ID', 'Machine_ID', 'Date', 'Type', 'Failure_Mode', 'Duration_Hours', 'Downtime_Hours', 'Status'],
    'pm_schedule': ['PM_ID', 'Machine_ID', 'PM_Type', 'Due_Date', 'Completed_Date', 'Status'],
}
