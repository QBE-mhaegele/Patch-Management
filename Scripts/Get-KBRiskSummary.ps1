<#
.SYNOPSIS
    Extract high-risk KB summary from risk analysis
.DESCRIPTION
    Reads the risk scores and generates a summary report of KBs that
    may be problematic for specific machines based on their hardware/software
.NOTES
    Run after Master-Orchestrator.ps1 -Phase Analyze
    Author: QB Energy IT Infrastructure Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RiskScoresPath = "C:\PatchManagement\Analysis\RiskScores_2026-Jan.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportCSV
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "High-Risk KB Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Load risk scores
if (-not (Test-Path $RiskScoresPath)) {
    Write-Host "X Risk scores not found: $RiskScoresPath" -ForegroundColor Red
    Write-Host "  Run: .\Master-Orchestrator.ps1 -Phase Analyze" -ForegroundColor Yellow
    exit 1
}

$RiskScores = Get-Content $RiskScoresPath -Raw | ConvertFrom-Json
Write-Host "Loaded risk scores for $($RiskScores.Count) machines`n" -ForegroundColor Green

# Extract all KB warnings
$AllKBWarnings = @()
$KBsByMachine = @{}

foreach ($Machine in $RiskScores) {
    $ComputerName = $Machine.ComputerName
    
    if ($Machine.Factors.KBCompatibility.ProblematicKBs.Count -gt 0) {
        foreach ($KB in $Machine.Factors.KBCompatibility.ProblematicKBs) {
            $AllKBWarnings += [PSCustomObject]@{
                KB = $KB.KB
                ComputerName = $ComputerName
                Severity = $KB.Severity
                Reason = $KB.Reason
                Recommendation = $KB.Recommendation
                Priority = $Machine.Priority
                RiskScore = $Machine.TotalScore
            }
            
            # Group by KB
            if (-not $KBsByMachine.ContainsKey($KB.KB)) {
                $KBsByMachine[$KB.KB] = @{
                    KB = $KB.KB
                    Severity = $KB.Severity
                    Reason = $KB.Reason
                    Recommendation = $KB.Recommendation
                    AffectedMachines = @()
                }
            }
            
            $KBsByMachine[$KB.KB].AffectedMachines += $ComputerName
        }
    }
}

# Display summary
if ($AllKBWarnings.Count -eq 0) {
    Write-Host "✓ No high-risk KB warnings detected" -ForegroundColor Green
    Write-Host "  All machines appear compatible with upcoming patches`n" -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($AllKBWarnings.Count) total KB warnings affecting $($KBsByMachine.Count) unique KBs`n" -ForegroundColor Yellow

# Group by severity
$BySeverity = $AllKBWarnings | Group-Object Severity

foreach ($Group in ($BySeverity | Sort-Object {
    switch ($_.Name) {
        "HIGH" { 1 }
        "MEDIUM" { 2 }
        "LOW" { 3 }
    }
})) {
    
    $Color = switch ($Group.Name) {
        "HIGH" { "Red" }
        "MEDIUM" { "Yellow" }
        "LOW" { "Gray" }
    }
    
    $WarningCount = $Group.Count
    Write-Host "=== $($Group.Name) Severity ($WarningCount warnings) ===" -ForegroundColor $Color
    Write-Host ""
    
    $KBs = $Group.Group | Group-Object KB
    
    foreach ($KBGroup in $KBs) {
        $KB = $KBGroup.Name
        $Machines = $KBGroup.Group | Select-Object -ExpandProperty ComputerName
        $FirstWarning = $KBGroup.Group[0]
        
        Write-Host "  $KB" -ForegroundColor White
        Write-Host "    Issue: $($FirstWarning.Reason)" -ForegroundColor Gray
        Write-Host "    Action: $($FirstWarning.Recommendation)" -ForegroundColor Cyan
        Write-Host "    Affected: $($Machines -join ', ')" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Action items
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Action Items Before Patching" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$ActionNumber = 1

# Get unique issues
$UniqueIssues = $AllKBWarnings | Select-Object Reason, Recommendation -Unique

foreach ($Issue in $UniqueIssues) {
    $AffectedCount = ($AllKBWarnings | Where-Object {$_.Reason -eq $Issue.Reason}).Count
    
    Write-Host "$ActionNumber. [$AffectedCount machines] $($Issue.Reason)" -ForegroundColor Yellow
    Write-Host "   -> $($Issue.Recommendation)" -ForegroundColor Cyan
    Write-Host ""
    
    $ActionNumber++
}

# Export to CSV if requested
if ($ExportCSV) {
    $OutputPath = $RiskScoresPath -replace '\.json$', '_KBWarnings.csv'
    
    $AllKBWarnings | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "✓ Exported to CSV: $OutputPath" -ForegroundColor Green
}

# Display KB blocking recommendations
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Intune Management Recommendations" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$HighSeverityKBs = ($AllKBWarnings | Where-Object {$_.Severity -eq "HIGH"} | Select-Object -ExpandProperty KB -Unique)

if ($HighSeverityKBs.Count -gt 0) {
    Write-Host "Consider blocking these HIGH severity KBs until machines are remediated:`n" -ForegroundColor Yellow
    
    foreach ($KB in $HighSeverityKBs) {
        $AffectedMachines = ($KBsByMachine[$KB].AffectedMachines -join ', ')
        Write-Host "  $KB (affects: $AffectedMachines)" -ForegroundColor White
    }
    
    Write-Host "`nTo block via Intune:" -ForegroundColor Cyan
    $KBList = $HighSeverityKBs -join "', '"
    Write-Host "  .\Manage-IntuneUpdates.ps1 -KBNumbers @('$KBList') -Action Decline -TargetGroup All" -ForegroundColor Gray
} else {
    Write-Host "No HIGH severity KBs found - standard deployment should be safe" -ForegroundColor Green
}

Write-Host "`n========================================`n" -ForegroundColor Cyan