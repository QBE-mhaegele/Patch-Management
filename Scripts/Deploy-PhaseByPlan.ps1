<#
.SYNOPSIS
    Deploy patches according to deployment plan (without Intune)
.DESCRIPTION
    Reads the deployment plan and helps you deploy patches to machines
    in the correct order based on their risk level
.NOTES
    For local management without Intune
    Deploys one phase at a time with manual confirmation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$DeploymentPlanPath = "C:\PatchManagement\Analysis\DeploymentPlan_2026-Jan.json",
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,4)]
    [int]$Phase = 1,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoReboot = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Patch Deployment (Local Management)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Load deployment plan
if (-not (Test-Path $DeploymentPlanPath)) {
    Write-Host "✗ Deployment plan not found: $DeploymentPlanPath" -ForegroundColor Red
    Write-Host "  Run: .\Master-Orchestrator.ps1 -Phase Analyze first" -ForegroundColor Yellow
    exit 1
}

$Plan = Get-Content $DeploymentPlanPath -Raw | ConvertFrom-Json
Write-Host "Loaded deployment plan: $($Plan.PatchCycle)" -ForegroundColor Green
Write-Host "Total machines: $($Plan.TotalMachines)" -ForegroundColor White

# Get the requested phase
if ($Phase -gt $Plan.Phases.Count) {
    Write-Host "✗ Phase $Phase not found in deployment plan" -ForegroundColor Red
    Write-Host "  Available phases: 1-$($Plan.Phases.Count)" -ForegroundColor Yellow
    exit 1
}

$DeployPhase = $Plan.Phases[$Phase - 1]

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase $($DeployPhase.Number): $($DeployPhase.Name)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Description: $($DeployPhase.Description)" -ForegroundColor White
Write-Host "Machines: $($DeployPhase.Machines.Count)" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "Mode: WHATIF (no patches will be deployed)`n" -ForegroundColor Yellow
} else {
    Write-Host ""
}

# Display machines in this phase
Write-Host "Machines to patch:" -ForegroundColor Yellow
$DeployPhase.Machines | ForEach-Object {
    $StatusColor = switch ($_.Priority) {
        "CRITICAL" { "Red" }
        "HIGH" { "Yellow" }
        "MEDIUM" { "Cyan" }
        default { "Green" }
    }
    
    Write-Host "  - $($_.ComputerName) (Priority: $($_.Priority), Risk: $($_.RiskScore))" -ForegroundColor $StatusColor
    
    if ($_.CreateSnapshot) {
        Write-Host "    ⚠ Virtual machine - create snapshot before patching" -ForegroundColor Yellow
    }
    
    if ($_.RequiresRemediation) {
        Write-Host "    ⚠ Requires remediation before patching!" -ForegroundColor Red
    }
    
    if ($_.RequiresRebuild) {
        Write-Host "    ⚠ CRITICAL - Manual intervention required, do NOT auto-patch" -ForegroundColor Red
    }
}

# Check for VMs needing snapshots
$VMsNeedingSnapshots = $DeployPhase.Machines | Where-Object {$_.CreateSnapshot}

if ($VMsNeedingSnapshots.Count -gt 0) {
    Write-Host "`n⚠ IMPORTANT: Create snapshots for VMs before patching:" -ForegroundColor Yellow
    $VMsNeedingSnapshots | ForEach-Object {
        Write-Host "  ssh root@proxmox 'qm snapshot VMID pre-patch-$(Get-Date -Format yyyyMMdd)' # $($_.ComputerName)" -ForegroundColor Gray
    }
}

# Check for machines requiring remediation
$MachinesNeedingRemediation = $DeployPhase.Machines | Where-Object {$_.RequiresRemediation -or $_.RequiresRebuild}

if ($MachinesNeedingRemediation.Count -gt 0) {
    Write-Host "`n⚠ WARNING: Some machines require attention before patching:" -ForegroundColor Red
    $MachinesNeedingRemediation | ForEach-Object {
        Write-Host "  - $($_.ComputerName)" -ForegroundColor Yellow
    }
    Write-Host "  Review the risk analysis report for details" -ForegroundColor Gray
}

# Confirm deployment
if (-not $WhatIf) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    
    $Confirm = Read-Host "Deploy patches to Phase $($DeployPhase.Number) machines? (y/n)"
    
    if ($Confirm -ne 'y') {
        Write-Host "Deployment cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting Deployment" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$SuccessCount = 0
$FailCount = 0
$SkippedCount = 0

foreach ($Machine in $DeployPhase.Machines) {
    $ComputerName = $Machine.ComputerName
    
    Write-Host "`n[$($SuccessCount + $FailCount + $SkippedCount + 1)/$($DeployPhase.Machines.Count)] Processing $ComputerName..." -ForegroundColor Cyan
    
    # Skip machines that should not be auto-patched
    if ($Machine.RequiresRebuild -or $Machine.AutoPatch -eq $false) {
        Write-Host "  ⊘ Skipped - requires manual intervention" -ForegroundColor Yellow
        $SkippedCount++
        continue
    }
    
    # Warn if requires remediation but continue
    if ($Machine.RequiresRemediation) {
        Write-Host "  ⚠ WARNING: Machine requires remediation but proceeding..." -ForegroundColor Yellow
    }
    
    # Test connectivity
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        Write-Host "  ✗ Cannot reach $ComputerName" -ForegroundColor Red
        $FailCount++
        continue
    }
    
    if ($WhatIf) {
        Write-Host "  [WHATIF] Would deploy patches to $ComputerName" -ForegroundColor Gray
        $SuccessCount++
        continue
    }
    
    # Deploy patches
    try {
        $DeployScript = Join-Path (Split-Path $PSScriptRoot -Parent) "Scripts\Deploy-Patches.ps1"
        
        if (-not (Test-Path $DeployScript)) {
            $DeployScript = ".\Deploy-Patches.ps1"
        }
        
        & $DeployScript -ComputerName $ComputerName -AutoReboot:$AutoReboot -CreateSnapshot:$Machine.CreateSnapshot
        
        Write-Host "  ✓ Successfully deployed to $ComputerName" -ForegroundColor Green
        $SuccessCount++
        
        # Wait between machines if specified
        if ($DeployPhase.WaitHours -gt 0 -and $Machine -ne $DeployPhase.Machines[-1]) {
            Write-Host "  ⏱ Waiting $($DeployPhase.WaitHours) hours before next machine..." -ForegroundColor Yellow
            Start-Sleep -Seconds ($DeployPhase.WaitHours * 3600)
        }
        
    } catch {
        Write-Host "  ✗ Failed to deploy to $ComputerName : $_" -ForegroundColor Red
        $FailCount++
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary - Phase $($DeployPhase.Number)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Successful: $SuccessCount" -ForegroundColor Green
Write-Host "Failed: $FailCount" -ForegroundColor $(if ($FailCount -gt 0) {"Red"} else {"White"})
Write-Host "Skipped: $SkippedCount" -ForegroundColor $(if ($SkippedCount -gt 0) {"Yellow"} else {"White"})

if ($DeployPhase.WaitBeforeNext -gt 0) {
    Write-Host "`n⏱ Wait $($DeployPhase.WaitBeforeNext) hours before deploying Phase $($DeployPhase.Number + 1)" -ForegroundColor Yellow
}

# Next steps
Write-Host "`nNext Steps:" -ForegroundColor Cyan

if ($Phase -lt $Plan.Phases.Count) {
    Write-Host "  1. Monitor deployed machines for $($DeployPhase.WaitBeforeNext) hours" -ForegroundColor White
    Write-Host "  2. Check Event Viewer for errors" -ForegroundColor White
    Write-Host "  3. Test applications" -ForegroundColor White
    Write-Host "  4. Deploy Phase $($Phase + 1):" -ForegroundColor White
    Write-Host "     .\Deploy-PhaseByPlan.ps1 -Phase $($Phase + 1)" -ForegroundColor Gray
} else {
    Write-Host "  1. Monitor all patched machines" -ForegroundColor White
    Write-Host "  2. Document any issues" -ForegroundColor White
    Write-Host "  3. Update records" -ForegroundColor White
    Write-Host "`n  ✓ All phases complete!" -ForegroundColor Green
}

Write-Host "`n========================================`n" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "This was a WHATIF run - no patches were deployed" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf to actually deploy patches`n" -ForegroundColor Gray
}
