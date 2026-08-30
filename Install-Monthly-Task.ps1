param([string]$Time="12:00",[int]$DayOfMonth=1)

function Test-Admin{
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if(-not(Test-Admin)){
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Time `"$Time`" -DayOfMonth $DayOfMonth"
    exit
}

$destDir=Join-Path $env:ProgramData "WinCare ToolkitV230"
New-Item -ItemType Directory -Force -Path $destDir|Out-Null
$dest=Join-Path $destDir "WinCare Toolkit-V2.3.0.ps1"
Copy-Item (Join-Path $PSScriptRoot "WinCare Toolkit-V2.3.0.ps1") $dest -Force

$task="WinCare Toolkit V2.3.0 - Monthly"
$tr="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$dest`" -Mode Monthly -NonInteractive"

schtasks.exe /Create /TN "$task" /TR "$tr" /SC MONTHLY /D $DayOfMonth /ST $Time /RU SYSTEM /RL HIGHEST /F|Out-Host

Write-Host ""
Write-Host "Installed: $task"
Write-Host "Runs as: NT AUTHORITY\SYSTEM"
Write-Host "Schedule: day $DayOfMonth at $Time"
Write-Host "Automatic reboot: never"
Read-Host "Press Enter"
