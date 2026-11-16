"""Use Windows built-in .NET SQL client. No optional database fallback."""
import subprocess
from .config import ROOT


def load_sql(batch_dir, server='localhost', database='MaintenancePlanningJD'):
    process=subprocess.run(['powershell.exe','-NoProfile','-File',str(ROOT/'sql'/'load_batch.ps1'),
                            '-BatchDir',str(batch_dir),'-Server',server,'-Database',database],capture_output=True,text=True)
    if process.returncode:
        raise RuntimeError('SQL Server load failed; see logs/sql_error.txt')
    return process.stdout
