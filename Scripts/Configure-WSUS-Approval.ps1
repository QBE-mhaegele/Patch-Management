# Configure-WSUS-Approval.ps1
# Configure automatic approval rules for WSUS

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$WSUSServer = "QBE-DEN-WINUP1",
    
    [Parameter(Mandatory=$false)]
    [int]$WSUSPort = 8530
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "WSUS Automatic Approval Configuration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Connect to WSUS
Write-Host "Connecting to WSUS server: $WSUSServer..." -ForegroundColor Yellow

try {
    $WSUS = Get-WsusServer -Name $WSUSServer -PortNumber $WSUSPort -ErrorAction Stop
    Write-Host "  Connected successfully" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Cannot connect to WSUS - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Get computer groups
Write-Host "Loading computer groups..." -ForegroundColor Yellow
$AllGroups = $WSUS.GetComputerTargetGroups()

Write-Host "  Available Groups:" -ForegroundColor White
foreach ($Group in $AllGroups) {
    Write-Host "    - $($Group.Name) ($($Group.GetComputerTargets().Count) computers)" -ForegroundColor Gray
}

Write-Host ""

# Create approval rules
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating Approval Rules" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Rule 1: Critical Updates - Auto approve for All Computers
Write-Host "[1/4] Critical Updates - All Computers..." -ForegroundColor Yellow

try {
    $Rule1 = $WSUS.CreateInstallApprovalRule("Critical Updates - Auto Approve")
    
    # Enable the rule
    $Rule1.Enabled = $true
    
    # Set update classifications (Critical Updates, Security Updates)
    $Classifications = $WSUS.GetUpdateClassifications() | Where-Object { 
        $_.Title -eq "Critical Updates" -or $_.Title -eq "Security Updates" 
    }
    $Rule1.SetUpdateClassifications($Classifications)
    
    # Set computer groups (All Computers)
    $AllComputersGroup = $AllGroups | Where-Object { $_.Name -eq "All Computers" }
    $Rule1.SetComputerTargetGroups(@($AllComputersGroup))
    
    # Set approval action
    $Rule1.Action = [Microsoft.UpdateServices.Administration.AutomaticUpdateApprovalAction]::Install
    
    # Save rule
    $Rule1.Save()
    
    Write-Host "  Created: Critical/Security updates auto-approve" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "  Rule already exists" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

Write-Host ""

# Rule 2: Definition Updates - Auto approve for All Computers
Write-Host "[2/4] Definition Updates - All Computers..." -ForegroundColor Yellow

try {
    $Rule2 = $WSUS.CreateInstallApprovalRule("Definition Updates - Auto Approve")
    
    # Enable the rule
    $Rule2.Enabled = $true
    
    # Set update classifications (Definition Updates)
    $DefClassification = $WSUS.GetUpdateClassifications() | Where-Object { 
        $_.Title -eq "Definition Updates" 
    }
    $Rule2.SetUpdateClassifications(@($DefClassification))
    
    # Set computer groups (All Computers)
    $AllComputersGroup = $AllGroups | Where-Object { $_.Name -eq "All Computers" }
    $Rule2.SetComputerTargetGroups(@($AllComputersGroup))
    
    # Set approval action
    $Rule2.Action = [Microsoft.UpdateServices.Administration.AutomaticUpdateApprovalAction]::Install
    
    # Save rule
    $Rule2.Save()
    
    Write-Host "  Created: Definition updates auto-approve" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "  Rule already exists" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }
}

Write-Host ""

# Rule 3: Update Rollups - Manual approval recommended
Write-Host "[3/4] Update Rollups - Information only..." -ForegroundColor Yellow
Write-Host "  Recommended: Manual approval for rollups" -ForegroundColor Gray
Write-Host "  Configure in WSUS console if auto-approval desired" -ForegroundColor Gray

Write-Host ""

# Rule 4: Feature Updates - Manual approval REQUIRED
Write-Host "[4/4] Feature Updates - Information only..." -ForegroundColor Yellow
Write-Host "  Recommended: MANUAL approval for feature updates" -ForegroundColor Gray
Write-Host "  These are major Windows version upgrades" -ForegroundColor Gray

Write-Host ""

# Display configured rules
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Current Approval Rules" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$Rules = $WSUS.GetInstallApprovalRules()

if ($Rules.Count -eq 0) {
    Write-Host "No approval rules configured`n" -ForegroundColor Yellow
} else {
    foreach ($Rule in $Rules) {
        $StatusColor = if ($Rule.Enabled) { "Green" } else { "Gray" }
        $StatusText = if ($Rule.Enabled) { "[ENABLED]" } else { "[DISABLED]" }
        
        Write-Host "$StatusText $($Rule.Name)" -ForegroundColor $StatusColor
        
        # Get classifications
        $RuleClassifications = $Rule.GetUpdateClassifications()
        if ($RuleClassifications.Count -gt 0) {
            Write-Host "  Classifications:" -ForegroundColor Gray
            foreach ($Class in $RuleClassifications) {
                Write-Host "    - $($Class.Title)" -ForegroundColor Gray
            }
        }
        
        # Get computer groups
        $RuleGroups = $Rule.GetComputerTargetGroups()
        if ($RuleGroups.Count -gt 0) {
            Write-Host "  Computer Groups:" -ForegroundColor Gray
            foreach ($Group in $RuleGroups) {
                Write-Host "    - $($Group.Name)" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
    }
}

# Decline superseded updates
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Declining Superseded Updates" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "This may take a few minutes..." -ForegroundColor Yellow

try {
    $UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::Any
    
    $AllUpdates = $WSUS.GetUpdates($UpdateScope)
    
    $SupersededCount = 0
    
    foreach ($Update in $AllUpdates) {
        if ($Update.IsSuperseded -and -not $Update.IsDeclined) {
            $Update.Decline()
            $SupersededCount++
        }
    }
    
    Write-Host "  Declined $SupersededCount superseded updates" -ForegroundColor Green
    
} catch {
    Write-Host "  ERROR: Failed to decline superseded updates - $_" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Approval Rules Summary:" -ForegroundColor White
Write-Host "  Auto-Approve:" -ForegroundColor Green
Write-Host "    - Critical Updates" -ForegroundColor Gray
Write-Host "    - Security Updates" -ForegroundColor Gray
Write-Host "    - Definition Updates" -ForegroundColor Gray
Write-Host ""
Write-Host "  Manual Approval Required:" -ForegroundColor Yellow
Write-Host "    - Update Rollups (optional auto-approve)" -ForegroundColor Gray
Write-Host "    - Feature Updates (recommended manual)" -ForegroundColor Gray
Write-Host "    - All other updates" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Monitor WSUS console for new updates" -ForegroundColor Gray
Write-Host "     updateservices.msc" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Manually approve Update Rollups as needed" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Test updates on pilot group before production" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Set up monthly maintenance:" -ForegroundColor Gray
Write-Host "     .\Maintenance-WSUS.ps1" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================`n" -ForegroundColor Cyan
