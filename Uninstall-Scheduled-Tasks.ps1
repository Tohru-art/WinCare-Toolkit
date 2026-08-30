function Test-Admin{
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if(-not(Test-Admin)){
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

@("WinCare Toolkit V2.3.0 - Monthly","WinCare Toolkit V2.3.0 - Quarterly Defender Full Scan")|ForEach-Object{
    schtasks.exe /Delete /TN $_ /F 2>$null|Out-Null
}

Write-Host "WinCare Toolkit V2.3.0 scheduled tasks removed."
Read-Host "Press Enter"
