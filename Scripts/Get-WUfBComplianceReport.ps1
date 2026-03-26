<#
.SYNOPSIS
    Windows Update for Business - Compliance Report Generator
    
.DESCRIPTION
    Reads update logs from central share and generates compliance reports
    including CSV exports and HTML dashboards.
    
    Run this on your patch management server on a schedule (e.g., daily at 6 AM).
    
.PARAMETER LogShare
    Path to the central update logs share
    
.PARAMETER OutputPath
    Path for generated reports
    
.PARAMETER StaleThresholdHours
    Hours after which a workstation is considered "stale" (not reporting)
    
.PARAMETER SendEmail
    Send email summary to administrators
    
.PARAMETER EmailTo
    Email recipient(s) for the summary report

.EXAMPLE
    .\Get-WUfBComplianceReport.ps1
    
.EXAMPLE
    .\Get-WUfBComplianceReport.ps1 -SendEmail -EmailTo "itadmin@qb-energy.com"
    
.EXAMPLE
    .\Get-WUfBComplianceReport.ps1 -StaleThresholdHours 72 -OutputPath "D:\Reports\WUfB"

.NOTES
    Author: QB Energy IT Infrastructure
    Version: 1.0
    Date: February 2026
#>

[CmdletBinding()]
param(
    [string]$LogShare = "\\qbe-den-qnap\File4\Inventory\Logs",
    [string]$OutputPath = "C:\PatchManagement\Reports\WUfB",
    [int]$StaleThresholdHours = 48,
    [switch]$SendEmail,
    [string]$EmailTo = "itadmin@qb-energy.com",
    [string]$EmailFrom = "patchmanagement@qb-energy.com",
    [string]$SmtpServer = "smtp-relay.qb-energy.com"
)

# ============================================================
# INITIALIZATION
# ============================================================

$ScriptStartTime = Get-Date

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Windows Update for Business - Compliance Report Generator       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Start Time: $($ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "Log Share: $LogShare" -ForegroundColor Gray
Write-Host "Output Path: $OutputPath" -ForegroundColor Gray
Write-Host "Stale Threshold: $StaleThresholdHours hours" -ForegroundColor Gray
Write-Host ""

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Yellow
}

# Verify log share is accessible
if (-not (Test-Path $LogShare -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Log share not accessible: $LogShare" -ForegroundColor Red
    exit 1
}

# ============================================================
# COLLECT DATA
# ============================================================

Write-Host "Collecting workstation data..." -ForegroundColor Yellow

# Get all workstation status files
$StatusFiles = Get-ChildItem -Path $LogShare -Filter "*_UpdateStatus.json" -ErrorAction SilentlyContinue

if ($StatusFiles.Count -eq 0) {
    Write-Host "WARNING: No status files found in $LogShare" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($StatusFiles.Count) workstation status file(s)" -ForegroundColor Green

$AllWorkstations = @()
$StaleCount = 0
$RebootPendingCount = 0
$UpdatesPendingCount = 0
$FailedUpdatesCount = 0
$CriticalPendingCount = 0

foreach ($File in $StatusFiles) {
    try {
        $Data = Get-Content $File.FullName -Raw | ConvertFrom-Json
        
        $LastReport = [DateTime]::Parse($Data.ComputerInfo.Timestamp)
        $HoursSinceReport = [Math]::Round(((Get-Date) - $LastReport).TotalHours, 1)
        $IsStale = $HoursSinceReport -gt $StaleThresholdHours
        
        if ($IsStale) { $StaleCount++ }
        if ($Data.UpdateStatus.RebootPending) { $RebootPendingCount++ }
        if ($Data.UpdateStatus.PendingUpdateCount -gt 0) { $UpdatesPendingCount++ }
        if ($Data.UpdateStatus.FailedLast30Days -gt 0) { $FailedUpdatesCount++ }
        
        # Check for critical pending updates
        $CriticalPending = ($Data.PendingUpdates | Where-Object { $_.Severity -eq "Critical" }).Count
        if ($CriticalPending -gt 0) { $CriticalPendingCount++ }
        
        # Determine overall status
        $Status = "Compliant"
        if ($IsStale) { $Status = "Stale" }
        elseif ($CriticalPending -gt 0) { $Status = "CriticalPending" }
        elseif ($Data.UpdateStatus.RebootPending) { $Status = "RebootPending" }
        elseif ($Data.UpdateStatus.PendingUpdateCount -gt 0) { $Status = "UpdatesPending" }
        
        $AllWorkstations += [PSCustomObject]@{
            ComputerName = $Data.ComputerInfo.ComputerName
            LastReport = $Data.ComputerInfo.Timestamp
            HoursSinceReport = $HoursSinceReport
            IsStale = $IsStale
            IPAddress = $Data.ComputerInfo.IPAddress
            OSVersion = $Data.ComputerInfo.OSVersion
            OSBuild = $Data.ComputerInfo.OSBuild
            Model = $Data.ComputerInfo.Model
            RebootPending = $Data.UpdateStatus.RebootPending
            RebootReasons = ($Data.UpdateStatus.RebootReasons -join ", ")
            PendingUpdates = $Data.UpdateStatus.PendingUpdateCount
            CriticalPending = $CriticalPending
            InstalledLast30Days = $Data.UpdateStatus.InstalledLast30Days
            FailedLast30Days = $Data.UpdateStatus.FailedLast30Days
            LastCheckTime = $Data.UpdateStatus.LastCheckTime
            LastInstallTime = $Data.UpdateStatus.LastInstallTime
            WUService = $Data.UpdateStatus.WindowsUpdateService
            DefenderSigDate = $Data.DefenderStatus.AntivirusSignatureLastUpdated
            DefenderSigVersion = $Data.DefenderStatus.AntivirusSignatureVersion
            Status = $Status
        }
    } catch {
        Write-Host "WARNING: Failed to parse $($File.Name): $_" -ForegroundColor Yellow
    }
}

# ============================================================
# GENERATE SUMMARY
# ============================================================

$CompliantCount = ($AllWorkstations | Where-Object { $_.Status -eq 'Compliant' }).Count
$CompliancePercentage = if ($AllWorkstations.Count -gt 0) { [Math]::Round(($CompliantCount / $AllWorkstations.Count) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  COMPLIANCE SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Workstations:       $($AllWorkstations.Count)" -ForegroundColor White
Write-Host "  ─────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "  ✓ Compliant:              $CompliantCount ($CompliancePercentage%)" -ForegroundColor Green
Write-Host "  ⚠ Updates Pending:        $UpdatesPendingCount" -ForegroundColor Yellow
Write-Host "  ⚠ Reboot Pending:         $RebootPendingCount" -ForegroundColor Yellow
Write-Host "  ✗ Critical Pending:       $CriticalPendingCount" -ForegroundColor Red
Write-Host "  ✗ Failed Updates:         $FailedUpdatesCount" -ForegroundColor Red
Write-Host "  ○ Stale (>$StaleThresholdHours hrs):        $StaleCount" -ForegroundColor Gray
Write-Host ""

# ============================================================
# EXPORT REPORTS
# ============================================================

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DateStamp = Get-Date -Format "yyyy-MM-dd"

Write-Host "Generating reports..." -ForegroundColor Yellow

# Full Report CSV
$FullReportPath = Join-Path $OutputPath "WUfB-FullReport-$Timestamp.csv"
$AllWorkstations | Sort-Object Status, ComputerName | Export-Csv -Path $FullReportPath -NoTypeInformation
Write-Host "  Full Report: $FullReportPath" -ForegroundColor Gray

# Latest Report (overwrites daily)
$LatestReportPath = Join-Path $OutputPath "WUfB-LatestReport.csv"
$AllWorkstations | Sort-Object Status, ComputerName | Export-Csv -Path $LatestReportPath -NoTypeInformation

# Non-Compliant Report
$NonCompliant = $AllWorkstations | Where-Object { $_.Status -ne 'Compliant' }
if ($NonCompliant.Count -gt 0) {
    $NonCompliantPath = Join-Path $OutputPath "WUfB-NonCompliant-$Timestamp.csv"
    $NonCompliant | Sort-Object Status, ComputerName | Export-Csv -Path $NonCompliantPath -NoTypeInformation
    Write-Host "  Non-Compliant: $NonCompliantPath" -ForegroundColor Gray
}

# Critical Pending Report
$CriticalPending = $AllWorkstations | Where-Object { $_.CriticalPending -gt 0 }
if ($CriticalPending.Count -gt 0) {
    $CriticalPath = Join-Path $OutputPath "WUfB-CriticalPending-$Timestamp.csv"
    $CriticalPending | Sort-Object CriticalPending -Descending | Export-Csv -Path $CriticalPath -NoTypeInformation
    Write-Host "  Critical Pending: $CriticalPath" -ForegroundColor Gray
}

# Reboot Pending Report
$RebootPending = $AllWorkstations | Where-Object { $_.RebootPending -eq $true }
if ($RebootPending.Count -gt 0) {
    $RebootPath = Join-Path $OutputPath "WUfB-RebootPending-$Timestamp.csv"
    $RebootPending | Sort-Object ComputerName | Export-Csv -Path $RebootPath -NoTypeInformation
    Write-Host "  Reboot Pending: $RebootPath" -ForegroundColor Gray
}

# Stale/Offline Report
$StaleWorkstations = $AllWorkstations | Where-Object { $_.IsStale -eq $true }
if ($StaleWorkstations.Count -gt 0) {
    $StalePath = Join-Path $OutputPath "WUfB-Stale-$Timestamp.csv"
    $StaleWorkstations | Sort-Object HoursSinceReport -Descending | Export-Csv -Path $StalePath -NoTypeInformation
    Write-Host "  Stale/Offline: $StalePath" -ForegroundColor Gray
}

# ============================================================
# HTML DASHBOARD
# ============================================================

$HtmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>WUfB Compliance Dashboard - $DateStamp</title>
    <meta charset="UTF-8">
    <style>
        * { box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: #f0f2f5; 
        }
        .header { 
            background: linear-gradient(135deg, #1a5490, #2980b9); 
            color: white; 
            padding: 25px 30px; 
            border-radius: 12px; 
            margin-bottom: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 { margin: 0 0 5px 0; font-size: 28px; }
        .header p { margin: 0; opacity: 0.9; font-size: 14px; }
        
        .summary { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); 
            gap: 20px; 
            margin-bottom: 25px; 
        }
        .card { 
            background: white; 
            padding: 20px; 
            border-radius: 12px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.08);
            text-align: center;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .card h3 { 
            margin: 0 0 10px 0; 
            color: #666; 
            font-size: 12px; 
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .card .value { 
            font-size: 42px; 
            font-weight: bold; 
            line-height: 1;
        }
        .card .subtitle {
            font-size: 12px;
            color: #888;
            margin-top: 5px;
        }
        .compliant { color: #27ae60; }
        .warning { color: #f39c12; }
        .critical { color: #e74c3c; }
        .neutral { color: #7f8c8d; }
        
        .compliance-bar {
            background: #ecf0f1;
            border-radius: 10px;
            height: 20px;
            margin: 20px 0;
            overflow: hidden;
        }
        .compliance-fill {
            background: linear-gradient(90deg, #27ae60, #2ecc71);
            height: 100%;
            transition: width 0.5s ease;
        }
        
        .section { margin-bottom: 25px; }
        .section h2 { 
            color: #2c3e50; 
            margin: 0 0 15px 0;
            font-size: 18px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        table { 
            width: 100%; 
            border-collapse: collapse; 
            background: white; 
            border-radius: 12px; 
            overflow: hidden; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.08); 
        }
        th { 
            background: #34495e; 
            color: white; 
            padding: 14px 12px; 
            text-align: left; 
            font-size: 13px;
            font-weight: 600;
        }
        td { 
            padding: 12px; 
            border-bottom: 1px solid #eee; 
            font-size: 13px;
        }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: #f8f9fa; }
        
        .status-badge {
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .status-compliant { background: #d4edda; color: #155724; }
        .status-pending { background: #fff3cd; color: #856404; }
        .status-reboot { background: #ffeaa7; color: #6c5ce7; }
        .status-critical { background: #f8d7da; color: #721c24; }
        .status-stale { background: #e2e3e5; color: #383d41; }
        
        .footer {
            text-align: center;
            padding: 20px;
            color: #888;
            font-size: 12px;
        }
        
        @media print {
            body { background: white; }
            .card { box-shadow: none; border: 1px solid #ddd; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔄 Windows Update for Business - Compliance Dashboard</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | QB Energy IT Infrastructure</p>
    </div>
    
    <div class="summary">
        <div class="card">
            <h3>Total Workstations</h3>
            <div class="value neutral">$($AllWorkstations.Count)</div>
            <div class="subtitle">Reporting</div>
        </div>
        <div class="card">
            <h3>Compliant</h3>
            <div class="value compliant">$CompliantCount</div>
            <div class="subtitle">$CompliancePercentage% compliance</div>
        </div>
        <div class="card">
            <h3>Updates Pending</h3>
            <div class="value warning">$UpdatesPendingCount</div>
            <div class="subtitle">Need attention</div>
        </div>
        <div class="card">
            <h3>Reboot Pending</h3>
            <div class="value warning">$RebootPendingCount</div>
            <div class="subtitle">Awaiting restart</div>
        </div>
        <div class="card">
            <h3>Critical Pending</h3>
            <div class="value critical">$CriticalPendingCount</div>
            <div class="subtitle">Security updates</div>
        </div>
        <div class="card">
            <h3>Stale</h3>
            <div class="value neutral">$StaleCount</div>
            <div class="subtitle">&gt;$StaleThresholdHours hours offline</div>
        </div>
    </div>
    
    <div class="compliance-bar">
        <div class="compliance-fill" style="width: $CompliancePercentage%;"></div>
    </div>
    
    <div class="section">
        <h2>📋 All Workstations</h2>
        <table>
            <tr>
                <th>Computer</th>
                <th>Status</th>
                <th>OS Build</th>
                <th>Pending</th>
                <th>Critical</th>
                <th>Installed (30d)</th>
                <th>Last Report</th>
                <th>WU Service</th>
            </tr>
            $($AllWorkstations | Sort-Object @{Expression={
                switch ($_.Status) {
                    'CriticalPending' { 1 }
                    'RebootPending' { 2 }
                    'UpdatesPending' { 3 }
                    'Stale' { 4 }
                    'Compliant' { 5 }
                    default { 6 }
                }
            }}, ComputerName | ForEach-Object {
                $StatusClass = switch ($_.Status) {
                    'Compliant' { 'status-compliant' }
                    'UpdatesPending' { 'status-pending' }
                    'RebootPending' { 'status-reboot' }
                    'CriticalPending' { 'status-critical' }
                    'Stale' { 'status-stale' }
                    default { 'status-pending' }
                }
                $StatusIcon = switch ($_.Status) {
                    'Compliant' { '✓' }
                    'UpdatesPending' { '⏳' }
                    'RebootPending' { '🔄' }
                    'CriticalPending' { '⚠️' }
                    'Stale' { '○' }
                    default { '?' }
                }
                "<tr>
                    <td><strong>$($_.ComputerName)</strong></td>
                    <td><span class='status-badge $StatusClass'>$StatusIcon $($_.Status)</span></td>
                    <td>$($_.OSBuild)</td>
                    <td>$($_.PendingUpdates)</td>
                    <td>$(if ($_.CriticalPending -gt 0) { "<strong style='color:#e74c3c'>$($_.CriticalPending)</strong>" } else { $_.CriticalPending })</td>
                    <td>$($_.InstalledLast30Days)</td>
                    <td>$($_.LastReport)</td>
                    <td>$($_.WUService)</td>
                </tr>"
            })
        </table>
    </div>
    
    <div class="footer">
        <p>Report generated by QB Energy Patch Management System | Windows Update for Business</p>
        <p>Processing time: $([Math]::Round(((Get-Date) - $ScriptStartTime).TotalSeconds, 2)) seconds</p>
    </div>
</body>
</html>
"@

$HtmlPath = Join-Path $OutputPath "WUfB-Dashboard-$Timestamp.html"
$HtmlReport | Out-File $HtmlPath -Encoding UTF8
Write-Host "  HTML Dashboard: $HtmlPath" -ForegroundColor Gray

# Latest dashboard (overwrites)
$LatestHtmlPath = Join-Path $OutputPath "WUfB-Dashboard-Latest.html"
$HtmlReport | Out-File $LatestHtmlPath -Encoding UTF8

# ============================================================
# EMAIL REPORT (Optional)
# ============================================================

if ($SendEmail) {
    Write-Host ""
    Write-Host "Sending email report..." -ForegroundColor Yellow
    
    $EmailBody = @"
<html>
<body style="font-family: 'Segoe UI', Arial, sans-serif;">
<h2 style="color: #2980b9;">Windows Update for Business - Daily Compliance Report</h2>
<p><strong>Report Date:</strong> $DateStamp</p>

<h3>Summary</h3>
<table style="border-collapse: collapse; width: 400px;">
    <tr style="background: #ecf0f1;"><td style="padding: 8px;">Total Workstations</td><td style="padding: 8px; text-align: right;"><strong>$($AllWorkstations.Count)</strong></td></tr>
    <tr><td style="padding: 8px;">✓ Compliant</td><td style="padding: 8px; text-align: right; color: #27ae60;"><strong>$CompliantCount ($CompliancePercentage%)</strong></td></tr>
    <tr style="background: #ecf0f1;"><td style="padding: 8px;">⏳ Updates Pending</td><td style="padding: 8px; text-align: right; color: #f39c12;"><strong>$UpdatesPendingCount</strong></td></tr>
    <tr><td style="padding: 8px;">🔄 Reboot Pending</td><td style="padding: 8px; text-align: right; color: #f39c12;"><strong>$RebootPendingCount</strong></td></tr>
    <tr style="background: #ecf0f1;"><td style="padding: 8px;">⚠️ Critical Pending</td><td style="padding: 8px; text-align: right; color: #e74c3c;"><strong>$CriticalPendingCount</strong></td></tr>
    <tr><td style="padding: 8px;">○ Stale (>$StaleThresholdHours hrs)</td><td style="padding: 8px; text-align: right; color: #7f8c8d;"><strong>$StaleCount</strong></td></tr>
</table>

$(if ($CriticalPendingCount -gt 0) {
    "<h3 style='color: #e74c3c;'>⚠️ Workstations with Critical Updates Pending</h3>
    <ul>
    $($CriticalPending | ForEach-Object { "<li><strong>$($_.ComputerName)</strong> - $($_.CriticalPending) critical update(s)</li>" })
    </ul>"
})

$(if ($StaleCount -gt 0) {
    "<h3 style='color: #7f8c8d;'>Stale Workstations (Not Reporting)</h3>
    <ul>
    $($StaleWorkstations | Select-Object -First 10 | ForEach-Object { "<li><strong>$($_.ComputerName)</strong> - Last seen $($_.HoursSinceReport) hours ago</li>" })
    $(if ($StaleCount -gt 10) { "<li><em>...and $($StaleCount - 10) more</em></li>" })
    </ul>"
})

<p style="color: #888; font-size: 12px; margin-top: 30px;">
Full reports available at: $OutputPath<br>
HTML Dashboard: <a href="file:///$($LatestHtmlPath -replace '\\','/')">$LatestHtmlPath</a>
</p>

<p style="color: #888; font-size: 11px;">
QB Energy IT Infrastructure - Automated Report
</p>
</body>
</html>
"@

    try {
        Send-MailMessage -SmtpServer $SmtpServer -From $EmailFrom -To $EmailTo `
            -Subject "WUfB Compliance Report - $DateStamp - $CompliancePercentage% Compliant" `
            -Body $EmailBody -BodyAsHtml -Priority $(if ($CriticalPendingCount -gt 0) { "High" } else { "Normal" })
        Write-Host "  Email sent to: $EmailTo" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR sending email: $_" -ForegroundColor Red
    }
}

# ============================================================
# CLEANUP OLD REPORTS
# ============================================================

Write-Host ""
Write-Host "Cleaning up old reports (keeping last 30 days)..." -ForegroundColor Yellow

$OldReports = Get-ChildItem -Path $OutputPath -Filter "WUfB-*-2*.csv" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
$OldHtml = Get-ChildItem -Path $OutputPath -Filter "WUfB-*-2*.html" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

$CleanedCount = 0
$OldReports + $OldHtml | ForEach-Object {
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    $CleanedCount++
}

if ($CleanedCount -gt 0) {
    Write-Host "  Removed $CleanedCount old report file(s)" -ForegroundColor Gray
}

# ============================================================
# COMPLETE
# ============================================================

$ScriptEndTime = Get-Date
$Duration = $ScriptEndTime - $ScriptStartTime

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  REPORT GENERATION COMPLETE" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Duration: $([Math]::Round($Duration.TotalSeconds, 2)) seconds" -ForegroundColor Gray
Write-Host "  Output: $OutputPath" -ForegroundColor Gray
Write-Host ""
