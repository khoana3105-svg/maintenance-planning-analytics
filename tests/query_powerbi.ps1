param([string]$Query='EVALUATE ROW("Downtime",[Total Downtime Hours],"Breakdowns",[Breakdown Count],"MTTR",[MTTR],"MTBF",[MTBF],"PMCompliance",[PM Compliance Rate])',[string]$Output)
$ErrorActionPreference='Stop'
$pkg=Get-AppxPackage '*PowerBI*'|Select-Object -First 1
[void][Reflection.Assembly]::LoadFrom((Join-Path $pkg.InstallLocation 'bin\Microsoft.PowerBI.AdomdClient.dll'))
$processes=Get-CimInstance Win32_Process -Filter "Name='msmdsrv.exe'" | Sort-Object CreationDate -Descending
$connection=$null
foreach($engine in $processes){
 if($engine.CommandLine -match '-s "([^"]+)"'){
  $portFile=Join-Path $Matches[1] 'msmdsrv.port.txt'
  if(Test-Path -LiteralPath $portFile){
   $port=([IO.File]::ReadAllText($portFile,[Text.Encoding]::Unicode)).Trim([char]0).Trim()
   $candidate=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$port;")
   try{
    $candidate.Open();$command=$candidate.CreateCommand();$command.CommandText='EVALUATE ROW("Exists",COUNTROWS(Dim_Machine))';$reader=$command.ExecuteReader();$reader.Close()
    $connection=$candidate;break
   }catch{$candidate.Dispose()}
  }
 }
}
if(!$connection){throw 'Open the Maintenance Power BI model first.'}
try{
 $cmd=$connection.CreateCommand();$cmd.CommandText=$Query;$reader=$cmd.ExecuteReader();$rows=@()
 while($reader.Read()){
  $row=[ordered]@{}
  for($i=0;$i -lt $reader.FieldCount;$i++){$v=$reader.GetValue($i);if($v -is [DBNull]){$v=$null};$row[$reader.GetName($i)]=$v}
  $rows += [pscustomobject]$row
 }
 $json=ConvertTo-Json -InputObject @($rows) -Depth 8
 if($Output){[IO.File]::WriteAllText($Output,$json,[Text.UTF8Encoding]::new($false));Write-Output ('Saved '+$rows.Count+' DAX rows: '+$Output)}else{Write-Output $json}
}finally{$connection.Dispose()}
