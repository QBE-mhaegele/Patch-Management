# KB Risk Analysis Feature Guide

## Overview

The enhanced risk analysis now identifies **specific KB updates that could be problematic** for each machine based on their hardware and software configuration.

---

## What Gets Analyzed

### 1. Intel RST VMD Controllers
**Detection:** Machines with Intel Rapid Storage Technology Volume Management Device controllers

**Risk:** Storage driver updates can cause boot failure

**KB Types Flagged:**
- Any KB with "storage" in description
- Any KB with "driver" updates
- Any KB with "disk" in description

**Example Warning:**
```
⚠ KB5012345 - Intel RST VMD detected - storage driver updates may cause boot failure
→ Update Intel RST drivers before applying this patch
```

### 2. Proxmox/KVM Virtual Machines
**Detection:** VMs running on Proxmox with VirtIO drivers

**Risk:** Network/display driver updates may affect VirtIO functionality

**KB Types Flagged:**
- KBs with "network" updates
- KBs with "display" updates  
- KBs with "hyper-v" references

**Example Warning:**
```
⚠ KB5023456 - Proxmox VM - network/display driver updates may affect VirtIO
→ Ensure VirtIO drivers are up to date, have VM snapshot
```

### 3. Missing Security Features
**Detection:** Machines without TPM or Secure Boot

**Risk:** Security updates requiring these features may fail

**KB Types Flagged:**
- KBs mentioning "TPM"
- KBs mentioning "Secure Boot"
- KBs mentioning "UEFI"

**Example Warning:**
```
⚠ KB5034567 - Machine lacks TPM/Secure Boot - security updates may fail
→ Verify compatibility before deploying
```

### 4. Outdated OS Versions
**Detection:** Windows 10 1607, Server 2012, etc.

**Risk:** Large cumulative updates, possible incompatibilities

**Example Warning:**
```
⚠ OS version is significantly outdated - cumulative updates may be very large
→ Consider in-place upgrade instead of patching
```

---

## New HTML Report Sections

### Section 1: High-Risk KB Summary (Top of Report)

Shows KBs that affect multiple machines:

```
⚠ High-Risk KB Updates Requiring Attention

KB5012345
Issue: Intel RST VMD detected - storage driver updates may cause boot failure
Recommendation: Update Intel RST drivers before applying this patch
Affected Machines (3): DEN-FS572T2-LT, DEN-1QSDKB4-LT, DEN-4P7DN74-LT
```

### Section 2: Per-Machine KB Warnings (New Column)

Each machine now has a "KB Warnings & Recommendations" column:

**For a machine with Intel RST:**
```
⚠ Watch These KBs:
• KB5012345 - Intel RST VMD detected - storage driver updates may cause boot failure
  → Update Intel RST drivers before applying this patch
```

**For a Proxmox VM:**
```
⚠ Watch These KBs:
• KB5023456 - Proxmox VM - network/display driver updates may affect VirtIO
  → Ensure VirtIO drivers are up to date, have VM snapshot

Notes:
• Machine is a virtual machine - create snapshot before patching
```

**For machines with no concerns:**
```
No specific KB concerns detected ✓
```

---

## Using the KB Risk Summary Script

### Automatic (Part of Workflow)

The KB summary is automatically generated when you run analysis:

```powershell
# Runs automatically
.\Master-Orchestrator.ps1 -Phase Analyze
```

This creates:
- `RiskAnalysis_2026-Jan.html` - Full HTML report with KB warnings
- `RiskScores_2026-Jan_KBWarnings.csv` - CSV export of all warnings

### Manual (Standalone)

You can also run it separately to get a quick console summary:

```powershell
cd C:\PatchManagement\Scripts

# Console output only
.\Get-KBRiskSummary.ps1

# Console + CSV export
.\Get-KBRiskSummary.ps1 -ExportCSV
```

---

## Example Console Output

```
========================================
High-Risk KB Summary
========================================

Loaded risk scores for 11 machines

Found 8 total KB warnings affecting 4 unique KBs

=== HIGH Severity (3 warnings) ===

  KB5012345
    Issue: Intel RST VMD detected - storage driver updates may cause boot failure
    Action: Update Intel RST drivers before applying this patch
    Affected: DEN-FS572T2-LT, DEN-1QSDKB4-LT, DEN-4P7DN74-LT

=== MEDIUM Severity (5 warnings) ===

  KB5023456
    Issue: Proxmox VM - network/display driver updates may affect VirtIO
    Action: Ensure VirtIO drivers are up to date, have VM snapshot
    Affected: QBE-DEN-TEST, QBE-DEN-VM1, QBE-DEN-VM2

========================================
Action Items Before Patching
========================================

1. [3 machines] Intel RST VMD detected - storage driver updates may cause boot failure
   → Update Intel RST drivers before applying this patch

2. [5 machines] Proxmox VM - network/display driver updates may affect VirtIO
   → Ensure VirtIO drivers are up to date, have VM snapshot

========================================
Intune Management Recommendations
========================================

Consider blocking these HIGH severity KBs until machines are remediated:

  KB5012345 (affects: DEN-FS572T2-LT, DEN-1QSDKB4-LT, DEN-4P7DN74-LT)

To block via Intune:
  .\Manage-IntuneUpdates.ps1 -KBNumbers @('KB5012345') -Action Decline -TargetGroup All
```

---

## Integration with Intune

When high-risk KBs are detected, you can immediately block them:

```powershell
# Block a problematic KB for all machines
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5012345") `
    -Action Decline `
    -TargetGroup All

# Or just for specific machines
.\Manage-IntuneUpdates.ps1 `
    -KBNumbers @("KB5012345") `
    -Action Decline `
    -SpecificComputers @("DEN-FS572T2-LT", "DEN-1QSDKB4-LT")
```

---

## Monthly Workflow (Updated)

### Week 1 - Thursday (Analysis Day)

```powershell
# Run analysis
.\Master-Orchestrator.ps1 -Phase Analyze

# KB summary is automatically generated
# Opens the HTML report
Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_2026-Jan.html"
```

**Review the report:**
1. Check "High-Risk KB Summary" at the top
2. Review per-machine KB warnings
3. Note action items

### Week 1 - Friday (Decision Day)

**If high-risk KBs found:**

```powershell
# Block problematic KBs via Intune
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5012345") -Action Decline -TargetGroup All

# Or delay for specific groups
.\Manage-IntuneUpdates.ps1 -Action Pause -TargetGroup High
```

**If no high-risk KBs:**
- Proceed with normal deployment schedule

### Week 2-3 - Remediation

For machines with warnings:
1. Update Intel RST drivers → Then allow KB
2. Update VirtIO drivers → Then allow KB
3. Enable TPM/Secure Boot → Then allow KB

```powershell
# After remediation, unblock the KB
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5012345") -Action Approve -TargetGroup High
```

---

## Files Generated

| File | Description |
|------|-------------|
| `RiskAnalysis_2026-Jan.html` | Full HTML report with KB warnings |
| `RiskScores_2026-Jan.json` | Detailed JSON with all risk data |
| `RiskScores_2026-Jan_KBWarnings.csv` | Spreadsheet of KB warnings |
| `DeploymentPlan_2026-Jan.json` | Phased deployment plan |

---

## Severity Levels

| Severity | Color | Meaning | Action |
|----------|-------|---------|--------|
| **HIGH** | 🔴 Red | Known to cause issues | Block or remediate first |
| **MEDIUM** | 🟡 Yellow | Possible issues | Monitor closely |
| **LOW** | ⚪ Gray | Minor concern | Proceed with caution |

---

## Real-World Example

**Scenario:** February 2026 Patch Tuesday includes KB5099123 with Intel storage driver updates

**Your System Detects:**
1. 3 machines have Intel RST VMD controllers
2. KB5099123 contains storage driver updates
3. Risk analysis flags this as HIGH severity

**HTML Report Shows:**
```
⚠ High-Risk KB Updates Requiring Attention

KB5099123
Issue: Intel RST VMD detected - storage driver updates may cause boot failure
Recommendation: Update Intel RST drivers before applying this patch
Affected Machines (3): DEN-FS572T2-LT, DEN-1QSDKB4-LT, DEN-4P7DN74-LT
```

**Your Action:**
```powershell
# Week 1: Block the KB
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5099123") -Action Decline -TargetGroup All

# Week 2: Update Intel RST drivers on those 3 machines

# Week 3: Unblock the KB for those machines
.\Manage-IntuneUpdates.ps1 -KBNumbers @("KB5099123") -Action Approve -SpecificComputers @("DEN-FS572T2-LT", "DEN-1QSDKB4-LT", "DEN-4P7DN74-LT")
```

**Result:** 
- ✅ Avoided 3 potential boot failures
- ✅ Updated drivers first (proper order)
- ✅ Applied patches safely

---

## Customizing Detection

You can add your own KB detection rules by editing `Invoke-RiskAnalysis.ps1`:

**Example: Add detection for specific applications**

```powershell
# Around line 250, add:

# Check for specific application incompatibilities
if ($Inventory.Software.InstalledApplications | Where-Object {$_.DisplayName -like "*AutoCAD*"}) {
    $CADKBs = $PatchData.CVEs | Where-Object {
        $_.Title -like "*graphics*" -or 
        $_.Title -like "*OpenGL*"
    }
    
    foreach ($KB in $CADKBs.Remediations | Select-Object -Unique) {
        $ProblematicKBs += @{
            KB = $KB
            Reason = "AutoCAD detected - graphics updates may affect rendering"
            Severity = "MEDIUM"
            Recommendation = "Test in non-production environment first"
        }
    }
}
```

---

## Benefits

1. ✅ **Proactive** - Know issues BEFORE deploying
2. ✅ **Specific** - Exact KB numbers to watch
3. ✅ **Actionable** - Clear remediation steps
4. ✅ **Integrated** - Works with Intune blocking
5. ✅ **Automated** - Part of monthly workflow
6. ✅ **Documented** - HTML report with recommendations

---

## Tips

### Tip 1: Review Before Patch Tuesday
Run analysis Wednesday after collection to have Thursday/Friday for review

### Tip 2: Export to CSV
Share the CSV with your team: `RiskScores_2026-Jan_KBWarnings.csv`

### Tip 3: Track Remediation
Use the CSV to track which machines need driver updates

### Tip 4: Learn Patterns
After a few months, you'll know which machines always need attention

### Tip 5: Test on Pilot First
Even with KB warnings, always test on Low risk (pilot) group first

---

*QB Energy IT Infrastructure Team*  
*KB Risk Analysis Guide*  
*January 2026*
