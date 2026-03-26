# Machine Exclusion List Feature
## QB Energy Patch Management System v2.1

---

## 📋 Overview

The **Machine Exclusion List** allows you to permanently skip specific machines during inventory collection. This is useful for:

- 🐧 **Linux/Unix systems** that show as "Windows" in Active Directory
- 🚫 **WinRM disabled machines** that can't be inventoried remotely
- 💤 **Offline templates** or virtual machines that should never be patched
- 📦 **Decommissioned machines** still present in Active Directory
- 🔒 **High-security systems** with special requirements

---

## 🎯 Your Use Case

**Machine:** `DEN-6G11R74-LT`

**Error:**
```
Error: [DEN-6G11R74-LT] Connecting to remote server DEN-6G11R74-LT 
failed with the following error message: WinRM cannot complete the 
operation. Verify that the specified computer name is valid...
```

**Likely Cause:** This is a Linux system showing as Windows in AD, or has WinRM disabled.

**Solution:** Add to exclusion list so it's automatically skipped in future collections.

---

## 🚀 Quick Start

### **Option 1: Use Management Script (Recommended)**

```powershell
# Navigate to scripts folder
cd C:\PatchManagement\Scripts

# Add the machine to exclusion list
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT

# Verify it was added
.\Manage-ExclusionList.ps1 -View

# Run collection again - machine will be skipped automatically
```

---

### **Option 2: Edit File Manually**

```powershell
# Open the exclusion file
notepad C:\PatchManagement\Config\ExcludedMachines.txt

# Add the machine name on a new line:
DEN-6G11R74-LT

# Save and close
```

---

## 📁 File Location

**Exclusion List File:**
```
C:\PatchManagement\Config\ExcludedMachines.txt
```

**Format:**
```
# Excluded Machines List
# Lines starting with # are comments
# One machine name per line

DEN-6G11R74-LT
DEN-LINUX-01
PAR-UBUNTU-SRV
Test-Machine-Offline
```

---

## 🛠️ Management Script

### **View Current Exclusions**

```powershell
.\Manage-ExclusionList.ps1 -View
```

**Output:**
```
========================================
Excluded Machines List
========================================

File: C:\PatchManagement\Config\ExcludedMachines.txt

Currently Excluded Machines (3):

  • DEN-6G11R74-LT
  • DEN-LINUX-01
  • PAR-UBUNTU-SRV

These machines will be skipped during collection.
```

---

### **Add Machine**

```powershell
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT
```

**Output:**
```
Added 'DEN-6G11R74-LT' to exclusion list.
This machine will be skipped during future collections.
```

**If Already Added:**
```
'DEN-6G11R74-LT' is already in the exclusion list.
```

---

### **Remove Machine**

```powershell
.\Manage-ExclusionList.ps1 -Remove DEN-6G11R74-LT
```

**Output:**
```
Removed 'DEN-6G11R74-LT' from exclusion list.
This machine will be included in future collections.
```

---

### **Clear All Exclusions**

```powershell
.\Manage-ExclusionList.ps1 -Clear
```

**Output:**
```
This will remove ALL machines from the exclusion list. Continue? (Y/N): Y

Cleared all machines from exclusion list.
All machines will be included in future collections.
```

---

## 🔄 Collection Workflow

### **With Exclusions:**

```
1. Load exclusion list from Config\ExcludedMachines.txt
2. Query Active Directory for computers
3. Filter Windows machines only
4. Remove excluded machines from list
5. Collect from remaining machines
6. Skip excluded machines automatically
```

---

### **Collection Output Example:**

```
Querying Active Directory...
Found 87 Windows computers to inventory

Filtered out 3 excluded machines from list
  (These are machines in the exclusion list)

Will collect from 84 machines

Organizing computers by OU...
  Created folder: Denver
  Created folder: Parachute

Collecting from DEN-FS572T2-LT (Denver)...
  Success: Saved to Denver\

Collecting from DEN-6G11R74-LT (Denver)...
  [SKIPPED - Machine in exclusion list]

Collecting from PAR-WK123-LT (Parachute)...
  Success: Saved to Parachute\
```

---

## 🎨 Error Detection

The system automatically detects WinRM connection failures and provides helpful hints:

### **Before Adding to Exclusion:**

```
Collecting from DEN-6G11R74-LT (Denver)...
  Error: WinRM connection failed (likely non-Windows or WinRM disabled)
  Hint: Consider adding 'DEN-6G11R74-LT' to exclusion list
  To auto-skip this machine in future, add it to:
  C:\PatchManagement\Config\ExcludedMachines.txt
```

---

### **After Adding to Exclusion:**

```
Found 87 Windows computers to inventory

Filtered out 1 excluded machine from list
  (These are machines in the exclusion list)

Will collect from 86 machines

[Collection proceeds without attempting DEN-6G11R74-LT]
```

---

## 📊 Common Use Cases

### **1. Linux System with Windows AD Entry**

**Scenario:** Linux server shows in AD as Windows

**Solution:**
```powershell
.\Manage-ExclusionList.ps1 -Add DEN-LINUX-01
```

**Benefit:** Stop wasting time trying to collect from Linux

---

### **2. VM Template Never Online**

**Scenario:** Virtual machine template in AD but always offline

**Solution:**
```powershell
.\Manage-ExclusionList.ps1 -Add TEMPLATE-WIN11
```

**Benefit:** Faster collection, no timeout waiting for offline machine

---

### **3. High-Security System**

**Scenario:** Critical server with special patching requirements

**Solution:**
```powershell
.\Manage-ExclusionList.ps1 -Add PROD-SQL-01
```

**Benefit:** Manually manage patches, avoid automation

---

### **4. Decommissioned But Not Removed from AD**

**Scenario:** Old machines still in AD, waiting for cleanup

**Solution:**
```powershell
.\Manage-ExclusionList.ps1 -Add OLD-SERVER-01
.\Manage-ExclusionList.ps1 -Add OLD-SERVER-02
```

**Benefit:** Clean collection logs, accurate machine counts

---

## 🧪 Testing

### **Test the Exclusion Feature:**

```powershell
# 1. Add machine to exclusion list
cd C:\PatchManagement\Scripts
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT

# 2. Verify it was added
.\Manage-ExclusionList.ps1 -View

# Expected: DEN-6G11R74-LT in list

# 3. Run collection
.\Launch-PatchManagementGUI.ps1
# Click "Run Collection"

# Expected Output:
# - "Filtered out 1 excluded machine from list"
# - DEN-6G11R74-LT not attempted
# - No WinRM error for DEN-6G11R74-LT
```

---

### **Test Removing from Exclusion:**

```powershell
# 1. Remove machine
.\Manage-ExclusionList.ps1 -Remove DEN-6G11R74-LT

# 2. Run collection
.\Launch-PatchManagementGUI.ps1
# Click "Run Collection"

# Expected:
# - Machine is attempted
# - WinRM error appears (because machine still can't be reached)
```

---

## 🔍 Troubleshooting

### **Issue: Machine Still Being Attempted**

**Possible Causes:**
1. Machine name typo in exclusion list
2. Machine name case sensitivity (shouldn't matter, but check)
3. Exclusion file not being read

**Solution:**
```powershell
# Check exact machine name from AD
Get-ADComputer -Identity "DEN-6G11R74-LT" | Select Name

# Compare with exclusion list
Get-Content "C:\PatchManagement\Config\ExcludedMachines.txt" | 
    Where-Object { $_ -eq "DEN-6G11R74-LT" }

# If not found, add it again
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT
```

---

### **Issue: Too Many Machines Excluded**

**Symptom:** Very few machines being collected

**Check:**
```powershell
# View current exclusions
.\Manage-ExclusionList.ps1 -View

# Remove incorrect entries
.\Manage-ExclusionList.ps1 -Remove WRONG-MACHINE

# Or clear all and start fresh
.\Manage-ExclusionList.ps1 -Clear
```

---

### **Issue: Exclusion File Missing**

**Solution:**
```powershell
# File is created automatically on first use
# Just add a machine and it will be created:
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT

# Or run collection once - file will be created
```

---

## 📋 Best Practices

### **1. Document Why Each Machine is Excluded**

**Good:**
```
# Linux systems
DEN-LINUX-01
PAR-UBUNTU-SRV

# Offline templates
TEMPLATE-WIN10
TEMPLATE-WIN11

# High-security - manual patching only
PROD-SQL-01
```

**Why:** Makes it clear why machines are excluded, easier to review

---

### **2. Regular Review**

**Schedule:** Quarterly review of exclusion list

**Check:**
- Are excluded machines still in AD?
- Can any be removed (WinRM enabled, etc.)?
- Are there new machines to add?

```powershell
# Review list
.\Manage-ExclusionList.ps1 -View

# Check if excluded machines still exist in AD
Get-Content "C:\PatchManagement\Config\ExcludedMachines.txt" | 
    Where-Object { $_.Trim() -and -not $_.StartsWith("#") } |
    ForEach-Object {
        $Exists = Get-ADComputer -Identity $_ -ErrorAction SilentlyContinue
        if (-not $Exists) {
            Write-Host "$_ - Not found in AD (consider removing)" -ForegroundColor Yellow
        } else {
            Write-Host "$_ - Still in AD" -ForegroundColor Green
        }
    }
```

---

### **3. Keep Exclusions Minimal**

**Goal:** Only exclude machines that genuinely can't be inventoried

**Don't Exclude:**
- Temporarily offline machines (they'll be skipped automatically)
- Machines you just don't want to patch yet (use deployment phases)
- Machines with temporary issues (fix the issue instead)

**Do Exclude:**
- Linux/Unix systems in AD
- Permanently disabled machines
- Templates never online
- Special-case systems

---

### **4. Monitor Exclusion Impact**

**Track:**
- Total machines in AD
- Machines excluded
- Percentage excluded

```powershell
# Count AD machines
$TotalAD = (Get-ADComputer -Filter {Enabled -eq $true} -SearchBase "OU=Workstations,OU=QBE,DC=qb-energy,DC=com").Count

# Count excluded
$Excluded = (Get-Content "C:\PatchManagement\Config\ExcludedMachines.txt" | 
    Where-Object { $_.Trim() -and -not $_.StartsWith("#") }).Count

# Calculate percentage
$Percentage = [math]::Round(($Excluded / $TotalAD) * 100, 1)

Write-Host "Total AD Machines: $TotalAD"
Write-Host "Excluded: $Excluded ($Percentage%)"
```

**Goal:** Keep exclusions under 5% of total machines

---

## 🎯 Summary

### **Key Points:**

- ✅ **Automatic Skip:** Excluded machines skipped during collection
- ✅ **Easy Management:** Simple script to add/remove/view
- ✅ **Smart Detection:** System hints when to add machines
- ✅ **File-Based:** Easy to edit, backup, and version control
- ✅ **Flexible:** Add individual machines or entire groups

---

### **Typical Workflow:**

1. **Run collection** → Get WinRM error
2. **System hints** → "Consider adding to exclusion list"
3. **Add machine** → `.\Manage-ExclusionList.ps1 -Add MACHINE`
4. **Run collection again** → Machine skipped automatically
5. **Review quarterly** → Remove machines no longer needed

---

### **Files Involved:**

```
C:\PatchManagement\
├── Config\
│   └── ExcludedMachines.txt  ← Exclusion list
└── Scripts\
    ├── Manage-ExclusionList.ps1  ← Management script
    └── PatchManagement-GUI.ps1  ← Updated with exclusion support
```

---

## 🚀 Quick Reference

### **Common Commands:**

```powershell
# Add machine
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT

# View list
.\Manage-ExclusionList.ps1 -View

# Remove machine
.\Manage-ExclusionList.ps1 -Remove DEN-6G11R74-LT

# Clear all
.\Manage-ExclusionList.ps1 -Clear
```

---

### **Quick Fix for Your Error:**

```powershell
# For DEN-6G11R74-LT WinRM error:
cd C:\PatchManagement\Scripts
.\Manage-ExclusionList.ps1 -Add DEN-6G11R74-LT
# Done! Future collections will skip this machine
```

---

**Document Version:** 1.0  
**Date:** January 21, 2026  
**System:** QB Energy Patch Management v2.1  
**Author:** Matt Haegele
