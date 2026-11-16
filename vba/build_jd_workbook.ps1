param([Parameter(Mandatory=$true)][string]$BatchDir)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$e=New-Object -ComObject Excel.Application
$e.Visible=$true
Start-Sleep -Seconds 2
$e.DisplayAlerts=$false;$e.AutomationSecurity=3
$w=$e.Workbooks.Add()
while($w.Worksheets.Count -gt 1){$w.Worksheets.Item(2).Delete()}
$menu=$w.Worksheets.Item(1);$menu.Name='Dashboard_Menu'
function AddTable($sheetName,$tableName,$file,$extra){
 $s=$w.Worksheets.Add();$s.Name=$sheetName
 $rows=@(Import-Csv -LiteralPath (Join-Path $BatchDir $file) -Encoding UTF8)
 $cols=@($rows[0].PSObject.Properties.Name)+$extra
 for($j=0;$j -lt $cols.Count;$j++){$s.Cells.Item(1,$j+1).Value2=$cols[$j]}
 for($i=0;$i -lt $rows.Count;$i++){
  for($j=0;$j -lt ($cols.Count-$extra.Count);$j++){
   $v=$rows[$i].($cols[$j]);$c=$s.Cells.Item($i+2,$j+1)
   if($v -ne ''){
    if($cols[$j] -in @('Duration_Hours','Downtime_Hours')){$c.Formula=$v}
    elseif($cols[$j] -in @('Date','Due_Date','Completed_Date')){$d=[datetime]::Parse($v,[cultureinfo]::InvariantCulture);$c.Formula='=DATE('+$d.Year+','+$d.Month+','+$d.Day+')+TIME('+$d.Hour+','+$d.Minute+','+$d.Second+')';$c.NumberFormat='yyyy-mm-dd hh:mm'}
    else{$c.Value2=$v}
   }
  }
 }
 $r=$s.Range($s.Cells.Item(1,1),$s.Cells.Item($rows.Count+1,$cols.Count))
 $t=$s.ListObjects.Add(1,$r,$null,1);$t.Name=$tableName;$t.TableStyle='TableStyleMedium2'
 $s.UsedRange.Columns.AutoFit()|Out-Null
 return $s
}
try{
 $null=AddTable 'Machine_Master' 'tblMachines' 'machines.csv' @()
 $null=AddTable 'Maintenance_Input' 'tblMaintenance' 'maintenance_records.csv' @()
 $null=AddTable 'PM_Schedule' 'tblPM' 'pm_schedule.csv' @('Alert_Status','Days_Remaining')
 $s=$w.Worksheets.Add();$s.Name='Export_Log'
 $headers=@('Export_Time','File_Name','Row_Count','Status','Folder')
 for($i=0;$i -lt $headers.Count;$i++){$s.Cells.Item(1,$i+1).Value2=$headers[$i]}
 $t=$s.ListObjects.Add(1,$s.Range('A1:E2'),$null,1);$t.Name='tblExportLog';$t.ListRows.Item(1).Delete()
 $w.Names.Add('MachineID_List','=tblMachines[Machine_ID]')|Out-Null
 $menu.Range('A1:F1').Merge();$menu.Range('A1').Value2='MAINTENANCE PLANNER | SYNTHETIC DATA'
 $menu.Range('A3').Value2='Result';$menu.Range('B3:F4').Merge();$menu.Range('B3').WrapText=$true
 $labels=@('Maintenance_ID (optional)','Machine_ID','Date (May-Oct 2026)','Type','Failure_Mode','Duration_Hours','Downtime_Hours','Status')
 for($i=0;$i -lt $labels.Count;$i++){$menu.Cells.Item(8+$i,1).Value2=$labels[$i]}
 $menu.Range('B8:B15').Interior.Color=13434879;$menu.Range('B10').NumberFormat='yyyy-mm-dd'
 $menu.Range('A18').Value2='PM reporting date';$menu.Range('B18').Formula='=DATE(2026,10,31)';$menu.Range('B18').NumberFormat='yyyy-mm-dd'
 $menu.Range('A21:F21').Merge();$menu.Range('A21').Value2='Blank form: Validate/Submit checks all data. Filled form: appends one completed event.'
 $menu.Range('A22:F22').Merge();$menu.Range('A22').Value2='Edit PM tasks directly in PM_Schedule. Three macros only. Warning window: 7 days.'
 $menu.Range('A23:F23').Merge();$menu.Range('A23').Value2='PM_Type: Daily check / Weekly lubrication / Monthly inspection (sampled tasks, not a complete calendar).'
 $menu.Range('A24:F24').Merge();$menu.Range('A24').Value2='Export => project exports/<batch>. Ctrl+S saves records and logs. No real company data.'
 $menu.Activate()
 foreach($entry in @(@('B9','=MachineID_List'),@('B11','Preventive,Corrective,Inspection'),@('B15','Completed'))){$v=$menu.Range($entry[0]).Validation;$v.Add(3,1,[Type]::Missing,$entry[1]);$v.ShowError=$true}
 $menu.Range('B13:B14').Validation.Add(2,1,7,'0')
 $buttons=@(@('Validate / Submit','ValidateSubmit'),@('Refresh PM Status','RefreshPMStatus'),@('Export three CSVs','ExportData'))
 for($i=0;$i -lt $buttons.Count;$i++){$b=$menu.Shapes.AddShape(5,490,110+$i*55,210,38);$b.TextFrame.Characters().Text=$buttons[$i][0];$b.OnAction="'Maintenance_Planner.xlsm'!JDPlanner."+$buttons[$i][1];$b.Fill.ForeColor.RGB=8278823;$b.TextFrame.Characters().Font.Color=16777215}
 $menu.Columns.Item('A').ColumnWidth=30;$menu.Columns.Item('B').ColumnWidth=28;$menu.Range('C:F').ColumnWidth=18
 $menu.Range('A1:F1').Interior.Color=8278823;$menu.Range('A1:F1').Font.Color=16777215;$menu.Range('A1').Font.Size=18;$menu.Rows.Item(1).RowHeight=35
 $menu.Range('B3').Value2='Ready. Fully synthetic, May-Oct 2026. 20 machines.'
 New-Item -ItemType Directory -Force -Path (Join-Path $root 'excel')|Out-Null
 $w.SaveAs((Join-Path $root 'excel\Maintenance_Planner.xlsm'),52)
 Write-Output 'Workbook built; VBA import next.'
}catch{Write-Output $_.ScriptStackTrace;throw}
