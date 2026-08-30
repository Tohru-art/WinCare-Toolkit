param([string]$Time="13:00",[int]$DayOfMonth=1)

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

$task="WinCare Toolkit V2.3.0 - Quarterly Defender Full Scan"
$tr="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$dest`" -Mode FullScan -NonInteractive"

schtasks.exe /Create /TN "$task" /TR "$tr" /SC MONTHLY /MO 3 /D $DayOfMonth /ST $Time /RU SYSTEM /RL HIGHEST /F|Out-Host

Write-Host ""
Write-Host "Optional quarterly Defender Full Scan installed."
Write-Host "If Defender is not active, the scan safely skips."
Read-Host "Press Enter"
