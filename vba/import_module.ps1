param([Parameter(Mandatory=$true)][string]$ModulePath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;using System.Runtime.InteropServices;
public class NativeImport {
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,string l);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
}
'@
$root=[System.Windows.Automation.AutomationElement]::RootElement
function Find($parent,$property,$value){
 $c=New-Object System.Windows.Automation.PropertyCondition($property,$value)
 return $parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$c)
}
$editor=Find $root ([System.Windows.Automation.AutomationElement]::ClassNameProperty) 'wndclass_desked_gsk'
if(!$editor){throw 'Open the intended workbook in the VBA editor first.'}
$dialog=Find $editor ([System.Windows.Automation.AutomationElement]::NameProperty) 'Import File'
if(!$dialog){
 $doc=Find $editor ([System.Windows.Automation.AutomationElement]::ControlTypeProperty) ([System.Windows.Automation.ControlType]::Document)
 $doc.SetFocus()
 $shell=New-Object -ComObject WScript.Shell
 $shell.SendKeys('^m');Start-Sleep -Milliseconds 700
 $dialog=Find $editor ([System.Windows.Automation.AutomationElement]::NameProperty) 'Import File'
}
if(!$dialog){throw 'Import File dialog did not open.'}
$field=Find $dialog ([System.Windows.Automation.AutomationElement]::ClassNameProperty) 'Edit'
$open=Find $dialog ([System.Windows.Automation.AutomationElement]::NameProperty) 'Open'
[void][NativeImport]::SendMessage([intptr]$field.Current.NativeWindowHandle,12,[intptr]0,$ModulePath)
[void][NativeImport]::PostMessage([intptr]$open.Current.NativeWindowHandle,245,[intptr]0,[intptr]0)
Start-Sleep -Milliseconds 700
if(Find $editor ([System.Windows.Automation.AutomationElement]::NameProperty) 'Import File'){throw 'Import dialog is still open.'}
Write-Output 'Module imported. Save the intended workbook.'
