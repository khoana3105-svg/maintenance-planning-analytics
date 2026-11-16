param([Parameter(Mandatory=$true)][string]$BatchDir,[string]$Server='localhost',[string]$Database='MaintenancePlanningJD')
$ErrorActionPreference='Stop'
if($Database -notmatch '^[A-Za-z][A-Za-z0-9_]*$'){throw 'Invalid database identifier'}
$summary=Get-Content -LiteralPath (Join-Path $BatchDir 'summary.json') -Raw | ConvertFrom-Json
$connection=New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=master;Integrated Security=True;Connect Timeout=10")
$tx=$null
function Exec([string]$sql){$cmd=$connection.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=60;if($tx){$cmd.Transaction=$tx};[void]$cmd.ExecuteNonQuery();$cmd.Dispose()}
function Param($cmd,$name,$value){if($null -eq $value -or ($value -is [string] -and $value.Length -eq 0)){$value=[DBNull]::Value};[void]$cmd.Parameters.AddWithValue($name,$value)}
function Audit($status,$errorText){
 $cmd=$connection.CreateCommand();$cmd.CommandText='INSERT dbo.ETL_Run_Log VALUES (@batch,@start,SYSUTCDATETIME(),@source,@accepted,@rejected,@inserted,@updated,@skipped,@status,@error)'
 Param $cmd '@batch' $summary.Batch_ID;Param $cmd '@start' ([datetime]::Parse($summary.Started_UTC).ToUniversalTime())
 Param $cmd '@source' ([int]$summary.Source_Rows);Param $cmd '@accepted' ([int]$summary.Accepted_Rows);Param $cmd '@rejected' ([int]$summary.Rejected_Rows)
 Param $cmd '@inserted' $inserted;Param $cmd '@updated' $updated;Param $cmd '@skipped' $skipped;Param $cmd '@status' $status;Param $cmd '@error' $errorText
 if($tx){$cmd.Transaction=$tx};[void]$cmd.ExecuteNonQuery();$cmd.Dispose()
}
$inserted=0;$updated=0;$skipped=0
try {
 $connection.Open()
 Exec "IF DB_ID(N'$Database') IS NULL CREATE DATABASE [$Database]"
 $connection.ChangeDatabase($Database)
 Exec (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'create_tables.sql') -Raw)
 foreach($batch in ((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'create_views.sql') -Raw) -split '(?im)^GO\s*$')){if($batch.Trim()){Exec $batch}}
 $tx=$connection.BeginTransaction([System.Data.IsolationLevel]::Serializable)
 foreach($mapping in @(@('machines','Dim_Machine','Machine_ID'),@('maintenance_records','Fact_Maintenance','Maintenance_ID'),@('pm_schedule','Fact_PM_Schedule','PM_ID'))){
  $rows=Import-Csv -LiteralPath (Join-Path $BatchDir ($mapping[0]+'.csv')) -Encoding UTF8
  foreach($row in $rows){
   $columns=@($row.PSObject.Properties.Name);$cmd=$connection.CreateCommand();$cmd.Transaction=$tx
   $parameters=@();$changes=@();$sets=@();$columnSql=@()
   foreach($col in $columns){
    $value=$row.$col
    if($col -in @('Duration_Hours','Downtime_Hours')){$value=[decimal]::Parse($value,[cultureinfo]::InvariantCulture)}
    if($col -in @('Date','Due_Date','Completed_Date') -and $value -ne ''){$value=[datetime]::Parse($value,[cultureinfo]::InvariantCulture)}
    Param $cmd ('@'+$col) $value
    $parameters+=('@'+$col);$columnSql+=('['+$col+']')
    if($col -ne $mapping[2]){
     $sets+=('['+$col+']=@'+$col)
     $changes+=('(['+$col+']<>@'+$col+' OR (['+$col+'] IS NULL AND @'+$col+' IS NOT NULL) OR (['+$col+'] IS NOT NULL AND @'+$col+' IS NULL))')
    }
   }
   $table='dbo.['+$mapping[1]+']';$key='['+$mapping[2]+']=@'+$mapping[2]
   $cmd.CommandText="IF NOT EXISTS(SELECT 1 FROM $table WHERE $key) BEGIN INSERT $table ($($columnSql -join ',')) VALUES ($($parameters -join ',')); SELECT 1; END ELSE IF EXISTS(SELECT 1 FROM $table WHERE $key AND ($($changes -join ' OR '))) BEGIN UPDATE $table SET $($sets -join ',') WHERE $key; SELECT 2; END ELSE SELECT 0;"
   $result=[int]$cmd.ExecuteScalar();$cmd.Dispose()
   if($result -eq 1){$inserted++}elseif($result -eq 2){$updated++}else{$skipped++}
  }
 }
 Audit 'SUCCESS' $null
 $tx.Commit();$tx.Dispose();$tx=$null
 Write-Output "Inserted=$inserted Updated=$updated Skipped=$skipped Database=$Database"
} catch {
 if($tx){$tx.Rollback();$tx.Dispose();$tx=$null}
 $message=$_.Exception.Message
 if($connection.State -eq 'Open'){try{$inserted=0;$updated=0;$skipped=0;Audit 'FAILED' $message}catch{}}
 $logs=Join-Path (Split-Path $PSScriptRoot -Parent) 'logs';New-Item -ItemType Directory -Force -Path $logs | Out-Null
 $message | Set-Content -LiteralPath (Join-Path $logs 'sql_error.txt') -Encoding UTF8
 Write-Error 'SQL Server load failed. See logs/sql_error.txt';exit 1
} finally {$connection.Dispose()}
