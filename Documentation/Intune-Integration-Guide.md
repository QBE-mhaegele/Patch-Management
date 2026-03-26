# QB Energy Patch Management - Intune Integration Guide

**Complete Guide to Managing Windows Updates via Intune Based on Risk Analysis**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Monthly Workflow](#monthly-workflow)
5. [Common Scenarios](#common-scenarios)
6. [Troubleshooting](#troubleshooting)

---

## Overview

This integration connects your local risk analysis with Microsoft Intune's update management capabilities:

**What You Get:**
- ✅ Automatic grouping by risk level in Azure AD
- ✅ Different update policies for different risk levels
- ✅ Ability to approve/block specific updates
- ✅ Granular control over update deployment
- ✅ Uninstall problematic updates remotely

**The Flow:**
```
Risk Analysis → Azure AD Groups → Update Rings → Controlled Deployment
     ↓
  CRITICAL: No auto-updates (manual only)
     HIGH: 14-day delay
   MEDIUM: 7-day delay
      LOW: Immediate (pilot group)
```

---

## Prerequisites

### 1. Azure/Intune Licensing
- **Required:** Azure AD P1 or P2 (for dynamic groups)
- **Required:** Intune licenses for all devices
- **Required:** Windows 10/11 Pro or Enterprise

### 2. Permissions
You need **one** of these roles:
- Global Administrator
- Intune Administrator
- Cloud Device Administrator (with Group.ReadWrite.All)

### 3. PowerShell Modules

```powershell
# Install required modules
Install-Module Microsoft.Graph.Authentication -Force
Install-Module Microsoft.Graph.DeviceManagement -Force
Install-Module Microsoft.Graph.Groups -Force
Install-Module Microsoft.Graph.Devices.CorporateManagement -Force

# Verify installation
Get-Module Microsoft.Graph.* -ListAvailable
```

### 4. Devices Must Be:
- ✅ Azure AD Joined or Hybrid Joined
- ✅ Enrolled in Intune
- ✅ Running Windows 10 Pro+ or Windows 11
- ✅ Have device names matching your AD computer names

---

## Initial Setup

### Step 1: Run Risk Analysis

```powershell
# On your patch management server
cd C:\PatchManagement\Scripts

# Run full analysis
.\Master-Orchestrator.ps1 -Phase All -DryRun

# Verify risk scores were created
Test-Path "C:\PatchManagement\Analysis\RiskScores_2026-Jan.json"
```

### Step 2: Create Azure AD Groups

```powershell
# First, do a dry run to see what would happen
.\Sync-IntuneRiskGroups.ps1 -CreateGroups -WhatIf

# If everything looks good, create the groups
.\Sync-IntuneRiskGroups.ps1 -CreateGroups
```

**This creates 4 dynamic groups:**
- `QB-PatchManagement-Critical` - Manual intervention required
- `QB-PatchManagement-High` - Delayed updates
- `QB-PatchManagement-Medium` - Standard schedule
- `QB-PatchManagement-Low` - Pilot/early updates

### Step 3: Sync Device Risk Scores

```powershell
# Sync risk scores to Azure AD device attributes
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes

# This sets extensionAttribute1 on each device with its priority level
# Dynamic groups will auto-populate based on this
```

**Wait 15-30 minutes** for Azure AD dynamic group membership to update.

### Step 4: Create Update Rings

```powershell
# Create update policies for each risk level
.\Sync-IntuneRiskGroups.ps1 -CreateUpdateRings

# Verify in Intune portal:
# Devices → Windows → Windows 10/11 update rings
```

**Update Ring Settings:**

| Group | Quality Defer | Feature Defer | Auto-Update |
|-------|---------------|---------------|-------------|
| **Critical** | 30 days | 180 days | ❌ Paused |
| **High** | 14 days | 90 days | ✅ Enabled |
| **Medium** | 7 days | 60 days | ✅ Enabled |
| **Low** | 0 days | 30 days | ✅ Enabled |

### Step 5: Verify Setup

```powershell
# Check group membership in Azure AD portal
# Go to: Azure AD → Groups → QB-PatchManagement-*

# Verify devices are in correct groups based on risk scores
```

---

## Monthly Workflow

### Week 1 - Patch Tuesday Week

**Tuesday (Microsoft releases patches):**
```
[Microsoft Action]
```

**Wednesday (Collect data):**
```powershell
# Automated via scheduled task
.\Master-Orchestrator.ps1 -Phase Collect
```

**Thursday (Analyze & sync):**
```powershell
# Automated via scheduled task
.\Master-Orchestrator.ps1 -Phase Analyze

# Then sync to Intune
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes
```

**Friday (Review):**
```
1. Review: C:\PatchManagement\Analysis\RiskAnalysis_YYYY-MMM.html
2. Check for critical issues in the report
3. Decide if any updates need to be blocked
```

### Week 2 - Low Risk Deployment

**Automatic deployment to Low risk group:**
- Updates install immediately (0-day defer)
- Monitor for issues

**If problems found:**
```powershell
# Block the problematic update
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5012345") -Action Decline -TargetGroup All
```

### Week 3 - Medium & High Risk Deployment

**Medium group:** Updates auto-install (7 days after release)  
**High group:** Updates auto-install (14 days after release)

**Monitor deployment status** in Intune portal.

### Week 4 - Critical Group (Manual)

For critical systems:
```powershell
# 1. First remediate issues (update drivers, etc.)

# 2. Then approve specific updates
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5012345") -Action Approve -TargetGroup Critical

# 3. Or manually patch via RMM tool
```

---

## Common Scenarios

### Scenario 1: Block a Problematic Update Globally

**Example:** KB5012345 is breaking Intel RST controllers

```powershell
# Block it for ALL groups
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5012345") `
    -Action Decline `
    -TargetGroup All

# Or test first
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5012345") `
    -Action Decline `
    -TargetGroup All `
    -WhatIf
```

### Scenario 2: Force Critical Security Update

**Example:** Zero-day exploit - need to patch immediately

```powershell
# Expedite for all groups
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5099999") `
    -Action Approve `
    -TargetGroup All
```

### Scenario 3: Uninstall Bad Update

**Example:** Update deployed but causing bluescreens

```powershell
# Generate uninstall script
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5012345") `
    -Action Uninstall `
    -TargetGroup Medium

# Then deploy via Intune Remediations or run directly:
Invoke-Command -ComputerName "PROBLEM-PC" -FilePath "C:\Temp\Uninstall-Updates.ps1"
```

### Scenario 4: Pause Updates for a Group

**Example:** Major project ongoing, can't risk reboots

```powershell
# Pause for 35 days (maximum allowed)
.\Manage-IntuneUpdates.ps1 `
    -Action Pause `
    -TargetGroup Medium
```

### Scenario 5: Target Specific Machines

**Example:** 3 Dell machines with specific driver issues

```powershell
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5012345") `
    -Action Decline `
    -SpecificComputers @("DEN-FS572T2-LT", "DEN-1QSDKB4-LT", "DEN-4P7DN74-LT")
```

### Scenario 6: Re-sync After Adding Machines

**Example:** New machines added to domain

```powershell
# Run full collection
.\Master-Orchestrator.ps1 -Phase Collect

# Re-run analysis
.\Master-Orchestrator.ps1 -Phase Analyze

# Sync to Intune
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes
```

---

## Verifying Deployment Status

### Via Intune Portal

```
1. Go to: Intune portal → Reports → Windows updates
2. Select: "Feature and quality update reports"
3. Filter by: Update ring or device group
4. Check: Installation status
```

### Via PowerShell

```powershell
# Connect
Connect-MgGraph

# Get update status for a specific computer
$Device = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq 'DEN-FS572T2-LT'"
Get-MgDeviceManagementManagedDeviceWindowsProtectionState -ManagedDeviceId $Device.Id

# Get all devices needing updates
Get-MgDeviceManagementManagedDevice -Filter "operatingSystem eq 'Windows'" |
    Where-Object {$_.complianceState -ne 'compliant'}
```

---

## Intune Portal Locations

**Update Rings:**
```
Devices → Windows → Windows 10/11 update rings
```

**Device Groups:**
```
Groups → All groups → Search: "QB-PatchManagement"
```

**Deployment Status:**
```
Reports → Windows updates
```

**Remediation Scripts:**
```
Devices → Scripts → Add → Windows 10/11
```

---

## Troubleshooting

### Devices Not Appearing in Groups

**Check:**
```powershell
# 1. Is device in Azure AD?
Get-MgDevice -Filter "displayName eq 'COMPUTERNAME'"

# 2. Is extensionAttribute1 set?
$Device = Get-MgDevice -Filter "displayName eq 'COMPUTERNAME'"
$Device.AdditionalProperties.extensionAttributes.extensionAttribute1

# 3. Re-sync the attribute
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes
```

**Wait:** Dynamic group membership can take 15-30 minutes to update.

### Updates Not Installing

**Check:**
1. **Device enrolled?** Devices → All devices → Find device
2. **Update ring assigned?** Check device's "Configuration" tab
3. **Paused?** Check update ring settings
4. **Connectivity?** Device must be online and checking in

### Permission Errors

**Error:** "Insufficient privileges"

**Fix:**
```powershell
# Re-connect with all required scopes
Disconnect-MgGraph
Connect-MgGraph -Scopes @(
    "DeviceManagementConfiguration.ReadWrite.All",
    "DeviceManagementManagedDevices.ReadWrite.All",
    "Group.ReadWrite.All",
    "Directory.ReadWrite.All"
)
```

### Hybrid Join Issues

**For Hybrid Azure AD Joined devices:**
- Device name in Intune may differ from AD name
- Use Azure AD Device ID for matching
- Consider using `objectId` instead of `displayName`

---

## Best Practices

### 1. Always Use WhatIf First
```powershell
.\Sync-IntuneRiskGroups.ps1 -CreateGroups -WhatIf
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB123") -Action Decline -WhatIf
```

### 2. Test on Pilot First
- Low risk group = your pilot
- Monitor for 48 hours before wider deployment
- Check Event Logs and Intune reports

### 3. Document Blocked Updates
```powershell
# Keep a log
Add-Content "C:\PatchManagement\BlockedUpdates.txt" "$(Get-Date) - Blocked KB5012345 - Intel RST issue"
```

### 4. Regular Sync
```powershell
# Monthly after analysis
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes
```

### 5. Monitor Compliance
- Set up Intune compliance policies
- Get alerts for non-compliant devices
- Review monthly reports

---

## Complete Monthly Command Sequence

```powershell
# Week 1 - Collection & Analysis
cd C:\PatchManagement\Scripts
.\Master-Orchestrator.ps1 -Phase Collect
.\Master-Orchestrator.ps1 -Phase Analyze

# Week 1 - Sync to Intune
.\Sync-IntuneRiskGroups.ps1 -SyncDeviceAttributes

# Week 1 - Review report
Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html"

# Week 2 - Monitor pilot deployment (auto)
# (Check Intune portal for Low group)

# Week 3 - Check for issues
# If problems found:
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5012345") -Action Decline -TargetGroup All

# Week 4 - Handle critical systems
# (Manual review and approval)
```

---

## Key Files

| File | Purpose |
|------|---------|
| `Sync-IntuneRiskGroups.ps1` | Create groups, sync attributes, create rings |
| `Manage-IntuneUpdates.ps1` | Approve/decline/uninstall specific updates |
| `RiskScores_YYYY-MMM.json` | Input data for Intune sync |
| `BlockedUpdates.txt` | Your documentation of blocked updates |

---

## Support

**Microsoft Documentation:**
- Windows Update for Business: https://learn.microsoft.com/windows/deployment/update/waas-manage-updates-wufb
- Intune Update Rings: https://learn.microsoft.com/mem/intune/protect/windows-10-update-rings
- Microsoft Graph API: https://learn.microsoft.com/graph/api/overview

**Internal:**
- Script Location: `C:\PatchManagement\Scripts\`
- Logs: `C:\PatchManagement\Logs\`
- IT Team: it-team@qbenergy.com

---

*QB Energy IT Infrastructure Team*  
*Intune Integration Guide v1.0*  
*January 2026*
