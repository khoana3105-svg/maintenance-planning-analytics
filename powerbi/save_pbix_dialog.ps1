param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;using System.Runtime.InteropServices;
public class FileDialogNative {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
}
'@
$root=[System.Windows.Automation.AutomationElement]::RootElement
function Find($parent,$property,$value){$c=New-Object System.Windows.Automation.PropertyCondition($property,$value);return $parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$c)}
$dialog=Find $root ([System.Windows.Automation.AutomationElement]::NameProperty) 'Save As'
if(!$dialog){throw 'Open Save As first'}
[void][FileDialogNative]::SetForegroundWindow([intptr]$dialog.Current.NativeWindowHandle)
function Click($item,[bool]$arrow=$false){
 $b=$item.Current.BoundingRectangle
 $x=if($arrow){$b.Right-10}else{$b.X+$b.Width/2}
 [void][FileDialogNative]::SetCursorPos([int]$x,[int]($b.Y+$b.Height/2))
 [FileDialogNative]::mouse_event(2,0,0,0,[uintptr]::Zero);[FileDialogNative]::mouse_event(4,0,0,0,[uintptr]::Zero)
}
$type=Find $dialog ([System.Windows.Automation.AutomationElement]::AutomationIdProperty) 'FileTypeControlHost'
$filename=Find $dialog ([System.Windows.Automation.AutomationElement]::AutomationIdProperty) 'FileNameControlHost'
if(!$type -or !$filename){throw 'Unexpected file dialog layout'}
$shell=New-Object -ComObject WScript.Shell
Click $type $true
Start-Sleep -Milliseconds 150
$shell.SendKeys('{HOME}{ENTER}')
Start-Sleep -Milliseconds 150
Click $filename
$clipboard=[Windows.Forms.Clipboard]::GetDataObject()
try{
 [Windows.Forms.Clipboard]::SetText($Destination)
 $shell.SendKeys('^a');$shell.SendKeys('^v');$shell.SendKeys('{TAB}')
 Start-Sleep -Milliseconds 200
 foreach($item in $dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)){
  if($item.Current.Name -eq 'Save' -and $item.Current.ClassName -eq 'Button'){Click $item;break}
 }
}finally{if($clipboard){[Windows.Forms.Clipboard]::SetDataObject($clipboard,$true)}}
Start-Sleep -Milliseconds 700
$confirm=Find $root ([System.Windows.Automation.AutomationElement]::NameProperty) 'Confirm Save As'
if($confirm){
 $all=$confirm.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
 $text=($all|ForEach-Object {$_.Current.Name}) -join ' '
 if($text -notlike ('*'+[IO.Path]::GetFileName($Destination)+'*')){throw 'Unexpected overwrite target'}
 foreach($item in $all){if($item.Current.Name -eq 'Yes'){
  [void][FileDialogNative]::SetForegroundWindow([intptr]$confirm.Current.NativeWindowHandle)
  [void][FileDialogNative]::PostMessage([intptr]$item.Current.NativeWindowHandle,245,[intptr]0,[intptr]0);break
 }}
}
Write-Output 'PBIX save requested; verify file timestamp and reopen.'
