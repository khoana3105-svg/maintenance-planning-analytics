$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$watch=Start-Job {
 Add-Type -AssemblyName UIAutomationClient;Add-Type -AssemblyName UIAutomationTypes
 Add-Type 'using System;using System.Runtime.InteropServices;public class ClickOK{[DllImport("user32.dll")]public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);}'
 for($i=0;$i -lt 600;$i++){
  try{$r=[System.Windows.Automation.AutomationElement]::RootElement;$c=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Synthetic Maintenance Planner');$d=$r.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$c)
   if($d){$c=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'OK');$ok=$d.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$c);if($ok){[void][ClickOK]::PostMessage([intptr]$ok.Current.NativeWindowHandle,245,[intptr]0,[intptr]0)}}
  }catch{};Start-Sleep -Milliseconds 150
 }
}
try{
 $e=[Runtime.InteropServices.Marshal]::GetActiveObject('Excel.Application')
 foreach($b in @($e.Workbooks)){if($b.Name -eq 'Maintenance_Planner.xlsm'){$b.Save();$b.Close($false)}}
 $copy=Join-Path $PSScriptRoot 'JD_Excel_test.xlsm'
 Copy-Item -LiteralPath (Join-Path $root 'excel\Maintenance_Planner.xlsm') -Destination $copy -Force
 $e.AutomationSecurity=1;$w=$e.Workbooks.Open($copy);$e.AutomationSecurity=3
 $menu=$w.Worksheets.Item('Dashboard_Menu');$t=$w.Worksheets.Item('Maintenance_Input').ListObjects.Item('tblMaintenance')
 $results=@()
 function Run($macro){$e.Run("'JD_Excel_test.xlsm'!JDPlanner.$macro")|Out-Null;return [string]$menu.Range('B3').Value2}
 $msg=Run 'ValidateSubmit';$results+=[pscustomobject]@{Test='Validate baseline';Pass=$msg.StartsWith('PASS');Message=$msg}
 $msg=Run 'RefreshPMStatus';$results+=[pscustomobject]@{Test='Refresh PM';Pass=$msg.StartsWith('PM refreshed');Message=$msg}
 $n=$t.ListRows.Count
 $menu.Range('B9').Value2='M999';$msg=Run 'ValidateSubmit';$results+=[pscustomobject]@{Test='Reject unknown machine';Pass=($msg.StartsWith('Rejected') -and $t.ListRows.Count -eq $n);Message=$msg}
 $menu.Range('B9').Value2='M001';$menu.Range('B10').Formula='=DATE(2026,10,15)';$menu.Range('B11').Value2='Corrective';$menu.Range('B12').Value2='Test bearing';$menu.Range('B13').Formula='2';$menu.Range('B14').Formula='3';$menu.Range('B15').Value2='Completed'
 $msg=Run 'ValidateSubmit';$results+=[pscustomobject]@{Test='Submit valid';Pass=($msg.StartsWith('Saved') -and $t.ListRows.Count -eq $n+1);Message=$msg}
 $t.ListRows.Item($t.ListRows.Count).Delete()
 $old=$t.DataBodyRange.Cells.Item(1,6).Value2;$t.DataBodyRange.Cells.Item(1,6).Formula='-1';$msg=Run 'ExportData';$results+=[pscustomobject]@{Test='Export blocks negative duration';Pass=$msg.StartsWith('FAIL');Message=$msg};$t.DataBodyRange.Cells.Item(1,6).Formula=[string]$old
 $msg=Run 'ExportData';$results+=[pscustomobject]@{Test='Export 3 source files';Pass=$msg.StartsWith('Exported 3');Message=$msg}
 $first=$msg;$msg=Run 'ExportData';$results+=[pscustomobject]@{Test='Repeat export unique folder';Pass=($msg.StartsWith('Exported 3') -and $msg -ne $first);Message=$msg}
 $results|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'excel_results.json') -Encoding UTF8
 $w.Save();$w.Close($false)
 $results|Format-Table -AutoSize
 if(@($results|Where-Object {-not $_.Pass}).Count){throw 'Excel test failure'}
}finally{Stop-Job $watch;Remove-Job $watch}
