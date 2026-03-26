# Required Scripts for Patch Management System
## File-Based Update Integration

---

## 📁 Scripts Folder Structure

```
C:\PatchManagement\Scripts\
├── PatchManagement-GUI.ps1           ← Main GUI (updated with new Deploy tab)
├── Deploy-FileBasedUpdate.ps1        ← Deploy .msu to single computer
├── Deploy-UpdateBatch.ps1            ← Deploy .msu to multiple computers  
├── Get-AvailableUpdates.ps1          ← List updates in repository
├── Create-USBPackage.ps1             ← Create USB deployment package
├── Test-ComputerConnectivity.ps1     ← Test if computers are online
├── Get-InstalledUpdates.ps1          ← Check what's installed
├── PatchConfig.psm1                  ← Configuration module
└── [existing scripts...]
```

---

## 📋 Required Scripts

### **1. Deploy-FileBasedUpdate.ps1** ⭐ CRITICAL

**Purpose:** Deploy .msu file to a single computer using WUSA

**Parameters:**
- `ComputerName` - Target computer
- `UpdatePath` - Path to .msu file  
- `AutoReboot` - Auto-reboot after install
- `RebootDelayMinutes` - Delay before reboot

**Location:** C:\PatchManagement\Scripts\

**Used By:** GUI Deploy button (single computer)

**Example:**
```powershell
.\Deploy-FileBasedUpdate.ps1 `
    -ComputerName "QBE-DEN-TSGW1" `
    -UpdatePath "\\QBE-DEN-WINUP1\UpdateFiles\Windows10\2026-01\KB5073457.msu" `
    -AutoReboot
```

---

### **2. Deploy-UpdateBatch.ps1** ⭐ CRITICAL

**Purpose:** Deploy .msu to multiple computers in batch

**Parameters:**
- `UpdatePath` - Path to .msu file
- `ComputerNames` - Array of computer names
- `AutoReboot` - Auto-reboot after install

**Location:** C:\PatchManagement\Scripts\

**Used By:** GUI Deploy button (multiple computers)

**Example:**
```powershell
.\Deploy-UpdateBatch.ps1 `
    -UpdatePath "\\QBE-DEN-WINUP1\UpdateFiles\Windows10\2026-01\KB5073457.msu" `
    -ComputerNames "PC1","PC2","PC3"
```

**Creates:** Deployment log CSV in C:\PatchManagement\Logs\

---

### **3. Get-AvailableUpdates.ps1** ⭐ CRITICAL

**Purpose:** Scan repository and list available .msu files

**Parameters:**
- `RepositoryPath` - Path to update repository
- `OS` - Filter by OS (All, Windows10, Windows11, etc.)
- `Month` - Filter by month
- `ExportToCSV` - Export results

**Location:** C:\PatchManagement\Scripts\

**Used By:** GUI Refresh Updates button

**Returns:** Array of update objects with KB, OS, Month, Path, Size

**Example:**
```powershell
$Updates = .\Get-AvailableUpdates.ps1 -RepositoryPath "\\QBE-DEN-WINUP1\UpdateFiles"

# Output:
# KB5073457 [Win10] [2026-01] (487 MB)
# KB5073458 [Win11] [2026-01] (512 MB)
```

---

### **4. Create-USBPackage.ps1** ⭐ CRITICAL

**Purpose:** Create USB deployment package with .msu files and INSTALL.bat

**Parameters:**
- `KBNumbers` - Array of KB numbers to include
- `Product` - OS type (Windows10, Windows11, etc.)
- `OutputPath` - Where to create package

**Location:** C:\PatchManagement\Scripts\

**Used By:** GUI Create USB Package button

**Creates:**
- Folder with selected .msu files
- INSTALL.bat for offline installation
- README.txt with instructions

**Example:**
```powershell
.\Create-USBPackage.ps1 `
    -KBNumbers "KB5073457","KB5073458" `
    -Product "Windows10" `
    -OutputPath "D:\USBPackages"
```

---

### **5. Test-ComputerConnectivity.ps1**

**Purpose:** Test if computers are online and reachable

**Parameters:**
- `ComputerNames` - Array of computer names

**Location:** C:\PatchManagement\Scripts\

**Used By:** GUI Test Connectivity button

**Returns:** List of online/offline computers

**Example:**
```powershell
.\Test-ComputerConnectivity.ps1 -ComputerNames "PC1","PC2","PC3"

# Output:
# PC1: Online
# PC2: Offline
# PC3: Online
```

---

### **6. Get-InstalledUpdates.ps1**

**Purpose:** Check what updates are installed on a computer

**Parameters:**
- `ComputerName` - Target computer
- `KB` - Specific KB to check (optional)

**Location:** C:\PatchManagement\Scripts\

**Used By:** GUI and verification scripts

**Returns:** List of installed updates (KB numbers)

**Example:**
```powershell
.\Get-InstalledUpdates.ps1 -ComputerName "QBE-DEN-TSGW1"

# Output:
# KB5073457 - Installed on 2026-01-15
# KB5073458 - Installed on 2026-01-16
```

---

### **7. PatchConfig.psm1**

**Purpose:** Configuration module with paths and settings

**Contains:**
- Repository paths
- OU lists
- Log locations
- Default settings

**Location:** C:\PatchManagement\Scripts\

**Used By:** All scripts and GUI

**Example:**
```powershell
Import-Module .\PatchConfig.psm1

$Config = Get-PatchConfig
$Config.RepositoryPath  # \\QBE-DEN-WINUP1\UpdateFiles
$Config.LogPath         # C:\PatchManagement\Logs
```

---

### **8. PatchManagement-GUI.ps1**

**Purpose:** Main GUI application (updated with new Deploy tab)

**Location:** C:\PatchManagement\Scripts\

**Runs:** All other scripts based on user actions

---

## 🔧 Helper Scripts (Optional but Recommended)

### **9. Get-DeploymentHistory.ps1**

**Purpose:** View deployment logs and history

**Parameters:**
- `Days` - How many days back to check
- `ComputerName` - Filter by computer
- `KB` - Filter by KB

---

### **10. Rollback-Update.ps1**

**Purpose:** Uninstall an update using WUSA

**Parameters:**
- `ComputerName` - Target computer
- `KB` - KB number to remove

**Example:**
```powershell
.\Rollback-Update.ps1 -ComputerName "QBE-DEN-TSGW1" -KB "KB5073457"
```

---

### **11. Sync-RepositoryToParis.ps1**

**Purpose:** Sync update files from Denver to Paris

**Parameters:**
- `SourcePath` - Denver repository
- `DestinationPath` - Paris location

**Example:**
```powershell
.\Sync-RepositoryToParis.ps1 `
    -SourcePath "\\QBE-DEN-WINUP1\UpdateFiles" `
    -DestinationPath "\\QBE-PAR-FILE1\UpdateFiles"
```

---

## 📦 Deployment Package

All scripts bundled in: **Deploy-FileBasedScripts.ps1**

This script:
1. Checks for existing scripts
2. Creates backups
3. Copies all new scripts to C:\PatchManagement\Scripts\
4. Updates PatchManagement-GUI.ps1 with new Deploy tab
5. Verifies installation

**Run once to deploy all scripts:**
```powershell
.\Deploy-FileBasedScripts.ps1
```

---

## ✅ Installation Checklist

**On Management Workstation:**
- [ ] C:\PatchManagement\Scripts\ exists
- [ ] Deploy-FileBasedUpdate.ps1 present
- [ ] Deploy-UpdateBatch.ps1 present
- [ ] Get-AvailableUpdates.ps1 present
- [ ] Create-USBPackage.ps1 present
- [ ] Test-ComputerConnectivity.ps1 present
- [ ] Get-InstalledUpdates.ps1 present
- [ ] PatchConfig.psm1 present (updated with repository path)
- [ ] PatchManagement-GUI.ps1 updated with new Deploy tab
- [ ] Logs folder exists: C:\PatchManagement\Logs\
- [ ] USBPackages folder exists: C:\PatchManagement\USBPackages\

**On WINUP1:**
- [ ] D:\UpdateFiles\ created
- [ ] Network share created: \\QBE-DEN-WINUP1\UpdateFiles
- [ ] Permissions set (Domain Users: Read, Admins: Full)
- [ ] Monthly folders created for current year
- [ ] At least one .msu file downloaded for testing

**Testing:**
- [ ] GUI launches without errors
- [ ] Deploy tab loads
- [ ] Refresh Updates finds .msu files
- [ ] Can select update
- [ ] Can select target computer
- [ ] Test Connectivity works
- [ ] Deploy Update works (test machine)
- [ ] Create USB Package works
- [ ] USB package installs on field machine

---

## 🔄 Update Process

**Monthly:**
1. Download new .msu files to WINUP1
2. Refresh Updates in GUI
3. Test on pilot machine
4. Deploy to production
5. Create USB packages for field

**When GUI needs update:**
1. Run Deploy-FileBasedScripts.ps1
2. Overwrites with latest scripts
3. Backs up existing files
4. Verifies deployment

---

## 🎯 Critical Files Summary

| File | Location | Purpose | Required? |
|------|----------|---------|-----------|
| Deploy-FileBasedUpdate.ps1 | Scripts\ | Single deploy | ✅ YES |
| Deploy-UpdateBatch.ps1 | Scripts\ | Batch deploy | ✅ YES |
| Get-AvailableUpdates.ps1 | Scripts\ | List updates | ✅ YES |
| Create-USBPackage.ps1 | Scripts\ | USB packages | ✅ YES |
| Test-ComputerConnectivity.ps1 | Scripts\ | Test online | Recommended |
| Get-InstalledUpdates.ps1 | Scripts\ | Check installed | Recommended |
| PatchConfig.psm1 | Scripts\ | Configuration | ✅ YES |
| PatchManagement-GUI.ps1 | Scripts\ | Main GUI | ✅ YES |

---

## 📞 Quick Commands

### **Deploy All Scripts:**
```powershell
cd C:\Users\$env:USERNAME\Downloads
.\Deploy-FileBasedScripts.ps1
```

### **Test Installation:**
```powershell
cd C:\PatchManagement\Scripts

# Test each critical script
Test-Path .\Deploy-FileBasedUpdate.ps1
Test-Path .\Deploy-UpdateBatch.ps1
Test-Path .\Get-AvailableUpdates.ps1
Test-Path .\Create-USBPackage.ps1
Test-Path .\PatchConfig.psm1

# Launch GUI
.\PatchManagement-GUI.ps1
```

### **Verify Repository Access:**
```powershell
Test-Path "\\QBE-DEN-WINUP1\UpdateFiles"
Get-ChildItem "\\QBE-DEN-WINUP1\UpdateFiles\*\*\*.msu"
```

---

## ✅ Success Criteria

Your installation is complete when:
1. All 8 critical scripts are in C:\PatchManagement\Scripts\
2. GUI launches and Deploy tab shows File-Based options
3. Refresh Updates finds .msu files in repository
4. Can deploy to test machine successfully
5. Can create USB package
6. Deployment logs appear in Logs folder

---

**Next Step: Run Deploy-FileBasedScripts.ps1 to install everything!** 🚀
