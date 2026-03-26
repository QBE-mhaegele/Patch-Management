<#
.SYNOPSIS
    QB Energy - Phase 1 Patch Deployment
.DESCRIPTION
    Deploys Windows Updates to all Phase 1 machines sequentially.
    For each machine:
      - Searches, downloads and installs all available updates
      - Reboots on completion
      - Waits for machine to come back online
      - Verifies reboot success
      - Writes per-machine result to FILE4
    Generates a consolidated HTML report on completion.
.NOTES
    Runs on QBE-DEN-TSSH1 as mhaegele.admin
    Scheduled: Thursday after Patch Tuesday, 10:00 AM
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$InventoryShare  = '\\qbe-den-qnap\File4\Inventory',
    [string]$Phase1CSV       = '\\qbe-den-qnap\File4\Inventory\Phase1.csv',
    [string]$ExclusionFile   = 'C:\PatchManagement\Config\ExcludedMachines.txt',
    [string]$ReportOutputDir = '\\qbe-den-qnap\File4\Inventory\PatchManagement\Logs\PatchAutomation',
    [int]$RebootWaitMinutes  = 15,
    [int]$WinRMTimeoutSec    = 300
)

# ── Logging ──────────────────────────────────────────────────────────────────
$RunTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile      = Join-Path $ReportOutputDir "DeployResults-Phase1-$RunTimestamp.log"
$EventsFile   = Join-Path $ReportOutputDir "DeployEvents-Phase1-$RunTimestamp.jsonl"
if (-not (Test-Path $ReportOutputDir)) { New-Item $ReportOutputDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $Line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $LogFile -Value $Line
    $Color = switch ($Level) { 'ERROR' {'Red'} 'WARN' {'Yellow'} 'OK' {'Green'} default {'White'} }
    Write-Host $Line -ForegroundColor $Color
}

function Write-Event {
    param([string]$Machine, [string]$Event, [string]$Details = '')
    $Entry = [ordered]@{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Machine   = $Machine
        Event     = $Event
        Details   = $Details
    }
    ($Entry | ConvertTo-Json -Compress) | Add-Content -Path $EventsFile -Encoding UTF8
}

# ── Load machine list ─────────────────────────────────────────────────────────
$Exclusions = Get-Content $ExclusionFile -ErrorAction SilentlyContinue |
    Where-Object { $_ -and $_ -notmatch '^\s*#' } |
    ForEach-Object { ($_ -split '\s+')[0].Trim() }

$Machines = Import-Csv $Phase1CSV |
    Where-Object { $Exclusions -notcontains $_.ComputerName }

Write-Log "========================================" 'INFO'
Write-Log "QB Energy Phase 1 Patch Deployment" 'INFO'
Write-Log "========================================" 'INFO'
Write-Log "Machines: $($Machines.Count)  |  DryRun: $DryRun" 'INFO'
Write-Log "" 'INFO'
Write-Event 'SYSTEM' 'DeploymentStarted' "Machines:$($Machines.Count) DryRun:$($DryRun.IsPresent)"

# ── Windows Update scriptblock (runs on each target) ─────────────────────────
$UpdateScriptBlock = {
    param([bool]$DryRun)

    $Result = @{
        ComputerName   = $env:COMPUTERNAME
        StartTime      = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        UpdatesFound   = 0
        UpdatesInstalled = 0
        UpdatesFailed  = 0
        RebootRequired = $false
        Updates        = @()
        Errors         = @()
        DryRun         = $DryRun
    }

    try {
        $Session  = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()
        $Search   = $Searcher.Search("IsInstalled=0 AND Type='Software' AND IsHidden=0")
        $Result.UpdatesFound = $Search.Updates.Count

        if ($Search.Updates.Count -eq 0) {
            $Result.EndTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            return $Result | ConvertTo-Json -Depth 5
        }

        if (-not $DryRun) {
            # Download
            $Downloader = $Session.CreateUpdateDownloader()
            $Downloader.Updates = $Search.Updates
            $Downloader.Download() | Out-Null

            # Install
            $Installer = $Session.CreateUpdateInstaller()
            $Installer.Updates = $Search.Updates
            $InstallResult = $Installer.Install()
            $Result.RebootRequired = $InstallResult.RebootRequired

            for ($i = 0; $i -lt $Search.Updates.Count; $i++) {
                $Update = $Search.Updates.Item($i)
                $IR     = $InstallResult.GetUpdateResult($i)
                $Status = if ($IR.ResultCode -eq 2) { 'Installed' } else { 'Failed' }
                if ($IR.ResultCode -eq 2) { $Result.UpdatesInstalled++ } else { $Result.UpdatesFailed++ }
                $Result.Updates += @{
                    Title       = $Update.Title
                    KB          = if ($Update.KBArticleIDs.Count -gt 0) { 'KB' + $Update.KBArticleIDs.Item(0) } else { 'N/A' }
                    ResultCode  = $IR.ResultCode
                    Status      = $Status
                }
            }
        } else {
            # Dry run - just list what would be installed
            for ($i = 0; $i -lt $Search.Updates.Count; $i++) {
                $Update = $Search.Updates.Item($i)
                $Result.Updates += @{
                    Title  = $Update.Title
                    KB     = if ($Update.KBArticleIDs.Count -gt 0) { 'KB' + $Update.KBArticleIDs.Item(0) } else { 'N/A' }
                    Status = 'WouldInstall'
                }
            }
        }
    } catch {
        $Result.Errors += $_.Exception.Message
    }

    $Result.EndTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    return $Result | ConvertTo-Json -Depth 5
}

# ── Per-machine deployment ────────────────────────────────────────────────────
$AllResults = @()

foreach ($Machine in $Machines) {
    $Name = $Machine.ComputerName
    Write-Log "" 'INFO'
    Write-Log "--- $Name ---" 'INFO'

    $MachineResult = @{
        ComputerName     = $Name
        Reachable        = $false
        UpdateResult     = $null
        RebootInitiated  = $false
        RebootConfirmed  = $false
        OnlineAfterReboot = $false
        FinalStatus      = 'Unknown'
        Errors           = @()
    }

    # Connectivity check
    if (-not (Test-Connection -ComputerName $Name -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Log "$Name is offline - skipping" 'WARN'
        $MachineResult.FinalStatus = 'Offline'
        Write-Event $Name 'Offline'
        $AllResults += $MachineResult
        continue
    }
    $MachineResult.Reachable = $true

    # Run Windows Update
    Write-Log "Running Windows Update on $Name..." 'INFO'
    Write-Event $Name 'UpdatesStarted'
    try {
        $SessionOpt = New-PSSessionOption -OperationTimeout ($WinRMTimeoutSec * 1000) -OpenTimeout 15000
        $Job  = Invoke-Command -ComputerName $Name -SessionOption $SessionOpt `
                    -ScriptBlock $UpdateScriptBlock -ArgumentList $DryRun.IsPresent -AsJob -ErrorAction Stop
        $Done = Wait-Job $Job -Timeout $WinRMTimeoutSec
        if (-not $Done) {
            Stop-Job $Job; Remove-Job $Job -Force
            throw "Windows Update timed out after $WinRMTimeoutSec seconds"
        }
        $Raw = Receive-Job $Job
        Remove-Job $Job -Force -ErrorAction SilentlyContinue

        if ($Raw) {
            $UpdateResult = $Raw | ConvertFrom-Json
            $MachineResult.UpdateResult = $UpdateResult
            Write-Log "Updates found: $($UpdateResult.UpdatesFound)  Installed: $($UpdateResult.UpdatesInstalled)  Failed: $($UpdateResult.UpdatesFailed)" 'INFO'
            $UpdateResult.Updates | ForEach-Object { Write-Log "  [$($_.Status)] $($_.KB) - $($_.Title)" 'INFO' }
            Write-Event $Name 'UpdatesComplete' "Found:$($UpdateResult.UpdatesFound) Installed:$($UpdateResult.UpdatesInstalled) Failed:$($UpdateResult.UpdatesFailed)"
        }
    } catch {
        Write-Log "Update error on ${Name}: $_" 'ERROR'
        Write-Event $Name 'UpdateError' "$_"
        $MachineResult.Errors += $_.ToString()
        $MachineResult.FinalStatus = 'UpdateError'
        $AllResults += $MachineResult
        continue
    }

    # Reboot
    if ($DryRun) {
        Write-Log "[DRY RUN] Would reboot $Name" 'WARN'
        $MachineResult.FinalStatus = 'DryRun'
    } elseif ($Name -in @('QBE-DEN-ADTOOLS','QBE-DEN-AMTOOLS')) {
        # Dev/admin tools servers: skip auto-reboot - devs may be logged in
        Write-Log "${Name}: Skipping auto-reboot (devs may be logged in). Manual reboot required." 'WARN'
        $MachineResult.FinalStatus = 'PendingReboot-Manual'

        # Write a persistent alert file to the report directory
        $AlertMsg  = "ACTION REQUIRED: $Name was patched on $(Get-Date -Format 'yyyy-MM-dd HH:mm') and requires a reboot.`r`nPlease verify no developers are logged in, then reboot at your earliest convenience.`r`n`r`nRun: Restart-Computer -ComputerName $Name -Force"
        $AlertFile = Join-Path $ReportOutputDir "REBOOT-REQUIRED-${Name}-$RunTimestamp.txt"
        $AlertMsg | Out-File $AlertFile -Encoding UTF8
        Write-Log "Alert file written: $AlertFile" 'WARN'
        Write-Event $Name 'RebootManual' "AlertFile:$AlertFile"

        # Try to pop a message to mhaegele.admin's active session
        try {
            & msg.exe /server:$Name mhaegele.admin $AlertMsg 2>$null
        } catch {}
        try {
            & msg.exe /server:QBE-DEN-TSSH1 mhaegele.admin $AlertMsg 2>$null
        } catch {}
    } else {
        Write-Log "Initiating reboot on $Name..." 'INFO'
        try {
            $BootTimeBefore = Invoke-Command -ComputerName $Name -ScriptBlock {
                (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            } -ErrorAction Stop

            Restart-Computer -ComputerName $Name -Force -ErrorAction Stop
            $MachineResult.RebootInitiated = $true
            Write-Log "Reboot initiated. Waiting for $Name to go offline..." 'INFO'
            Write-Event $Name 'RebootTriggered'

            # Wait for machine to go offline (up to 3 min)
            $OfflineWait = 0
            do {
                Start-Sleep -Seconds 10
                $OfflineWait += 10
                $Offline = -not (Test-Connection -ComputerName $Name -Count 1 -Quiet -ErrorAction SilentlyContinue)
            } while (-not $Offline -and $OfflineWait -lt 180)

            Write-Log "Waiting up to $RebootWaitMinutes minutes for $Name to come back online..." 'INFO'
            $OnlineWait = 0
            $Online     = $false
            do {
                Start-Sleep -Seconds 20
                $OnlineWait += 20
                $Online = Test-Connection -ComputerName $Name -Count 1 -Quiet -ErrorAction SilentlyContinue
            } while (-not $Online -and $OnlineWait -lt ($RebootWaitMinutes * 60))

            if (-not $Online) {
                Write-Log "$Name did not come back within $RebootWaitMinutes minutes" 'ERROR'
                Write-Event $Name 'RebootTimeout' "DidNotReturnWithin:${RebootWaitMinutes}min"
                $MachineResult.FinalStatus = 'RebootTimeout'
                $AllResults += $MachineResult
                continue
            }

            $MachineResult.OnlineAfterReboot = $true
            Write-Log "$Name is back online. Verifying reboot..." 'INFO'

            # Give WinRM a moment to start
            Start-Sleep -Seconds 30

            # Verify new boot time is later than before
            try {
                $BootTimeAfter = Invoke-Command -ComputerName $Name -ScriptBlock {
                    (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                } -ErrorAction Stop

                if ($BootTimeAfter -gt $BootTimeBefore) {
                    $MachineResult.RebootConfirmed = $true
                    Write-Log "$Name reboot confirmed. Boot time: $BootTimeAfter" 'OK'
                    $MachineResult.FinalStatus = if ($MachineResult.UpdateResult.UpdatesFailed -gt 0) { 'PartialSuccess' } else { 'Success' }
                    Write-Event $Name 'RebootConfirmed' "BootTime:$($BootTimeAfter.ToString('yyyy-MM-dd HH:mm:ss'))"
                } else {
                    Write-Log "$Name boot time unchanged - reboot may not have completed" 'WARN'
                    Write-Event $Name 'RebootUnconfirmed' "BootTimeBefore:$($BootTimeBefore.ToString('yyyy-MM-dd HH:mm:ss'))"
                    $MachineResult.FinalStatus = 'RebootUnconfirmed'
                }
            } catch {
                Write-Log "Could not verify reboot on ${Name}: $_" 'WARN'
                $MachineResult.FinalStatus = 'RebootUnverified'
            }
        } catch {
            Write-Log "Reboot error on ${Name}: $_" 'ERROR'
            Write-Event $Name 'RebootError' "$_"
            $MachineResult.Errors += $_.ToString()
            $MachineResult.FinalStatus = 'RebootError'
        }
    }

    $AllResults += $MachineResult

    # Save per-machine result JSON
    $ResultFile = Join-Path $ReportOutputDir "DeployResult-${Name}-${RunTimestamp}.json"
    $MachineResult | ConvertTo-Json -Depth 6 | Out-File $ResultFile -Encoding UTF8
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Log "" 'INFO'
Write-Log "========================================" 'INFO'
Write-Log "Deployment Summary" 'INFO'
Write-Log "========================================" 'INFO'

$Success      = ($AllResults | Where-Object { $_.FinalStatus -eq 'Success' }).Count
$Partial      = ($AllResults | Where-Object { $_.FinalStatus -eq 'PartialSuccess' }).Count
$Failed       = ($AllResults | Where-Object { $_.FinalStatus -match 'Error|Timeout|Unconfirmed|Unverified' }).Count
$Offline      = ($AllResults | Where-Object { $_.FinalStatus -eq 'Offline' }).Count
$ManualReboot = ($AllResults | Where-Object { $_.FinalStatus -eq 'PendingReboot-Manual' }).Count
$TotalUpdates = ($AllResults | Where-Object { $_.UpdateResult } | ForEach-Object { $_.UpdateResult.UpdatesInstalled } | Measure-Object -Sum).Sum

Write-Log "Success:         $Success" 'OK'
Write-Log "Partial:         $Partial" 'WARN'
Write-Log "Manual Reboot:   $ManualReboot (ADTOOLS - action required)" 'WARN'
Write-Log "Failed:          $Failed" 'ERROR'
Write-Log "Offline:         $Offline" 'WARN'
Write-Log "Total updates installed: $TotalUpdates" 'INFO'

# ── HTML Report ───────────────────────────────────────────────────────────────
$ReportFile = Join-Path $ReportOutputDir "DeployReport-Phase1-$RunTimestamp.html"

$Rows = ''
foreach ($R in $AllResults) {
    $StatusColor = switch ($R.FinalStatus) {
        'Success'              { '#27ae60' }
        'PartialSuccess'       { '#f39c12' }
        'PendingReboot-Manual' { '#e67e22' }
        'Offline'              { '#95a5a6' }
        'DryRun'               { '#3498db' }
        default                { '#e74c3c' }
    }
    $Installed = if ($R.UpdateResult) { $R.UpdateResult.UpdatesInstalled } else { '-' }
    $Failed2   = if ($R.UpdateResult) { $R.UpdateResult.UpdatesFailed }    else { '-' }
    $Found     = if ($R.UpdateResult) { $R.UpdateResult.UpdatesFound }     else { '-' }

    $UpdateRows = ''
    if ($R.UpdateResult -and $R.UpdateResult.Updates) {
        foreach ($U in $R.UpdateResult.Updates) {
            $UColor = if ($U.Status -eq 'Installed') { '#27ae60' } elseif ($U.Status -eq 'Failed') { '#e74c3c' } else { '#3498db' }
            $UpdateRows += "<tr><td>$($U.KB)</td><td>$($U.Title)</td><td style='color:$UColor;font-weight:bold'>$($U.Status)</td></tr>"
        }
    }

    $UpdateTable = if ($UpdateRows) {
        "<table style='width:100%;font-size:0.85em;border-collapse:collapse;margin-top:8px'><thead><tr style='background:#34495e;color:white'><th style='padding:4px 8px'>KB</th><th style='padding:4px 8px'>Update</th><th style='padding:4px 8px'>Status</th></tr></thead><tbody>$UpdateRows</tbody></table>"
    } else { '<em style="color:#999">No updates</em>' }

    $Errors = if ($R.Errors) { "<p style='color:#e74c3c;font-size:0.85em'>" + ($R.Errors -join '<br>') + "</p>" } else { '' }

    $Rows += @"
<tr>
  <td style='padding:10px;font-weight:bold'>$($R.ComputerName)</td>
  <td style='padding:10px;color:$StatusColor;font-weight:bold'>$($R.FinalStatus)</td>
  <td style='padding:10px;text-align:center'>$Found</td>
  <td style='padding:10px;text-align:center'>$Installed</td>
  <td style='padding:10px;text-align:center'>$Failed2</td>
  <td style='padding:10px;text-align:center'>$(if($R.RebootConfirmed){'Yes'}elseif($R.RebootInitiated){'Initiated'}else{'-'})</td>
  <td style='padding:10px'>$UpdateTable$Errors</td>
</tr>
"@
}

$HTML = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='UTF-8'>
<title>QB Energy Phase 1 Patch Deployment Report</title>
<style>
  body { font-family: 'Segoe UI', sans-serif; background: #f5f5f5; margin: 20px; }
  .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
  h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
  .summary-grid { display: flex; gap: 15px; margin: 20px 0; flex-wrap: wrap; }
  .stat { background: #ecf0f1; border-radius: 6px; padding: 15px 25px; text-align: center; min-width: 120px; }
  .stat .num { font-size: 2em; font-weight: bold; }
  .stat .lbl { font-size: 0.85em; color: #666; margin-top: 4px; }
  .green { color: #27ae60; } .red { color: #e74c3c; } .orange { color: #f39c12; } .gray { color: #95a5a6; }
  table.main { width: 100%; border-collapse: collapse; margin-top: 20px; }
  table.main th { background: #2c3e50; color: white; padding: 12px; text-align: left; }
  table.main tr:nth-child(even) { background: #f9f9f9; }
  table.main td { vertical-align: top; border-bottom: 1px solid #eee; }
  .footer { margin-top: 30px; color: #999; font-size: 0.85em; border-top: 1px solid #eee; padding-top: 15px; }
</style>
</head>
<body>
<div class='container'>
  <h1>QB Energy - Phase 1 Patch Deployment Report</h1>
  <p><strong>Run:</strong> $(Get-Date -Format 'dddd, MMMM dd yyyy HH:mm') &nbsp;|&nbsp; <strong>Mode:</strong> $(if($DryRun){'DRY RUN'}else{'LIVE'}) &nbsp;|&nbsp; <strong>Machines:</strong> $($Machines.Count)</p>

  <div class='summary-grid'>
    <div class='stat'><div class='num green'>$Success</div><div class='lbl'>Success</div></div>
    <div class='stat'><div class='num orange'>$Partial</div><div class='lbl'>Partial</div></div>
    <div class='stat'><div class='num' style='color:#e67e22'>$ManualReboot</div><div class='lbl'>Reboot Required</div></div>
    <div class='stat'><div class='num red'>$Failed</div><div class='lbl'>Failed</div></div>
    <div class='stat'><div class='num gray'>$Offline</div><div class='lbl'>Offline</div></div>
    <div class='stat'><div class='num'>$TotalUpdates</div><div class='lbl'>Updates Installed</div></div>
  </div>

  <table class='main'>
    <thead>
      <tr>
        <th>Machine</th><th>Status</th><th>Found</th><th>Installed</th><th>Failed</th><th>Rebooted</th><th>Details</th>
      </tr>
    </thead>
    <tbody>$Rows</tbody>
  </table>

  <div class='footer'>QB Energy IT Infrastructure &bull; Phase 1 Deployment &bull; Log: $LogFile</div>
</div>
</body>
</html>
"@

$HTML | Out-File $ReportFile -Encoding UTF8
Write-Log "HTML report saved: $ReportFile" 'OK'
Write-Log "Deployment complete." 'OK'
Write-Event 'SYSTEM' 'DeploymentComplete' "Success:$Success Partial:$Partial ManualReboot:$ManualReboot Failed:$Failed Offline:$Offline TotalUpdates:$TotalUpdates"
