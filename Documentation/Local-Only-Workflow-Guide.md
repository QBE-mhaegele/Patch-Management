# QB Energy Patch Management - Local Deployment Guide
## (Without Intune - Direct Management)

---

## Overview

This guide covers using the patch management system **without Intune**, managing patches directly via:
- PSWindowsUpdate module (Windows Update API)
- Remote PowerShell (WinRM)
- Group Policy (manual application)
- RMM tools (optional)

---

## What You Have (Local Management)

### ✅ Automated Analysis
- Collects Microsoft CVE data
- Inventories all machines
- Calculates risk scores
- **NEW:** Identifies problematic KBs
- Generates HTML reports
- Creates phased deployment plan

### ✅ Manual Deployment
- You review the plan
- You decide when to patch each group
- You execute patches via scripts
- You monitor results

### ❌ What You DON'T Have (Without Intune)
- Automatic group creation
- Centralized policy enforcement
- Remote KB blocking
- Dashboard/reporting portal

**This is fine!** You still get 90% of the benefits.

---

## Monthly Workflow (Local Management)

### **Week 1: Collection & Analysis**

#### Wednesday (Day After Patch Tuesday)
```powershell
# Automated via scheduled task
cd C:\PatchManagement\Scripts
.\Master-Orchestrator.ps1 -Phase Collect
```

**What Happens:**
- Downloads Microsoft CVE data
- Collects inventory from all 11 machines
- Saves to \\QBE-DEN-FILE4\inventory

#### Thursday (Analysis Day)
```powershell
# Automated via scheduled task
.\Master-Orchestrator.ps1 -Phase Analyze
```

**What Happens:**
- Analyzes all inventory files
- Calculates risk scores
- **Identifies problematic KBs** ← NEW!
- Creates deployment plan
- Generates HTML report

**Output Files:**
- `C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html` - Main report
- `C:\PatchManagement\Analysis\DeploymentPlan_2026-Jan.json` - Phased plan
- `C:\PatchManagement\Analysis\RiskScores_2026-Jan_KBWarnings.csv` - KB warnings

#### Friday (Review Day)
```powershell
# Open the HTML report
Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html"

# View KB summary
.\Get-KBRiskSummary.ps1
```

**Your Actions:**
1. Review the HTML report
2. Check "High-Risk KB Summary" section
3. Note which machines need attention
4. Plan remediation for high-risk machines

**Decision Points:**
- Are there HIGH severity KB warnings?
  - YES → Don't deploy those KBs yet, remediate first
  - NO → Proceed with deployment plan

---

### **Week 2: Pilot Deployment (Low Risk Group)**

#### Monday (Deploy to Pilot)

**From the deployment plan, get Phase 1 machines (LOW risk):**

```powershell
# Load the deployment plan
$Plan = Get-Content "C:\PatchManagement\Analysis\DeploymentPlan_2026-Jan.json" | ConvertFrom-Json

# Get Phase 1 machines
$PilotMachines = $Plan.Phases[0].Machines

# Deploy to each pilot machine
foreach ($Machine in $PilotMachines) {
    Write-Host "Deploying to $($Machine.ComputerName)..." -ForegroundColor Cyan
    
    # Create snapshot if it's a VM
    if ($Machine.CreateSnapshot) {
        Write-Host "  Remember to create snapshot first!" -ForegroundColor Yellow
        # For Proxmox: ssh root@proxmox 'qm snapshot VMID pre-patch-$(date +%Y%m%d)'
    }
    
    # Deploy patches
    .\Deploy-Patches.ps1 -ComputerName $Machine.ComputerName -AutoReboot
}
```

**Or deploy one at a time:**
```powershell
# Example: QBE-DEN-TEST (your typical pilot machine)
.\Deploy-Patches.ps1 -ComputerName "QBE-DEN-TEST" -AutoReboot
```

#### Tuesday-Wednesday (Monitor Pilot)
- Check Event Viewer on pilot machines
- Test applications
- Verify no issues

**If issues found:**
- Document the problem
- Identify which KB caused it
- Skip that KB for other machines (manual block via GPO or just don't install)

---

### **Week 3: Standard Deployment (Medium Risk)**

#### Monday-Tuesday (Deploy Medium Risk)

**Get Phase 2 machines from deployment plan:**

```powershell
$Plan = Get-Content "C:\PatchManagement\Analysis\DeploymentPlan_2026-Jan.json" | ConvertFrom-Json
$MediumRiskMachines = $Plan.Phases[1].Machines

# Deploy in batches (5 machines at a time)
$Batches = 0..([math]::Ceiling($MediumRiskMachines.Count / 5) - 1)

foreach ($BatchNum in $Batches) {
    $Batch = $MediumRiskMachines | Select-Object -Skip ($BatchNum * 5) -First 5
    
    Write-Host "`nBatch $($BatchNum + 1): Deploying to $($Batch.Count) machines" -ForegroundColor Cyan
    
    foreach ($Machine in $Batch) {
        .\Deploy-Patches.ps1 -ComputerName $Machine.ComputerName -AutoReboot
        Start-Sleep -Seconds 10  # Small delay between machines
    }
    
    Write-Host "Batch complete. Waiting before next batch..." -ForegroundColor Yellow
    Start-Sleep -Seconds 300  # 5 minute wait between batches
}
```

**Or use a simple loop:**
```powershell
# Medium risk machines (from your deployment plan)
$MediumRisk = @("DEN-1QSDKB4-LT", "DEN-4P7DN74-LT", "DEN-MJ0J0FG7-DT")

foreach ($Computer in $MediumRisk) {
    Write-Host "Patching $Computer..." -ForegroundColor Cyan
    .\Deploy-Patches.ps1 -ComputerName $Computer -AutoReboot
    Start-Sleep -Seconds 60  # 1 minute between machines
}
```

---

### **Week 3-4: High Risk Deployment**

#### Before Patching: Remediate Issues

**For machines with KB warnings (from Get-KBRiskSummary.ps1):**

**Example: DEN-FS572T2-LT has Intel RST warning**

```powershell
# 1. Remote to the machine or use RMM
mstsc /v:DEN-FS572T2-LT

# 2. Update Intel RST drivers
# Download from Dell or Intel website
# Install via Device Manager or Dell Command Update

# 3. Reboot
Restart-Computer -ComputerName DEN-FS572T2-LT -Wait

# 4. NOW deploy patches
.\Deploy-Patches.ps1 -ComputerName DEN-FS572T2-LT -AutoReboot
```

**Or deploy WITHOUT the problematic KB:**

```powershell
# On the target machine, hide the problematic KB
Invoke-Command -ComputerName DEN-FS572T2-LT -ScriptBlock {
    # Hide KB5012345 so it won't install
    $Update = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search("IsInstalled=0").Updates | 
        Where-Object {$_.KBArticleIDs -contains "5012345"}
    
    if ($Update) {
        $Update.IsHidden = $true
        Write-Host "Hidden KB5012345"
    }
}

# Now deploy (will skip the hidden KB)
.\Deploy-Patches.ps1 -ComputerName DEN-FS572T2-LT -AutoReboot
```

---

### **Week 4: Critical Machines (Manual Only)**

**For CRITICAL priority machines, do NOT auto-patch:**

```powershell
# Example: QBE-PAR-CNRPT1 (that Paris machine from earlier)
# DO NOT RUN: .\Deploy-Patches.ps1 -ComputerName QBE-PAR-CNRPT1

# Instead:
# 1. Review the issues in the HTML report
# 2. Consider rebuild vs patch
# 3. If patching, do it manually during maintenance window
# 4. Have backups ready
```

---

## Handling Problematic KBs (Without Intune)

### Option 1: Hide KB on Specific Machines

```powershell
# Hide KB5012345 on machines with Intel RST
$MachinesWithRST = @("DEN-FS572T2-LT", "DEN-1QSDKB4-LT", "DEN-4P7DN74-LT")

foreach ($Computer in $MachinesWithRST) {
    Invoke-Command -ComputerName $Computer -ScriptBlock {
        param($KB)
        
        $Update = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search("IsInstalled=0").Updates | 
            Where-Object {$_.KBArticleIDs -contains $KB}
        
        if ($Update) {
            $Update.IsHidden = $true
            Write-Host "Hidden KB$KB on $env:COMPUTERNAME"
        }
    } -ArgumentList "5012345"
}
```

### Option 2: Group Policy (Domain-Wide Block)

1. **Open GPMC:** Group Policy Management Console
2. **Create new GPO:** "Block KB5012345"
3. **Navigate to:** Computer Configuration → Policies → Administrative Templates → Windows Components → Windows Update
4. **Enable:** "Do not include drivers with Windows Updates"
5. **Or use:** "Configure Automatic Updates" → Set to manual

**Better option:** Use WSUS if you have it, or Windows Update for Business settings in GPO

### Option 3: Manual Exclusion in Deploy Script

Edit `Deploy-Patches.ps1` around line 80:

```powershell
# Add exclusion list at the top of the script
$ExcludedKBs = @("5012345", "5023456")  # KBs to skip

# Then in the install section, add filter:
$Result = Install-WindowsUpdate -AcceptAll -IgnoreReboot -NotKBArticleID $ExcludedKBs -Verbose
```

---

## Automation Setup

### One-Time Setup

```powershell
cd C:\PatchManagement\Scripts

# Create scheduled tasks for monthly automation
.\Setup-ScheduledTasks.ps1

# Tasks created:
# - QB-PatchManagement-Collect (Wed 6 AM)
# - QB-PatchManagement-Analyze (Thu 7 AM)
```

**Note:** Deployment is NOT automated - you do it manually after review

---

## Quick Reference Commands

### Monthly Analysis
```powershell
# Full monthly workflow (Collect + Analyze)
.\Master-Orchestrator.ps1 -Phase All -DryRun  # Test first
.\Master-Orchestrator.ps1 -Phase All  # Real run

# Just collection
.\Master-Orchestrator.ps1 -Phase Collect

# Just analysis
.\Master-Orchestrator.ps1 -Phase Analyze
```

### View Results
```powershell
# HTML report
Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html"

# KB warnings
.\Get-KBRiskSummary.ps1

# KB warnings to CSV
.\Get-KBRiskSummary.ps1 -ExportCSV
```

### Deploy Patches
```powershell
# Single machine
.\Deploy-Patches.ps1 -ComputerName "COMPUTERNAME" -AutoReboot

# Without auto-reboot
.\Deploy-Patches.ps1 -ComputerName "COMPUTERNAME" -AutoReboot:$false

# Create snapshot first (for VMs)
.\Deploy-Patches.ps1 -ComputerName "COMPUTERNAME" -CreateSnapshot -AutoReboot
```

### Check Deployment Status
```powershell
# Check specific machine
Invoke-Command -ComputerName "COMPUTERNAME" -ScriptBlock {
    # Last installed update
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
    
    # Pending reboot?
    Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
}

# Check all machines
$AllComputers = @("QBE-DEN-TEST", "DEN-FS572T2-LT", "DEN-1QSDKB4-LT")

$AllComputers | ForEach-Object {
    $Computer = $_
    $LastPatch = Invoke-Command -ComputerName $Computer -ScriptBlock {
        (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).HotFixID
    }
    
    Write-Host "$Computer : $LastPatch"
}
```

---

## Files You Need (No Intune)

### Scripts Folder
- Master-Orchestrator.ps1 ✅
- Get-MicrosoftPatches.ps1 ✅
- Get-ClientInventory.ps1 ✅
- Invoke-RiskAnalysis.ps1 ✅
- Deploy-Patches.ps1 ✅
- Setup-ScheduledTasks.ps1 ✅
- Get-KBRiskSummary.ps1 ✅
- Test-ADConfiguration.ps1 ✅
- Diagnose-InventoryFiles.ps1 ✅
- Cleanup-InventoryFiles.ps1 ✅

### Documentation Folder
- 00-README-PatchManagement.md ✅
- 01-Installation-Guide.md ✅
- 02-Deployment-Checklist.md ✅
- KB-Risk-Analysis-Guide.md ✅

---

## Example: First Full Month

### Week 1 - Analysis
```powershell
# Wednesday (automatic)
# Scheduled task runs: .\Master-Orchestrator.ps1 -Phase Collect

# Thursday (automatic)  
# Scheduled task runs: .\Master-Orchestrator.ps1 -Phase Analyze

# Friday (manual review)
Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html"
.\Get-KBRiskSummary.ps1

# Output shows:
# HIGH Severity: KB5012345 affects 3 machines (Intel RST)
# Decision: Update Intel RST drivers before deploying KB5012345
```

### Week 2 - Pilot
```powershell
# Monday
# Update Intel RST drivers on DEN-FS572T2-LT, DEN-1QSDKB4-LT, DEN-4P7DN74-LT

# Tuesday (after driver updates)
.\Deploy-Patches.ps1 -ComputerName "QBE-DEN-TEST" -AutoReboot  # Pilot machine

# Monitor for 48 hours
```

### Week 3 - Standard Deployment
```powershell
# Tuesday (pilot was successful)
$MediumRisk = @("DEN-1QSDKB4-LT", "DEN-4P7DN74-LT", "DEN-MJ0J0FG7-DT")

foreach ($Computer in $MediumRisk) {
    .\Deploy-Patches.ps1 -ComputerName $Computer -AutoReboot
}

# Monitor for 24 hours
```

### Week 4 - High Risk
```powershell
# After ensuring drivers are updated
$HighRisk = @("DEN-FS572T2-LT")  # Already updated Intel RST

.\Deploy-Patches.ps1 -ComputerName "DEN-FS572T2-LT" -AutoReboot
```

---

## When You're Ready for Intune

When you want to add Intune later, you'll gain:

1. **Centralized Control** - Manage from Azure portal
2. **Automatic Grouping** - Machines auto-sort by risk level
3. **Policy Enforcement** - Block/approve KBs centrally
4. **Better Reporting** - Built-in dashboards

Your existing workflow stays the same, you just add:
```powershell
# One-time Intune setup
.\Sync-IntuneRiskGroups.ps1 -CreateGroups -CreateUpdateRings

# Monthly sync
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes
```

But that's for later! For now, you have everything you need for local management.

---

## Summary

**You Have (No Intune):**
- ✅ Automated monthly CVE collection
- ✅ Automated inventory gathering
- ✅ **KB risk detection** (NEW!)
- ✅ Risk scoring and prioritization
- ✅ Phased deployment planning
- ✅ HTML reports with KB warnings
- ✅ Manual deployment control

**You Don't Have:**
- ❌ Centralized policy portal
- ❌ Automatic group assignment
- ❌ Remote KB blocking via console
- ❌ Compliance dashboard

**But you still save:**
- 16+ hours/month on manual analysis
- Avoided system failures from bad patches
- Clear deployment priorities
- Documented decision-making

---

## Quick Start Checklist

- [ ] All scripts in C:\PatchManagement\Scripts\
- [ ] Scheduled tasks created
- [ ] WinRM enabled on all machines
- [ ] File share accessible
- [ ] First analysis run successful
- [ ] HTML report reviewed
- [ ] Pilot machines identified
- [ ] Deployment schedule planned

---

*QB Energy IT Infrastructure Team*  
*Local Patch Management Guide*  
*January 2026*
