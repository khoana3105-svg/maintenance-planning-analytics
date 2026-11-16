$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root 'outputs\sql_evidence';New-Item -ItemType Directory -Force -Path $out|Out-Null
$c=New-Object System.Data.SqlClient.SqlConnection('Server=localhost;Database=MaintenancePlanningJD;Integrated Security=True;Connect Timeout=10');$c.Open()
function Query($sql){$q=$c.CreateCommand();$q.CommandText=$sql;$adapter=New-Object System.Data.SqlClient.SqlDataAdapter($q);$dt=New-Object System.Data.DataTable;[void]$adapter.Fill($dt);return ,$dt}
try{
 $queries=@{
  machines='SELECT Machine_ID,SUM(Downtime_Hours) Downtime_Hours,SUM(Breakdown_Count) Breakdowns,SUM(Planned_Hours-Downtime_Hours)/NULLIF(SUM(Breakdown_Count),0) MTBF FROM dbo.vw_Machine_Downtime GROUP BY Machine_ID ORDER BY Downtime_Hours DESC'
  pm='SELECT Line_ID,SUM(On_Time) On_Time,SUM(Eligible_Due) Due,CAST(SUM(On_Time)*1.0/NULLIF(SUM(Eligible_Due),0) AS decimal(12,6)) Compliance FROM dbo.vw_PM_Performance GROUP BY Line_ID ORDER BY Line_ID'
  failures='SELECT Machine_ID,Failure_Mode,COUNT(*) Occurrences FROM dbo.vw_Breakdown_Analysis WHERE Is_Breakdown=1 GROUP BY Machine_ID,Failure_Mode ORDER BY Occurrences DESC'
  totals="SELECT COUNT(*) Maintenance_Rows,SUM(Downtime_Hours) Downtime_Hours,SUM(CASE WHEN Type='Corrective' THEN 1 ELSE 0 END) Breakdowns,SUM(CASE WHEN Type='Corrective' THEN Duration_Hours ELSE 0 END)/NULLIF(SUM(CASE WHEN Type='Corrective' THEN 1 ELSE 0 END),0) MTTR FROM dbo.Fact_Maintenance"
  audit='SELECT * FROM dbo.ETL_Run_Log ORDER BY Started_UTC'
 }
 foreach($key in $queries.Keys){$dt=Query $queries[$key];$dt|Export-Csv -LiteralPath (Join-Path $out ($key+'.csv')) -NoTypeInformation -Encoding UTF8}
 $checks=@()
 foreach($test in @(
  @('Duplicate key',"INSERT dbo.Dim_Machine SELECT * FROM dbo.Dim_Machine WHERE Machine_ID='M001'"),
  @('Foreign key',"INSERT dbo.Fact_Maintenance VALUES ('TEST-FK','M999','20261001','Corrective','Test',1,1,'Completed')"),
  @('Negative duration',"INSERT dbo.Fact_Maintenance VALUES ('TEST-NEG','M001','20261001','Corrective','Test',-1,1,'Completed')")
 )){
  $tx=$c.BeginTransaction();$q=$c.CreateCommand();$q.Transaction=$tx;$q.CommandText=$test[1];$blocked=$false
  try{[void]$q.ExecuteNonQuery()}catch{$blocked=$true}finally{$tx.Rollback();$tx.Dispose()}
  $checks+=[pscustomobject]@{Test=$test[0];Blocked=$blocked}
 }
 $checks|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'constraints.json') -Encoding UTF8
 if(@($checks|Where-Object {-not $_.Blocked}).Count){throw 'Constraint failure'}
 Write-Output 'SQL queries exported and constraints passed; tests rolled back.'
}finally{$c.Dispose()}
