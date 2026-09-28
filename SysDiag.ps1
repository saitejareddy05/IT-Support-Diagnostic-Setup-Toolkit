<#
.SYNOPSIS
    System diagnostic report for Windows 10/11 (Part 1 of the IT Support Toolkit).

.DESCRIPTION
    Collects: OS version/build/edition, license status, hardware summary, disk space,
    file system type per drive (fsutil fsinfo volumeinfo), boot method (UEFI vs Legacy
    via bcdedit), installed apps, network configuration and the top 10 processes by
    memory. Then runs DISM, SFC and a read-only CHKDSK and captures their output.
    Everything is saved into one timestamped text report.

.PARAMETER OutDir
    Folder for the report. Default: ..\reports (next to /windows-scripts).

.PARAMETER SkipRepairs
    Skip DISM / SFC / CHKDSK (they can take 10-40 minutes). Handy for a quick report.

.EXAMPLE
    .\SysDiag.ps1
.EXAMPLE
    .\SysDiag.ps1 -SkipRepairs

.NOTES
    Must run elevated (Run as administrator). Read-only except DISM /RestoreHealth and
    SFC, which repair Windows system files if they find damage.
#>
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path $PSScriptRoot '..\reports'),
    [switch]$SkipRepairs
)

$ErrorActionPreference = 'Continue'

# ---- admin check -----------------------------------------------------------
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Run this script from an elevated PowerShell (Run as administrator).'
    exit 1
}

# ---- report file -----------------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$Report = Join-Path $OutDir "DiagReport_${env:COMPUTERNAME}_$stamp.txt"

# ---- helpers ---------------------------------------------------------------
function Write-Section([string]$Title) {
    Write-Output ''
    Write-Output ('=' * 78)
    Write-Output "  $Title"
    Write-Output ('=' * 78)
}

# Collects piped objects and prints them as a table (or list) at a fixed width so the
# text report is not truncated with "..." like the default console view.
function Out-Block {
    param([Parameter(ValueFromPipeline = $true)]$InputObject, [switch]$List)
    begin   { $items = @() }
    process { $items += $InputObject }
    end {
        if ($List) { $text = $items | Format-List  | Out-String -Width 200 }
        else       { $text = $items | Format-Table -AutoSize | Out-String -Width 200 }
        Write-Output $text
    }
}

$script:Summary = @()

# Runs a native command, cleans its output (SFC writes UTF-16 so raw capture is full of
# NUL characters; DISM/SFC print progress lines that just add noise) and records the
# exit code and duration.
function Invoke-Repair {
    param([string]$Title, [scriptblock]$Command, [switch]$Utf16)
    Write-Section $Title
    $sw   = [Diagnostics.Stopwatch]::StartNew()
    $prev = [Console]::OutputEncoding
    $code = $null
    try {
        if ($Utf16) { try { [Console]::OutputEncoding = [Text.Encoding]::Unicode } catch {} }
        $raw  = & $Command 2>&1
        $code = $LASTEXITCODE
    }
    finally { try { [Console]::OutputEncoding = $prev } catch {} }

    $raw | ForEach-Object { ("$_" -replace "`0", '') -replace "`r", '' } |
        Where-Object {
            $_.Trim() -ne '' -and
            $_ -notmatch '^\s*\[[=\s\d\.%]+\]\s*$' -and
            $_ -notmatch 'Verification \d{1,2}% complete'
        } | ForEach-Object { Write-Output $_ }

    $sw.Stop()
    Write-Output ('--> Exit code: {0}    Duration: {1:hh\:mm\:ss}' -f $code, $sw.Elapsed)
    $script:Summary += [pscustomobject]@{ Step = $Title; ExitCode = $code; Duration = $sw.Elapsed.ToString('hh\:mm\:ss') }
}

# ============================================================================
Start-Transcript -Path $Report -Force | Out-Null
try {
    Write-Output 'IT SUPPORT TOOLKIT - SYSTEM DIAGNOSTIC REPORT'
    Write-Output "Computer : $env:COMPUTERNAME"
    Write-Output "User     : $env:USERDOMAIN\$env:USERNAME"
    Write-Output "Date     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "Script   : $PSCommandPath"
    Write-Output "PS ver   : $($PSVersionTable.PSVersion)"

    # ---- 1. OS -------------------------------------------------------------
    Write-Section '1. OPERATING SYSTEM'
    $os = Get-CimInstance Win32_OperatingSystem
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    [pscustomobject]@{
        Caption      = $os.Caption
        EditionID    = $cv.EditionID
        Version      = $(if ($cv.DisplayVersion) { $cv.DisplayVersion } else { $cv.ReleaseId })
        Build        = "$($os.BuildNumber).$($cv.UBR)"
        Architecture = $os.OSArchitecture
        InstallDate  = $os.InstallDate
        LastBoot     = $os.LastBootUpTime
    } | Out-Block -List

    # ---- 2. License --------------------------------------------------------
    Write-Section '2. LICENSE / ACTIVATION'
    $statusMap = @{ 0 = 'Unlicensed'; 1 = 'Licensed'; 2 = 'Out-of-box grace'; 3 = 'Out-of-tolerance grace';
                    4 = 'Non-genuine grace'; 5 = 'Notification'; 6 = 'Extended grace' }
    Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" |
        Select-Object Name, Description, PartialProductKey,
            @{ n = 'LicenseStatus'; e = { "$($_.LicenseStatus) ($($statusMap[[int]$_.LicenseStatus]))" } } |
        Out-Block -List
    Write-Output 'slmgr /dli:'
    cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli
    Write-Output 'slmgr /xpr:'
    cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr

    # ---- 3. Hardware -------------------------------------------------------
    Write-Section '3. HARDWARE SUMMARY (reused by the app-requirements check in Part 5)'
    $cs  = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join '; '
    [pscustomobject]@{
        Manufacturer      = $cs.Manufacturer
        Model             = $cs.Model
        CPU               = $cpu.Name.Trim()
        Cores             = $cpu.NumberOfCores
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
        MaxClockGHz       = [math]::Round($cpu.MaxClockSpeed / 1000, 2)
        RAM_GB            = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        GPU               = $gpu
    } | Out-Block -List

    # ---- 4. Disk space -----------------------------------------------------
    Write-Section '4. DISK SPACE (fixed drives)'
    $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'
    $disks | Select-Object DeviceID, VolumeName,
        @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } },
        @{ n = 'FreeGB'; e = { [math]::Round($_.FreeSpace / 1GB, 1) } },
        @{ n = 'UsedPct'; e = { if ($_.Size) { [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 1) } } } |
        Out-Block
    foreach ($d in $disks) {
        if ($d.Size -and (($d.FreeSpace / $d.Size) -lt 0.15)) {
            Write-Output "WARNING: $($d.DeviceID) has less than 15% free space."
        }
    }

    # ---- 5. File system per drive -----------------------------------------
    Write-Section '5. FILE SYSTEM TYPE PER DRIVE (fsutil fsinfo volumeinfo)'
    fsutil fsinfo drives
    foreach ($d in (Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -in 2, 3 })) {
        Write-Output ''
        Write-Output "--- $($d.DeviceID)\ ---"
        $out = fsutil fsinfo volumeinfo "$($d.DeviceID)\" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $out | Select-String 'Volume Name|Volume Serial Number|File System Name|Maximum Component Length|Case' |
                ForEach-Object { $_.Line }
        } else {
            Write-Output "  (could not read: $($out -join ' '))"
        }
    }
    Write-Output ''
    Write-Output 'Cross-check with Get-Volume:'
    Get-Volume | Where-Object DriveLetter |
        Select-Object DriveLetter, FileSystemLabel, FileSystem, DriveType, HealthStatus,
            @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } } | Out-Block

    # ---- 6. Boot method ----------------------------------------------------
    Write-Section '6. BOOT METHOD (UEFI vs Legacy BIOS)'
    $bcd      = bcdedit /enum '{current}' 2>&1
    $bcd | ForEach-Object { Write-Output "$_" }
    $pathLine = $bcd | Select-String -Pattern '^\s*path\s+(\S+)' | Select-Object -First 1
    $winload  = if ($pathLine) { $pathLine.Matches[0].Groups[1].Value } else { $null }
    $mode     = if ($winload -match 'winload\.efi') { 'UEFI' } elseif ($winload -match 'winload\.exe') { 'Legacy BIOS' } else { 'Unknown' }
    Write-Output ''
    Write-Output "bcdedit boot loader path : $winload"
    Write-Output "==> BOOT MODE            : $mode"
    try   { $fwt = (Get-ComputerInfo -Property BiosFirmwareType).BiosFirmwareType } catch { $fwt = 'n/a' }
    Write-Output "Get-ComputerInfo BiosFirmwareType : $fwt"
    try   { Write-Output "Secure Boot enabled               : $(Confirm-SecureBootUEFI)" }
    catch { Write-Output "Secure Boot                       : not available (Legacy BIOS or unsupported)" }
    Write-Output 'Partition styles (GPT normally = UEFI, MBR normally = Legacy):'
    Get-Disk | Select-Object Number, FriendlyName, PartitionStyle,
        @{ n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } } | Out-Block
    Write-Output "Manual cross-check: run msinfo32 and read the 'BIOS Mode' line."

    # ---- 7. Installed apps -------------------------------------------------
    Write-Section '7. INSTALLED APPLICATIONS'
    $paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
             'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $apps = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher |
        Sort-Object DisplayName -Unique
    Write-Output "Desktop applications found: $(@($apps).Count)"
    $apps | Out-Block
    Write-Output 'Microsoft Store (AppX) packages for the current user (frameworks excluded):'
    Get-AppxPackage | Where-Object { -not $_.IsFramework } |
        Select-Object Name, Version | Sort-Object Name | Out-Block

    # ---- 8. Network --------------------------------------------------------
    Write-Section '8. NETWORK CONFIGURATION'
    ipconfig /all
    Write-Output 'Adapters:'
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress | Out-Block
    Write-Output 'DNS servers (IPv4):'
    Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } |
        Select-Object InterfaceAlias, @{ n = 'DnsServers'; e = { $_.ServerAddresses -join ', ' } } | Out-Block
    Write-Output 'Default route(s):'
    $routes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric
    $routes | Select-Object InterfaceAlias, NextHop, RouteMetric | Out-Block
    Write-Output 'Quick connectivity checks:'
    $gw = ($routes | Select-Object -First 1).NextHop
    if ($gw) { Write-Output ("  Ping gateway {0,-15}: {1}" -f $gw, (Test-Connection $gw -Count 2 -Quiet)) }
    Write-Output ("  Ping 1.1.1.1 (internet)  : {0}" -f (Test-Connection 1.1.1.1 -Count 2 -Quiet))
    try {
        $dns = Resolve-DnsName microsoft.com -Type A -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1
        Write-Output "  DNS lookup microsoft.com : OK ($($dns.IPAddress))"
    } catch { Write-Output '  DNS lookup microsoft.com : FAILED' }

    # ---- 9. Top 10 processes ----------------------------------------------
    Write-Section '9. TOP 10 PROCESSES BY MEMORY (working set)'
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id,
        @{ n = 'WorkingSet_MB'; e = { [math]::Round($_.WorkingSet64 / 1MB, 1) } },
        @{ n = 'Private_MB';    e = { [math]::Round($_.PrivateMemorySize64 / 1MB, 1) } },
        @{ n = 'CPU_sec';       e = { [math]::Round($_.CPU, 1) } } | Out-Block

    # ---- 10. Repair tools --------------------------------------------------
    if ($SkipRepairs) {
        Write-Section '10. REPAIR TOOLS'
        Write-Output 'Skipped (-SkipRepairs).'
    }
    else {
        Write-Output ''
        Write-Output 'Running repair tools. This can take 10-40 minutes; leave the window open.'
        # DISM first: it repairs the component store that SFC copies good files from.
        Invoke-Repair '10a. DISM /Online /Cleanup-Image /RestoreHealth' { DISM /Online /Cleanup-Image /RestoreHealth }
        Invoke-Repair '10b. SFC /SCANNOW'                                 { sfc /scannow } -Utf16
        Invoke-Repair '10c. CHKDSK (read-only scan of the system drive)'  { chkdsk $env:SystemDrive }

        Write-Section 'REPAIR SUMMARY'
        $script:Summary | Out-Block
        Write-Output 'How to read the results:'
        Write-Output '  DISM  exit 0 = success.'
        Write-Output '  SFC   read the text: "did not find any integrity violations" = clean; "repaired them" = fixed.'
        Write-Output '        Details: findstr /c:"[SR]" %windir%\Logs\CBS\CBS.log   (DISM log: %windir%\Logs\DISM\dism.log)'
        Write-Output '  CHKDSK exit 0 = no errors, 1 = errors fixed, 2 = cleanup needed, 3 = could not check / errors found.'
        Write-Output '         Without /f this scan is read-only; it never changes the disk.'
    }

    Write-Output ''
    Write-Output 'End of report.'
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "`nReport saved to: $Report" -ForegroundColor Green
}
