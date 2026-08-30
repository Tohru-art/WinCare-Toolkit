param(
    [ValidateSet("Menu","Monthly","Audit","Security","Storage","Network","Repair","FullScan","RecycleBin","Aggressive","SelfCheck")]
    [string]$Mode="Menu",
    [switch]$NonInteractive
)

$ErrorActionPreference="SilentlyContinue"
$ProgressPreference="SilentlyContinue"

function Test-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if(-not(Test-Admin)){
    $a=@("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-Mode",$Mode)
    if($NonInteractive){$a+="-NonInteractive"}
    Start-Process powershell.exe -Verb RunAs -ArgumentList ($a -join " ")
    exit
}

$Root=Join-Path $env:ProgramData "WinCare ToolkitV232"
$LogDir=Join-Path $Root "Logs"
$HistoryDir=Join-Path $Root "History"
New-Item -ItemType Directory -Force -Path $LogDir,$HistoryDir|Out-Null

$Latest=Join-Path $HistoryDir "Latest.json"

function New-RunContext {
    $script:Stamp=Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $script:RunDate=Get-Date -Format "yyyy-MM-dd"
    $script:Log=Join-Path $LogDir ("WinCare ToolkitV232_"+$script:Stamp+".log")
    $script:Json=Join-Path $HistoryDir ("WinCare ToolkitV232_"+$script:Stamp+".json")
    $script:Started=Get-Date

    $script:Results=New-Object System.Collections.Generic.List[object]
    $script:Warnings=0
    $script:Critical=0
    $script:Info=0
    $script:Category="General"
    $script:NextSteps=New-Object System.Collections.Generic.List[string]
}

function Line([string]$t=""){
    Write-Host $t
    Add-Content -Path $Log -Value $t
}

function Header([string]$Title){
    Clear-Host
    $shortLog=[System.IO.Path]::GetFileName($Log)
    Line "================================================================"
    Line "                       WinCare Toolkit v2.3.2"
    Line "                 Windows Maintenance & Diagnostics"
    Line "================================================================"
    Line ("Run:  {0,-30} Log: {1}" -f $RunDate,$shortLog)
    Line ""
    if($Title){ Line $Title.ToUpper(); Line "" }
}

function Section([string]$Title,[string]$Description=""){
    Line ""
    Line $Title.ToUpper()
    if($Description){Line ("  "+$Description)}
    Line "  --------------------------------------------------------------"
}

function Status([string]$Name,[string]$Value,[string]$State="INFO",[string]$Detail=""){
    $s=$State.ToUpper()
    $tag=switch($s){
        "HEALTHY"{"[ OK ]"}
        "INFO"{"[INFO]"}
        "ATTENTION"{"[WARN]"}
        "CRITICAL"{"[FAIL]"}
        default{"[INFO]"}
    }
    Line ("  {0} {1,-34} {2}" -f $tag,$Name,$Value)
    if($Detail){Line ("         > "+$Detail)}

    $script:Results.Add([PSCustomObject]@{
        category=$script:Category
        name=$Name
        status=$s
        value=$Value
        detail=$Detail
        time=(Get-Date).ToString("o")
    })

    if($s -eq "INFO"){$script:Info++}
    if($s -eq "ATTENTION"){$script:Warnings++}
    if($s -eq "CRITICAL"){$script:Critical++}
}

function Add-NextStep([string]$Text){
    if($Text -and -not $script:NextSteps.Contains($Text)){
        $script:NextSteps.Add($Text)
    }
}

function Run-Logged([string]$Exe,[string[]]$Args,[string]$Label){
    $sw=[Diagnostics.Stopwatch]::StartNew()
    Line ("       Running: "+$Exe)
    $out=& $Exe @Args 2>&1
    $code=$LASTEXITCODE
    $sw.Stop()
    $out|ForEach-Object{Add-Content -Path $Log -Value $_}

    if($code -eq 0){
        Status $Label ("Success, {0:N1}s" -f $sw.Elapsed.TotalSeconds) "HEALTHY" "Exit code 0"
    }else{
        Status $Label ("Exit code $code, {0:N1}s" -f $sw.Elapsed.TotalSeconds) "ATTENTION" "Review the log for command output"
        Add-NextStep "Review the DISM/SFC result in the latest log."
    }
    return $code
}

function Get-CDrive {Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"}
function Get-FreeGB {$d=Get-CDrive;if($d){[math]::Round($d.FreeSpace/1GB,1)}}

function Remove-Old([string]$Path,[int]$Hours){
    if(-not(Test-Path $Path)){return 0}
    $cut=(Get-Date).AddHours(-$Hours)
    $freed=[int64]0
    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue|ForEach-Object{
        try{
            if($_.LastWriteTime -lt $cut){
                if($_.PSIsContainer){
                    $size=(Get-ChildItem -LiteralPath $_.FullName -Force -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
                }else{$size=$_.Length}
                if($null -eq $size){$size=0}
                Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                if(-not(Test-Path $_.FullName)){$freed+=[int64]$size}
            }
        }catch{}
    }
    return $freed
}

function Format-Bytes([long]$Bytes){
    if($Bytes -ge 1GB){return ("{0:N2} GB" -f ($Bytes/1GB))}
    if($Bytes -ge 1MB){return ("{0:N1} MB" -f ($Bytes/1MB))}
    if($Bytes -ge 1KB){return ("{0:N1} KB" -f ($Bytes/1KB))}
    return ("{0} bytes" -f $Bytes)
}

function Format-Uptime($Span){
    if($Span.TotalDays -ge 1){return ("{0}d {1}h {2}m" -f [int]$Span.TotalDays,$Span.Hours,$Span.Minutes)}
    if($Span.TotalHours -ge 1){return ("{0}h {1}m" -f [int]$Span.TotalHours,$Span.Minutes)}
    return ("{0}m {1}s" -f $Span.Minutes,$Span.Seconds)
}

function Decode-AVState([int]$State){
    $hex=("0x{0:X6}" -f $State)
    $enabledByte=($State -shr 8) -band 0xFF
    $signatureByte=$State -band 0xFF

    $enabled=$null
    if($enabledByte -in 0x10,0x11){$enabled=$true}
    elseif($enabledByte -in 0x00,0x01){$enabled=$false}

    $updated=$null
    if($signatureByte -eq 0x00){$updated=$true}
    elseif($signatureByte -eq 0x10){$updated=$false}

    [PSCustomObject]@{Hex=$hex;Enabled=$enabled;Updated=$updated}
}

function Get-AVProviders {
    try{
        return @(Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction Stop|
            Select-Object displayName,productState,pathToSignedProductExe)
    }catch{return @()}
}

function Show-Security([switch]$Quick,[switch]$Full){
    $script:Category="Security"
    Section "SECURITY" "Registered antivirus providers and firewall state"

    $avs=Get-AVProviders
    if($avs.Count -gt 0){
        foreach($a in $avs){
            $d=Decode-AVState ([int]$a.productState)
            $state="INFO";$summary="Registered, state unclear"
            if($d.Enabled -eq $true -and $d.Updated -eq $true){$state="HEALTHY";$summary="Active, defs current"}
            elseif($d.Enabled -eq $true -and $d.Updated -eq $false){$state="ATTENTION";$summary="Active, defs may be outdated";Add-NextStep ("Update "+$a.displayName+" definitions.")}
            elseif($d.Enabled -eq $false){$state="INFO";$summary="Registered, not active"}
            Status $a.displayName ($summary+" | "+$d.Hex) $state "Windows Security Center registration state"
        }
    }else{
        Status "Antivirus provider" "None detected" "ATTENTION"
        Add-NextStep "Confirm an antivirus provider is installed and active."
    }

    $defAvail=$null -ne (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)
    $defActive=$false
    if($defAvail){
        $m=Get-MpComputerStatus
        $defActive=[bool]$m.AntivirusEnabled
        if($defActive){
            Status "Microsoft Defender engine" "Active" "HEALTHY"
            Status "Defender real-time" ([string]$m.RealTimeProtectionEnabled) "HEALTHY"
        }else{
            Status "Microsoft Defender engine" "Inactive / passive" "INFO" "expected when another antivirus is primary"
        }
    }else{
        Status "Microsoft Defender engine" "Cmdlets unavailable" "INFO"
    }

    $fw=Get-NetFirewallProfile
    if($fw){
        $off=@($fw|Where-Object{-not $_.Enabled})
        if($off.Count -eq 0){
            Status "Windows Firewall" "Domain, Private, Public enabled" "HEALTHY"
        }else{
            Status "Windows Firewall" ("Disabled: "+(($off.Name)-join ", ")) "ATTENTION"
            Add-NextStep "Review disabled Windows Firewall profiles."
        }
    }

    if($Quick){
        if($defActive){
            try{Start-MpScan -ScanType QuickScan;Status "Defender Quick Scan" "Completed" "HEALTHY"}
            catch{Status "Defender Quick Scan" "Failed" "ATTENTION";Add-NextStep "Review the Defender Quick Scan failure."}
        }else{
            Status "Defender Quick Scan" "Skipped" "INFO" "Defender is not the active antivirus"
        }
    }

    if($Full){
        if($defActive){
            try{Start-MpScan -ScanType FullScan;Status "Defender Full Scan" "Completed" "HEALTHY"}
            catch{Status "Defender Full Scan" "Failed" "ATTENTION";Add-NextStep "Review the Defender Full Scan failure."}
        }else{
            Status "Defender Full Scan" "Skipped" "INFO" "Defender is not the active antivirus"
        }
    }
}

function Get-RebootState {
    $wu=Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    $cbs=Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    $cbsi=Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress"
    $ren=@()
    try{$ren=@((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations)}catch{}
    $uev=0
    try{$uev=[int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Updates" -Name UpdateExeVolatile -ErrorAction Stop).UpdateExeVolatile}catch{}
    $hard=$wu -or $cbs -or $cbsi -or ($uev -ne 0)
    [PSCustomObject]@{WU=$wu;CBS=$cbs;CBSI=$cbsi;Rename=$ren;UEV=$uev;Hard=$hard}
}

function Show-Reboot {
    $script:Category="Restart"
    Section "RESTART STATE" "Distinguishes hard reboot requirements from leftover file ops"

    $r=Get-RebootState

    if($r.WU){Status "Windows Update reboot" "Required" "ATTENTION";Add-NextStep "Restart Windows when convenient to complete Windows Update."}
    else{Status "Windows Update reboot" "No" "HEALTHY"}

    if($r.CBS -or $r.CBSI){Status "Component servicing reboot" "Required" "ATTENTION";Add-NextStep "Restart Windows when convenient to complete component servicing."}
    else{Status "Component servicing reboot" "No" "HEALTHY"}

    if($r.Rename.Count -gt 0){
        $st=if($r.Hard){"ATTENTION"}else{"INFO"}
        Status "Pending file operations" ([string]$r.Rename.Count+" entries") $st "does not alone require a reboot"
        $shown=0
        foreach($x in $r.Rename){
            if($x -and $shown -lt 4){
                Line ("         > "+$x)
                $shown++
            }
        }
        if(-not $r.Hard){Add-NextStep ("Pending file operations will normally clear during a future restart.")}
    }else{
        Status "Pending file operations" "None" "HEALTHY"
    }

    if($r.Hard){Status "Restart assessment" "Restart required" "ATTENTION"}
    elseif($r.Rename.Count -gt 0){Status "Restart assessment" "No hard reboot required" "INFO"}
    else{Status "Restart assessment" "No reboot required" "HEALTHY"}
}

function Show-StorageHealth {
    $script:Category="Storage"
    Section "STORAGE HEALTH" "Uses both percentage and absolute free space"

    $d=Get-CDrive
    if($d){
        $free=[math]::Round($d.FreeSpace/1GB,1)
        $total=[math]::Round($d.Size/1GB,1)
        $pct=[math]::Round(($d.FreeSpace/$d.Size)*100,1)

        if($free -lt 20 -or $pct -lt 5){$st="CRITICAL";$msg="Very low free space";Add-NextStep "Free disk space soon."}
        elseif($free -lt 50 -or $pct -lt 8){$st="ATTENTION";$msg="Low free space";Add-NextStep "Consider freeing disk space."}
        elseif($free -ge 100){$st="HEALTHY";$msg="Healthy working space"}
        else{$st="INFO";$msg="Monitor capacity"}

        Status "C: free space" "$free GB / $total GB ($pct%)" $st
        Status "Storage assessment" $msg $st
    }

    $pds=Get-PhysicalDisk
    if($pds){
        foreach($p in $pds){
            $st=if($p.HealthStatus -eq "Healthy"){"HEALTHY"}else{"ATTENTION"}
            Status $p.FriendlyName ($p.HealthStatus+", "+[math]::Round($p.Size/1GB,0)+" GB") $st
            if($st -eq "ATTENTION"){Add-NextStep ("Review drive health for "+$p.FriendlyName+".")}
        }
    }

    Status "Manual SSD/NVMe defrag" "Not performed" "HEALTHY"
}

function Show-Devices {
    $script:Category="Devices"
    Section "DEVICE HEALTH" "Disabled devices are informational, not failures"

    $dev=@(Get-PnpDevice -PresentOnly)
    $disabled=@($dev|Where-Object{$_.Problem -eq "CM_PROB_DISABLED" -or $_.ConfigManagerErrorCode -eq "CM_PROB_DISABLED"})
    $bad=@($dev|Where-Object{
        $_.Status -ne "OK" -and $_.Problem -ne "CM_PROB_DISABLED" -and $_.ConfigManagerErrorCode -ne "CM_PROB_DISABLED"
    })

    if($bad.Count -eq 0){
        Status "Active device failures" "None detected" "HEALTHY"
    }else{
        Status "Active device failures" ([string]$bad.Count) "ATTENTION"
        $bad|Select-Object -First 8|ForEach-Object{Line ("         > "+$_.FriendlyName+" ["+$_.Status+"]")}
        Add-NextStep "Review active device failures in Device Manager."
    }

    if($disabled.Count -gt 0){
        Status "Disabled devices" ([string]$disabled.Count) "INFO"
        $disabled|Select-Object -First 8|ForEach-Object{Line ("         > "+$_.FriendlyName+" [Disabled]")}
    }else{
        Status "Disabled devices" "None" "HEALTHY"
    }

    $v=@($dev|Where-Object{$_.FriendlyName -like "*VirtualBox*"})
    if($v.Count -gt 0){
        $ok=@($v|Where-Object{$_.Status -eq "OK"}).Count
        $off=@($v|Where-Object{$_.Problem -eq "CM_PROB_DISABLED" -or $_.ConfigManagerErrorCode -eq "CM_PROB_DISABLED"}).Count
        Status "VirtualBox adapters" "$ok working, $off disabled" "INFO"
    }
}

function Get-Event41Data($e){
    [xml]$x=$e.ToXml()
    $m=@{}
    foreach($d in $x.Event.EventData.Data){$m[$d.Name]=$d.'#text'}
    $bc=0;$wh=0
    if($m.ContainsKey("BugcheckCode")){$bc=[int64]$m["BugcheckCode"]}
    if($m.ContainsKey("WHEABootErrorCount")){$wh=[int64]$m["WHEABootErrorCount"]}
    [PSCustomObject]@{Bugcheck=$bc;WHEA=$wh}
}

function Show-Stability {
    $script:Category="Stability"
    Section "STABILITY ANALYSIS" "Correlates Event 41 with crash and shutdown evidence"

    $since=(Get-Date).AddDays(-7)
    $e41=@(Get-WinEvent -FilterHashtable @{LogName="System";Id=41;StartTime=$since} -MaxEvents 20)

    if($e41.Count -eq 0){
        Status "Kernel-Power 41 events (7d)" "None" "HEALTHY"
        return
    }

    Status "Kernel-Power 41 events (7d)" ([string]$e41.Count) "INFO"

    $last=$e41|Sort-Object TimeCreated -Descending|Select-Object -First 1
    $d=Get-Event41Data $last

    $near=@(Get-WinEvent -FilterHashtable @{LogName="System";StartTime=$last.TimeCreated.AddMinutes(-5);EndTime=$last.TimeCreated.AddMinutes(2)}|
        Where-Object{$_.Id -in 41,1074,6005,6006,6008,1001})

    $has1001=@($near|Where-Object{$_.Id -eq 1001}).Count -gt 0
    $has6008=@($near|Where-Object{$_.Id -eq 6008}).Count -gt 0
    $has1074=@($near|Where-Object{$_.Id -eq 1074}).Count -gt 0
    $has6006=@($near|Where-Object{$_.Id -eq 6006}).Count -gt 0

    if($d.Bugcheck -ne 0 -or $has1001){
        Status "Most recent Event 41" ([string]$last.TimeCreated) "ATTENTION" "bugcheck evidence detected"
        Status "Bugcheck code" ([string]$d.Bugcheck) "ATTENTION"
        Add-NextStep "Review the latest bugcheck/BSOD evidence."
    }elseif($d.WHEA -gt 0){
        Status "Most recent Event 41" ([string]$last.TimeCreated) "ATTENTION" "WHEA boot error detected"
        Status "WHEA boot errors" ([string]$d.WHEA) "ATTENTION"
        Add-NextStep "Review WHEA hardware error evidence."
    }elseif($has6008){
        Status "Most recent Event 41" ([string]$last.TimeCreated) "INFO" "unexpected shutdown recorded, no BSOD/WHEA evidence"
        Status "BSOD evidence" "None detected" "HEALTHY"
        Status "WHEA boot errors" "0" "HEALTHY"
    }else{
        Status "Most recent Event 41" ([string]$last.TimeCreated) "INFO"
    }

    if($has1074 -and $has6006){
        Status "Nearby clean restart" "Detected" "INFO"
    }
}

function Finish([string]$Type){
    $dur=(Get-Date)-$Started
    if($script:Critical -gt 0){$overall="CRITICAL";$overallTag="[FAIL]"}
    elseif($script:Warnings -gt 0){$overall="ATTENTION";$overallTag="[WARN]"}
    else{$overall="HEALTHY";$overallTag="[OK]"}

    $obj=[PSCustomObject]@{
        schemaVersion="1.0"
        product="WinCare Toolkit"
        version="2.3.2"
        runType=$Type
        started=$Started.ToString("o")
        finished=(Get-Date).ToString("o")
        durationSeconds=[math]::Round($dur.TotalSeconds,1)
        overallStatus=$overall
        infoCount=$script:Info
        warningCount=$script:Warnings
        criticalCount=$script:Critical
        resultCount=@($script:Results).Count
        logPath=$Log
        results=@($script:Results)
        nextSteps=@($script:NextSteps)
    }

    $jsonText=$obj|ConvertTo-Json -Depth 8
    Set-Content -Path $Json -Value $jsonText -Encoding UTF8
    Set-Content -Path $Latest -Value $jsonText -Encoding UTF8

    Line ""
    Line "----------------------------------------------------------------"
    Line ("  OVERALL STATUS: {0} {1}" -f $overallTag,$overall)
    if($overall -eq "HEALTHY"){
        Line "  No action required | 0 warnings | 0 critical"
    }else{
        Line ("  {0} warning(s) | {1} critical finding(s)" -f $script:Warnings,$script:Critical)
    }
    Line "----------------------------------------------------------------"

    Line ""
    Line "NEXT STEPS"
    if($script:NextSteps.Count -eq 0){
        Line "  Nothing requires action this run."
    }else{
        foreach($s in $script:NextSteps){Line ("  "+$s)}
    }
    Line "----------------------------------------------------------------"
    Line ("Log:  "+$Log)
    Line ("JSON: "+$Json)
}

function Audit {
    New-RunContext
    Header "SYSTEM HEALTH AUDIT"

    $script:Category="System"
    Section "SYSTEM" "Current runtime and memory state"
    $os=Get-CimInstance Win32_OperatingSystem
    if($os){
        $u=(Get-Date)-$os.LastBootUpTime
        Status "Windows uptime" (Format-Uptime $u) "HEALTHY"
        Status "Available RAM" ("{0:N1} GB" -f ($os.FreePhysicalMemory*1KB/1GB)) "HEALTHY"
    }

    Show-Reboot
    Show-Devices
    Show-Stability
    Show-StorageHealth
    Show-Security

    $script:Category="Windows"
    Section "WINDOWS IMAGE" "Protected Windows component-store health"
    Run-Logged "DISM.exe" @("/Online","/Cleanup-Image","/CheckHealth") "DISM CheckHealth"|Out-Null

    Finish "System Health Audit"
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class WinCare ToolkitFileOps {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct SHFILEOPSTRUCT {
        public IntPtr hwnd;
        public UInt32 wFunc;
        public string pFrom;
        public string pTo;
        public UInt16 fFlags;
        public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        public string lpszProgressTitle;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int SHFileOperation(ref SHFILEOPSTRUCT FileOp);

    public const UInt32 FO_DELETE = 0x0003;
    public const UInt16 FOF_SILENT = 0x0004;
    public const UInt16 FOF_NOCONFIRMATION = 0x0010;
    public const UInt16 FOF_NOERRORUI = 0x0400;
}
"@ -ErrorAction SilentlyContinue

function Remove-PathPermanentSilent([string]$Path) {
    if(-not $Path){return $false}
    try{
        $from = $Path + [char]0 + [char]0
        $op = New-Object WinCare ToolkitFileOps+SHFILEOPSTRUCT
        $op.hwnd = [IntPtr]::Zero
        $op.wFunc = [WinCare ToolkitFileOps]::FO_DELETE
        $op.pFrom = $from
        $op.pTo = $null
        $op.fFlags = [WinCare ToolkitFileOps]::FOF_SILENT -bor [WinCare ToolkitFileOps]::FOF_NOCONFIRMATION -bor [WinCare ToolkitFileOps]::FOF_NOERRORUI
        $op.fAnyOperationsAborted = $false
        $op.hNameMappings = [IntPtr]::Zero
        $op.lpszProgressTitle = $null
        $result = [WinCare ToolkitFileOps]::SHFileOperation([ref]$op)
        return ($result -eq 0 -and -not $op.fAnyOperationsAborted)
    }catch{
        return $false
    }
}

function Get-RecycleBinSize {
    $sid=""
    try{
        $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    }catch{}

    $bytes=[int64]0
    $items=0

    if(-not [string]::IsNullOrWhiteSpace($sid)){
        $drives=@(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID)
        foreach($drive in $drives){
            $userBin=Join-Path ($drive+"\") ('$Recycle.Bin\'+$sid)
            if(Test-Path -LiteralPath $userBin){
                $files=@(Get-ChildItem -LiteralPath $userBin -Force -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like '$R*' })
                foreach($f in $files){
                    $items++
                    $bytes += [int64]$f.Length
                }
            }
        }
    }

    [PSCustomObject]@{
        Items=$items
        Bytes=$bytes
    }
}

function Invoke-NativeRecycleBinEmpty {
    param([switch]$Confirmed)

    $script:Category="Cleanup"
    $before=Get-RecycleBinSize

    if(-not $Confirmed){
        return [PSCustomObject]@{
            Requested=$before.Items
            Deleted=0
            FreedBytes=0
            Success=$false
            Reason="Confirmation required"
        }
    }

    try{
        Clear-RecycleBin -Force -ErrorAction Stop
    }catch{
        return [PSCustomObject]@{
            Requested=$before.Items
            Deleted=0
            FreedBytes=0
            Success=$false
            Reason=$_.Exception.Message
        }
    }

    Start-Sleep -Milliseconds 500
    $after=Get-RecycleBinSize

    $deleted=[math]::Max(0,$before.Items-$after.Items)
    $freed=[math]::Max([int64]0,[int64]($before.Bytes-$after.Bytes))
    $success=($after.Items -eq 0)

    return [PSCustomObject]@{
        Requested=$before.Items
        Deleted=$deleted
        FreedBytes=$freed
        Success=$success
        Reason=if($success){""}else{"Recycle Bin still contains items after Windows cleanup"}
    }
}

function Monthly {
    New-RunContext
    Header "MONTHLY MAINTENANCE"

    $script:Category="Safety"
    Section "SAFETY POLICY" "These boundaries are never crossed automatically"
    Status "Automatic reboot" "Never" "HEALTHY"
    Status "DISM /ResetBase" "Never used" "HEALTHY"
    Status "DNS/Winsock reset" "Not automatic" "HEALTHY"
    Status "Browser/game/shader data" "Preserved" "HEALTHY"
    Status "Recycle Bin policy" "Preserved by default" "HEALTHY"

    $script:Category="Cleanup"
    Section "SAFE CLEANUP" "Balanced cleanup policy for disposable files"
    $before=Get-FreeGB
    $freed=[int64]0

    @($env:TEMP,(Join-Path $env:LOCALAPPDATA "Temp"),(Join-Path $env:WINDIR "Temp"))|
        Select-Object -Unique|ForEach-Object{if($_){$freed+=Remove-Old $_ 336}}

    $freed+=Remove-Old (Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportArchive") 720
    $after=Get-FreeGB

    Status "TEMP files older than 14d" "Cleanup attempted" "HEALTHY"
    Status "WER archives older than 30d" "Cleanup attempted" "HEALTHY"
    Status "Recycle Bin" "Preserved in scheduled/default maintenance" "INFO"
    Status "Approx. space recovered" ("{0:N2} GB" -f ($freed/1GB)) "HEALTHY"
    if($before -ne $null){Status "C: free before" "$before GB" "INFO"}
    if($after -ne $null){Status "C: free after" "$after GB" "INFO"}

    $script:Category="Windows"
    Section "WINDOWS COMPONENT STORE" "Removes superseded components without /ResetBase"
    Run-Logged "DISM.exe" @("/Online","/Cleanup-Image","/StartComponentCleanup") "DISM StartComponentCleanup"|Out-Null

    Show-Reboot
    Show-StorageHealth
    Show-Security

    $script:Category="Windows"
    Section "WINDOWS IMAGE" "Protected Windows component-store health"
    Run-Logged "DISM.exe" @("/Online","/Cleanup-Image","/CheckHealth") "DISM CheckHealth"|Out-Null

    Finish "Monthly Maintenance"
}

function AggressiveCleanup {
    New-RunContext
    Header "AGGRESSIVE CLEANUP"

    $script:Category="Cleanup"
    $before=Get-FreeGB
    $rbBefore=Get-RecycleBinSize

    Section "AGGRESSIVE CLEANUP" "7-day TEMP + 14-day WER + optional Windows Recycle Bin cleanup"
    Line "  Manual only."
    Line "  Preserves browser data, game data, shader caches, Downloads and Documents."
    Line ""
    Line "  Windows-native Recycle Bin handling is used."
    Line "  Age-based Recycle Bin deletion is not used because Windows does not expose"
    Line "  a reliable supported one-shot API for deleting only items older than N days."
    Line ""

    Line "  ELIGIBLE FOR CLEANUP"
    Line "  --------------------------------------------------------------"
    Line "  TEMP files older than 7 days"
    Line "  WER reports older than 14 days"
    Line ("  Recycle Bin currently               {0} item(s), approx {1}" -f $rbBefore.Items,(Format-Bytes $rbBefore.Bytes))
    Line ""
    Line "  TEMP and WER cleanup will run after CLEAN."
    if($rbBefore.Items -gt 0){
        Line "  Recycle Bin will be preserved unless you separately type EMPTY."
    }else{
        Line "  Recycle Bin is already empty."
    }
    Line ""

    $confirm=Read-Host "Type CLEAN to run Aggressive Cleanup, or press Enter to cancel"
    if($confirm -ne "CLEAN"){
        Line ""
        Line "  Aggressive Cleanup canceled. Nothing was deleted."
        Finish "Aggressive Cleanup"
        return
    }

    $emptyRecycle=$false
    if($rbBefore.Items -gt 0){
        Line ""
        Line "  OPTIONAL RECYCLE BIN CLEANUP"
        Line "  --------------------------------------------------------------"
        Line "  Windows will permanently empty the entire Recycle Bin."
        Line "  This includes recent items."
        $rbConfirm=Read-Host "Type EMPTY to include Recycle Bin cleanup, or press Enter to preserve it"
        if($rbConfirm -eq "EMPTY"){
            $emptyRecycle=$true
        }
    }

    $tempFreed=[int64]0
    @(
        $env:TEMP,
        (Join-Path $env:LOCALAPPDATA "Temp"),
        (Join-Path $env:WINDIR "Temp")
    ) |
    Select-Object -Unique |
    ForEach-Object {
        if($_){$tempFreed += Remove-Old $_ 168}
    }

    $werFreed=Remove-Old (Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportArchive") 336

    $rbResult=[PSCustomObject]@{
        Requested=$rbBefore.Items
        Deleted=0
        FreedBytes=0
        Success=$true
        Reason=""
    }

    if($emptyRecycle){
        $rbResult=Invoke-NativeRecycleBinEmpty -Confirmed
    }

    $after=Get-FreeGB
    $estimated=$tempFreed + $werFreed + [int64]$rbResult.FreedBytes
    $delta=if($before -ne $null -and $after -ne $null){
        [math]::Round($after-$before,2)
    }else{
        [math]::Round($estimated/1GB,2)
    }

    Line ""
    Line "  CLEANUP RESULTS"
    Line "  --------------------------------------------------------------"

    if($tempFreed -gt 0){
        Line ("  TEMP older than 7d                 {0} removed" -f (Format-Bytes $tempFreed))
    }else{
        Line "  TEMP older than 7d                 Nothing eligible"
    }

    if($werFreed -gt 0){
        Line ("  WER reports older than 14d         {0} removed" -f (Format-Bytes $werFreed))
    }else{
        Line "  WER reports older than 14d         Nothing eligible"
    }

    if($emptyRecycle){
        if($rbResult.Success){
            Line ("  Recycle Bin                         {0} item(s), {1} removed" -f $rbResult.Deleted,(Format-Bytes $rbResult.FreedBytes))
            Line "  Recycle Bin verification           PASSED"
        }else{
            Line ("  Recycle Bin                         Cleanup incomplete")
            Line ("  Recycle Bin verification           FAILED")
            $script:Warnings++
            Add-NextStep ("Recycle Bin cleanup failed: "+$rbResult.Reason)
        }
    }else{
        Line ("  Recycle Bin                         Preserved, {0} item(s)" -f $rbBefore.Items)
    }

    Line ""
    if($before -ne $null){Line ("  C: free space before                {0:N1} GB" -f $before)}
    if($after -ne $null){Line ("  C: free space after                 {0:N1} GB" -f $after)}
    Line ("  Storage gained                      {0:N2} GB" -f $delta)
    Line ""
    Line "  Preserved: browser data, game data, shader caches,"
    Line "             Downloads and Documents."

    Finish "Aggressive Cleanup"
}

function StorageReport {
    New-RunContext
    Header "STORAGE REPORT"

    $script:Category="Storage"
    Section "STORAGE USAGE" "Read-only view of common user folders"

    $items=@(
        @("Downloads",(Join-Path $env:USERPROFILE "Downloads")),
        @("Desktop",(Join-Path $env:USERPROFILE "Desktop")),
        @("Documents",(Join-Path $env:USERPROFILE "Documents")),
        @("Videos",(Join-Path $env:USERPROFILE "Videos")),
        @("User TEMP",$env:TEMP),
        @("Windows TEMP",(Join-Path $env:WINDIR "Temp"))
    )

    foreach($i in $items){
        $sum=[int64]0
        if(Test-Path $i[1]){
            $measured=(Get-ChildItem -LiteralPath $i[1] -Force -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
            if($null -ne $measured){$sum=[int64]$measured}
        }
        Status $i[0] (Format-Bytes $sum) "INFO"
    }

    Line ""
    Line "  Largest files under Downloads:"
    $dl=Join-Path $env:USERPROFILE "Downloads"
    if(Test-Path $dl){
        $largest=@(
            Get-ChildItem -LiteralPath $dl -File -Recurse -ErrorAction SilentlyContinue|
            Sort-Object Length -Descending|Select-Object -First 10
        )
        if($largest.Count -eq 0){
            Line "         > None found"
        }else{
            foreach($f in $largest){
                Line ("         > {0,-10} {1}" -f (Format-Bytes ([int64]$f.Length)),$f.FullName)
            }
        }
    }

    Line ""
    Line "  Largest top-level folders under the user profile:"
    Line "  Scanning folders... this may take a few minutes on large profiles."
    Line ""
    $profileFolders=@(
        Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @("AppData") -and
            -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        }
    )

    $folderSizes=@()
    foreach($folder in $profileFolders){
        $size=[int64]0
        try{
            $m=(Get-ChildItem -LiteralPath $folder.FullName -File -Recurse -Force -ErrorAction SilentlyContinue|
                Measure-Object Length -Sum).Sum
            if($null -ne $m){$size=[int64]$m}
        }catch{}
        $folderSizes += [PSCustomObject]@{Name=$folder.Name;Path=$folder.FullName;Bytes=$size}
    }

    Line "  Scan complete."
    Line ""

    $topFolders=@($folderSizes|Sort-Object Bytes -Descending|Select-Object -First 8)
    if($topFolders.Count -eq 0){
        Line "         > None found"
    }else{
        foreach($f in $topFolders){
            Line ("         > {0,-10} {1}" -f (Format-Bytes $f.Bytes),$f.Path)
        }
    }

    Line ""
    Line "  AppData and Windows junction/reparse-point folders are excluded from the"
    Line "  ranking to avoid duplicate or misleading storage totals."
    Line "  WinCare Toolkit does not delete anything from this report."

    Show-StorageHealth
    Finish "Storage Report"
}

function Show-NetworkConfiguration {
    $configs=@(Get-NetIPConfiguration -ErrorAction SilentlyContinue)

    $rows=@()
    foreach($cfg in $configs){
        $alias=[string]$cfg.InterfaceAlias
        if([string]::IsNullOrWhiteSpace($alias)){continue}

        $adapter=Get-NetAdapter -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue
        $status=if($adapter){[string]$adapter.Status}else{"Unknown"}

        $ipv4=@($cfg.IPv4Address | ForEach-Object {$_.IPAddress} | Where-Object {$_})
        $gateway=@($cfg.IPv4DefaultGateway | ForEach-Object {$_.NextHop} | Where-Object {$_})
        $dns=@(
            Get-DnsClientServerAddress -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            ForEach-Object {$_.ServerAddresses} |
            Where-Object {$_}
        )

        $rows += [PSCustomObject]@{
            Alias=$alias
            Status=$status
            IPv4=if($ipv4.Count){$ipv4 -join ", "}else{"None"}
            Gateway=if($gateway.Count){$gateway -join ", "}else{"None"}
            DNS=if($dns.Count){$dns -join ", "}else{"None"}
            Primary=($status -eq "Up" -and $gateway.Count -gt 0)
        }
    }

    $primary=@($rows | Where-Object {$_.Primary} | Sort-Object Alias)
    $other=@($rows | Where-Object {-not $_.Primary} | Sort-Object Alias)

    if($primary.Count -gt 0){
        Section "ACTIVE NETWORK" "Connected adapters with a default gateway"
        foreach($r in $primary){
            Line ("  {0}" -f $r.Alias)
            Line ("    Status                           {0}" -f $r.Status)
            Line ("    IPv4 Address                     {0}" -f $r.IPv4)
            Line ("    Default Gateway                  {0}" -f $r.Gateway)
            Line ("    DNS Servers                      {0}" -f $r.DNS)
            Line ""
        }
    }else{
        Section "ACTIVE NETWORK" "Connected adapters with a default gateway"
        Status "Active network" "None detected" "ATTENTION"
    }

    if($other.Count -gt 0){
        Section "OTHER ADAPTERS" "Inactive, virtual, tunnel, or secondary adapters"
        foreach($r in $other){
            $summary=$r.Status
            if($r.IPv4 -ne "None"){$summary += ", IPv4 "+$r.IPv4}
            Line ("  {0,-34} {1}" -f $r.Alias,$summary)
        }
    }
}

function NetworkTools {
    New-RunContext
    do{
        Header "NETWORK TROUBLESHOOTING"
        Line "  [1] Show network configuration"
        Line "  [2] Flush DNS cache"
        Line "  [3] Renew DHCP lease"
        Line "  [4] Reset Winsock, confirmation required"
        Line "  [5] Back"
        Line ""
        $c=Read-Host "Select"
        switch($c){
            "1"{
                $script:Category="Network"
                Show-NetworkConfiguration
                Read-Host "Press Enter"
            }
            "2"{
                $script:Category="Network"
                Section "FLUSH DNS"
                Clear-DnsClientCache
                Status "DNS cache" "Flushed" "HEALTHY" "Troubleshooting action, not a speed tweak"
                Read-Host "Press Enter"
            }
            "3"{
                $script:Category="Network"
                Section "RENEW DHCP"
                Line "  This requests a fresh DHCP lease for DHCP-enabled adapters."
                Line "  Brief network interruption is possible."
                Line ""
                $x=Read-Host "Type RENEW to continue, or press Enter to cancel"
                if($x -eq "RENEW"){
                    ipconfig /renew|Out-String|ForEach-Object{Line $_}
                    Status "DHCP lease" "Renew requested" "INFO"
                }else{
                    Status "DHCP lease" "Canceled" "INFO"
                }
                Read-Host "Press Enter"
            }
            "4"{
                $script:Category="Network"
                Section "WINSOCK RESET"
                Line "  Resets the Windows Winsock catalog."
                Line "  Use only for network troubleshooting. A restart is normally required."
                Line ""
                $x=Read-Host "Type RESET to continue, or press Enter to cancel"
                if($x -eq "RESET"){
                    netsh winsock reset|Out-String|ForEach-Object{Line $_}
                    Status "Winsock reset" "Completed" "ATTENTION" "Restart when convenient"
                }else{
                    Status "Winsock reset" "Canceled" "INFO"
                }
                Read-Host "Press Enter"
            }
        }
    }while($c -ne "5")
}

function Repair {
    New-RunContext
    Header "WINDOWS REPAIR"

    $script:Category="Windows"
    Section "WINDOWS REPAIR" "Diagnostics first. Repair commands remain opt-in."

    $scanCode=Run-Logged "DISM.exe" @("/Online","/Cleanup-Image","/ScanHealth") "DISM ScanHealth"

    if($scanCode -eq 0){
        Line ""
        Line "  ScanHealth completed successfully."
        Line "  RestoreHealth and SFC are optional unless Windows is showing corruption"
        Line "  or system-file problems."
    }else{
        Line ""
        Line "  ScanHealth did not complete successfully."
        Line "  Review the log before continuing with repair actions."
    }

    Line ""
    $x=Read-Host "Run RestoreHealth followed by SFC /scannow? (Y/N)"
    if($x -match "^[Yy]$"){
        $restoreCode=Run-Logged "DISM.exe" @("/Online","/Cleanup-Image","/RestoreHealth") "DISM RestoreHealth"
        if($restoreCode -eq 0){
            Run-Logged "sfc.exe" @("/scannow") "SFC scannow"|Out-Null
        }else{
            Status "SFC scannow" "Skipped" "ATTENTION" "RestoreHealth did not complete successfully"
            Add-NextStep "Resolve the DISM RestoreHealth error before running SFC again."
        }
    }else{
        Status "Repair actions" "Skipped by user" "INFO"
    }

    Finish "Windows Repair"
}

function Recycle {
    New-RunContext
    Header "EMPTY RECYCLE BIN"

    $script:Category="Cleanup"
    $before=Get-FreeGB
    $rbBefore=Get-RecycleBinSize

    Section "RECYCLE BIN" "Windows-native permanent cleanup"
    Line ("  Current contents                     {0} item(s), approx {1}" -f $rbBefore.Items,(Format-Bytes $rbBefore.Bytes))
    Line ""
    Line "  This permanently removes every item currently in the Recycle Bin."
    Line ""

    if($rbBefore.Items -eq 0){
        Line "  Recycle Bin is already empty."
        Finish "Recycle Bin Cleanup"
        return
    }

    $confirm=Read-Host "Type EMPTY to permanently clear the Recycle Bin, or press Enter to cancel"
    if($confirm -ne "EMPTY"){
        Line ""
        Line "  Recycle Bin cleanup canceled. Nothing was deleted."
        Finish "Recycle Bin Cleanup"
        return
    }

    $result=Invoke-NativeRecycleBinEmpty -Confirmed
    $after=Get-FreeGB
    $delta=if($before -ne $null -and $after -ne $null){[math]::Round($after-$before,2)}else{[math]::Round($result.FreedBytes/1GB,2)}

    Line ""
    Line "  CLEANUP RESULTS"
    Line "  --------------------------------------------------------------"

    if($result.Success){
        Line ("  Recycle Bin                         {0} item(s), {1} removed" -f $result.Deleted,(Format-Bytes $result.FreedBytes))
        Line "  Verification                        PASSED"
    }else{
        Line "  Recycle Bin                         Cleanup incomplete"
        Line "  Verification                        FAILED"
        $script:Warnings++
        Add-NextStep ("Recycle Bin cleanup failed: "+$result.Reason)
    }

    Line ""
    if($before -ne $null){Line ("  C: free space before                {0:N1} GB" -f $before)}
    if($after -ne $null){Line ("  C: free space after                 {0:N1} GB" -f $after)}
    Line ("  Storage gained                      {0:N2} GB" -f $delta)

    Finish "Recycle Bin Cleanup"
}

function SelfCheck {
    New-RunContext
    Header "TOOLKIT SELF CHECK"

    $script:Category="Diagnostics"
    Section "RUNTIME VALIDATION" "Checks command availability and safe read/write capabilities"

    $required=@(
        "Get-CimInstance",
        "Get-WinEvent",
        "Get-PnpDevice",
        "Get-MpComputerStatus",
        "Clear-RecycleBin",
        "Start-MpScan"
    )

    $missing=0
    foreach($cmd in $required){
        if(Get-Command $cmd -ErrorAction SilentlyContinue){
            Status $cmd "Available" "HEALTHY"
        }else{
            Status $cmd "Missing" "ATTENTION"
            $missing++
        }
    }

    Line ""
    Section "CAPABILITY TESTS" "Read-only tests plus temporary toolkit-file writes"

    try{
        $null=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        Status "CIM / WMI access" "Operational" "HEALTHY"
    }catch{
        Status "CIM / WMI access" "Failed" "ATTENTION" $_.Exception.Message
    }

    try{
        $null=Get-WinEvent -LogName System -MaxEvents 1 -ErrorAction Stop
        Status "Windows Event Log access" "Operational" "HEALTHY"
    }catch{
        Status "Windows Event Log access" "Failed" "ATTENTION" $_.Exception.Message
    }

    try{
        $null=Get-PnpDevice -PresentOnly -ErrorAction Stop | Select-Object -First 1
        Status "PnP device access" "Operational" "HEALTHY"
    }catch{
        Status "PnP device access" "Failed" "ATTENTION" $_.Exception.Message
    }

    try{
        $null=Get-MpComputerStatus -ErrorAction Stop
        Status "Defender status access" "Operational" "HEALTHY"
    }catch{
        Status "Defender status access" "Unavailable" "INFO" "Expected on some systems where Defender services are disabled"
    }

    foreach($pathInfo in @(
        @("Log directory",$LogDir),
        @("History directory",$HistoryDir)
    )){
        $label=$pathInfo[0]
        $path=$pathInfo[1]
        try{
            if(-not(Test-Path $path)){New-Item -ItemType Directory -Path $path -Force|Out-Null}
            $probe=Join-Path $path ("WinCare Toolkit_probe_"+[guid]::NewGuid().ToString("N")+".tmp")
            Set-Content -Path $probe -Value "WinCare Toolkit write test" -Encoding ASCII -ErrorAction Stop
            Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
            Status $label "Writable" "HEALTHY"
        }catch{
            Status $label "Write test failed" "ATTENTION" $_.Exception.Message
        }
    }

    if($missing -gt 0){
        Add-NextStep "$missing required Windows command(s) were not available."
    }

    Finish "Toolkit Self Check"
}

function Menu {
    do{
        Header ""
        Line "MAINTENANCE"
        Line "  [1] Monthly Maintenance        Safe cleanup + Windows health checks"
        Line ""
        Line "HEALTH & SECURITY"
        Line "  [2] System Health Audit        Full read-only health snapshot"
        Line "  [3] Security Check             Antivirus + firewall + Quick Scan"
        Line "  [4] Storage Report             Read-only storage breakdown"
        Line ""
        Line "TROUBLESHOOTING"
        Line "  [5] Network Troubleshooting    DNS, DHCP, Winsock tools"
        Line "  [6] Windows Repair             DISM + SFC workflow"
        Line ""
        Line "OPTIONAL"
        Line "  [7] Defender Full Scan         Only if Defender is active"
        Line "  [8] Empty Recycle Bin          Permanent deletion with confirmation"
        Line "  [9] Aggressive Cleanup         7-day TEMP + optional Recycle Bin"
        Line "  [10] Toolkit Self Check        Validate runtime requirements"
        Line ""
        Line "  [0] Exit"
        Line ""

        $c=Read-Host "Select"
        switch($c){
            "1"{Monthly;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "2"{Audit;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "3"{New-RunContext;Header "SECURITY CHECK";Show-Security -Quick;Finish "Security Check";if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "4"{StorageReport;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "5"{NetworkTools}
            "6"{Repair;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "7"{New-RunContext;Header "DEFENDER FULL SCAN";Show-Security -Full;Finish "Defender Full Scan";if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
             "8"{Recycle;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "9"{AggressiveCleanup;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
            "10"{SelfCheck;if(-not $NonInteractive){Read-Host "Press Enter to return to menu"}}
        }
    }while($c -ne "0")
}

switch($Mode){
    "Monthly"{Monthly}
    "Audit"{Audit}
    "Security"{New-RunContext;Header "SECURITY CHECK";Show-Security -Quick;Finish "Security Check"}
    "Storage"{StorageReport}
    "Network"{NetworkTools}
    "Repair"{Repair}
    "FullScan"{New-RunContext;Header "DEFENDER FULL SCAN";Show-Security -Full;Finish "Defender Full Scan"}
    "RecycleBin"{Recycle}
    "Aggressive"{AggressiveCleanup}
    "SelfCheck"{SelfCheck}
    default{Menu}
}
