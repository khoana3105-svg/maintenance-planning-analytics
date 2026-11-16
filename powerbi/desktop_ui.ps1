param([string]$Action='snapshot',[string]$Name,[string]$Keys,[string]$Path,[int]$X,[int]$Y)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;using System.Runtime.InteropServices;
public class DesktopNative {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,IntPtr p);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool attach);
 public static void Focus(IntPtr h) {
  uint source=GetCurrentThreadId(), target=GetWindowThreadProcessId(GetForegroundWindow(),IntPtr.Zero);
  AttachThreadInput(source,target,true); ShowWindow(h,IsIconic(h)?9:5); SetForegroundWindow(h); AttachThreadInput(source,target,false);
 }
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,string s);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr extra);
}
'@
$root=[System.Windows.Automation.AutomationElement]::RootElement
$ids=@(Get-CimInstance Win32_Process -Filter "Name='PBIDesktop.exe'"|Sort-Object CreationDate -Descending|Select-Object -ExpandProperty ProcessId)
$windows=$root.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
$window=$null
foreach($targetId in $ids){foreach($item in $windows){if($item.Current.ProcessId -eq $targetId -and $item.Current.Name -match 'Maintenance_Analytics'){$window=$item;break}};if($window){break}}
if(!$window){foreach($item in $windows){if($item.Current.ProcessId -in $ids -and $item.Current.Name -match 'Power BI'){$window=$item;break}}}
if(!$window){throw 'Power BI window not available'}
function Find($parent,$property,$value){$condition=New-Object System.Windows.Automation.PropertyCondition($property,$value);return $parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$condition)}
if($Action -eq 'snapshot'){
 Write-Output ('WINDOW '+$window.Current.Name)
 foreach($item in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)){
  if($item.Current.Name){Write-Output ($item.Current.ControlType.ProgrammaticName+' | '+$item.Current.Name+' | '+$item.Current.AutomationId+' | '+$item.Current.NativeWindowHandle)}
 }
}elseif($Action -eq 'keys'){
 [void][DesktopNative]::ShowWindow([intptr]$window.Current.NativeWindowHandle,9)
 [DesktopNative]::Focus([intptr]$window.Current.NativeWindowHandle)
 Start-Sleep -Milliseconds 300
 $shell=New-Object -ComObject WScript.Shell;$shell.SendKeys($Keys)
}elseif($Action -eq 'invoke'){
 $item=Find $window ([System.Windows.Automation.AutomationElement]::NameProperty) $Name
 if(!$item){throw "Control not found: $Name"}
 try{([System.Windows.Automation.InvokePattern]$item.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()}
 catch{([System.Windows.Automation.SelectionItemPattern]$item.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)).Select()}
}elseif($Action -eq 'refresh'){
 $condition=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty,'Refresh')
 $clicked=$false
 foreach($candidate in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)){
  if($candidate.Current.IsEnabled -and !$candidate.Current.IsOffscreen){
   try{([System.Windows.Automation.InvokePattern]$candidate.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke();$clicked=$true;Write-Output 'Invoked native Refresh command.';break}catch{}
  }
 }
 if(!$clicked){throw 'Refresh command is unavailable'}
}elseif($Action -eq 'page'){
 $item=$null
 foreach($candidate in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)){
  if($candidate.Current.Name -eq $Name -and $candidate.Current.ControlType.ProgrammaticName -eq 'ControlType.TabItem'){$item=$candidate;break}
 }
 if(!$item){throw 'Page tab not found'}
 ([System.Windows.Automation.SelectionItemPattern]$item.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)).Select()
}elseif($Action -eq 'file'){
 $item=Find $window ([System.Windows.Automation.AutomationElement]::ClassNameProperty) 'Edit'
 $edits=$window.FindAll([System.Windows.Automation.TreeScope]::Descendants,(New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty,'Edit')))
 foreach($edit in $edits){if($edit.Current.AutomationId -in @('1148','1001')){$item=$edit;break}}
 if(!$item){throw 'Filename field not found'}
 [void][DesktopNative]::SendMessage([intptr]$item.Current.NativeWindowHandle,12,[intptr]0,$Path)
 $button=$null
 foreach($candidate in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)){
  if($candidate.Current.Name -eq $Name -and $candidate.Current.ClassName -eq 'Button' -and $candidate.Current.NativeWindowHandle){$button=$candidate;break}
 }
 if(!$button){throw 'File dialog button not found'}
 if($button.Current.NativeWindowHandle){[void][DesktopNative]::PostMessage([intptr]$button.Current.NativeWindowHandle,245,[intptr]0,[intptr]0)}
 else{([System.Windows.Automation.InvokePattern]$button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()}
}elseif($Action -eq 'click'){
 [DesktopNative]::Focus([intptr]$window.Current.NativeWindowHandle)
 Start-Sleep -Milliseconds 200
 $rect=$window.Current.BoundingRectangle
 [void][DesktopNative]::SetCursorPos([int]$rect.X+$X,[int]$rect.Y+$Y)
 [DesktopNative]::mouse_event(2,0,0,0,[uintptr]::Zero);[DesktopNative]::mouse_event(4,0,0,0,[uintptr]::Zero)
}elseif($Action -eq 'screenshot'){
 Add-Type -AssemblyName System.Drawing
 Add-Type -AssemblyName System.Windows.Forms
 [DesktopNative]::Focus([intptr]$window.Current.NativeWindowHandle)
 [void][DesktopNative]::ShowWindow([intptr]$window.Current.NativeWindowHandle,3)
 Start-Sleep -Milliseconds 500
 $rect=$window.Current.BoundingRectangle
 if($Name -eq 'canvas'){
  foreach($candidate in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)){
   if($candidate.Current.Name -eq 'Power BI Report' -and $candidate.Current.ControlType.ProgrammaticName -eq 'ControlType.Group' -and !$candidate.Current.IsOffscreen){$rect=$candidate.Current.BoundingRectangle;break}
  }
 }
 [void][DesktopNative]::SetCursorPos([int]$window.Current.BoundingRectangle.Right-30,[int]$window.Current.BoundingRectangle.Top+50)
 Start-Sleep -Milliseconds 1100
 $bitmap=New-Object Drawing.Bitmap([int]$rect.Width,[int]$rect.Height)
 $g=[Drawing.Graphics]::FromImage($bitmap);$g.CopyFromScreen([int]$rect.X,[int]$rect.Y,0,0,$bitmap.Size)
 $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bitmap.Dispose()
}
