# Required Scripts Checklist
## File-Based Update System for Patch Management GUI

---

## 📁 Directory Structure

```
C:\PatchManagement\
├── Scripts\
│   ├── PatchManagement-GUI.ps1              ← Main GUI (UPDATE with integration code)
│   ├── Deploy-FileBasedUpdate.ps1           ← Deploy .msu to single computer ⭐ REQUIRED
│   ├── Deploy-UpdateBatch.ps1               ← Deploy .msu to multiple computers
│   ├── Get-AvailableUpdates.ps1             ← Scan repository for .msu files
│   ├── Create-USBPackage.ps1                ← Create USB deployment packages ⭐ REQUIRED
│   ├── Test-ComputerConnectivity.ps1        ← Test if computers are online
│   ├── Get-InstalledUpdates.ps1             ← Check what's installed
│   ├── PatchConfig.psm1                     ← Configuration module (UPDATE)
│   └── [your existing scripts]
├── Logs\                                     ← Deployment logs (AUTO-CREATED)
├── USBPackages\                              ← USB packages output (AUTO-CREATED)
└── Backup\                                   ← Script backups (AUTO-CREATED)
```

---

## ✅ Required Scripts (Must Have)

### **1. Deploy-FileBasedUpdate.ps1** ⭐ CRITICAL

**Purpose:** Deploy single .msu file to a computer using WUSA

**Parameters:**
- `-ComputerName` - Target computer name
- `-KB` - KB number (e.g., "KB5073457")
- `-UpdatePath` - Full path to .msu file
- `-AutoReboot` - Optional: Auto-reboot after install
- `-RebootDelayMinutes` - Optional: Delay before reboot

**Location:** `C:\PatchManagement\Scripts\Deploy-FileBasedUpdate.ps1`

**Used By:** GUI "Deploy Selected Update" button

**Must return:** Object with `.Success` and `.RebootRequired` properties

**Example:**
```powershell
.\Deploy-FileBasedUpdate.ps1 `
    -ComputerName "QBE-DEN-TSGW1" `
    -KB "KB5073457" `
    -UpdatePath "\\QBE-DEN-WINUP1\UpdateFiles\Windows10\2026-01\KB5073457.msu"
```

**Returns:**
```powershell
[PSCustomObject]@{
    Success = $true
    RebootRequired = $true
    ExitCode = 3010
    Error = ""
}
```

---

### **2. Create-USBPackage.ps1** ⭐ CRITICAL

**Purpose:** Create USB deployment package with .msu and INSTALL.bat

**Parameters:**
- `-UpdatePaths` - Array of .msu file paths
- `-OutputPath` - Where to create package
- `-PackageName` - Optional package name

**Location:** `C:\PatchManagement\Scripts\Create-USBPackage.ps1`

**Used By:** GUI "Create USB Package" button

**Creates:**
- Package folder with .msu files
- INSTALL.bat (auto-installer)
- README.txt (instructions)

**Example:**
```powershell
.\Create-USBPackage.ps1 `
    -UpdatePaths @("\\WINUP1\UpdateFiles\Windows10\2026-01\KB5073457.msu") `
    -OutputPath "C:\PatchManagement\USBPackages"
```

---

### **3. PatchConfig.psm1** ⭐ CRITICAL (UPDATE EXISTING)

**Purpose:** Configuration module with repository paths

**Must Include:**
```powershell
function Get-PatchConfig {
    $Config = @{
        BaseDirectory = "C:\PatchManagement"
        RepositoryPath = "\\QBE-DEN-WINUP1\UpdateFiles"  # ADD THIS
        USBPackagePath = "C:\PatchManagement\USBPackages"  # ADD THIS
        LogPath = "C:\PatchManagement\Logs"  # ADD THIS
        InventoryShare = "\\QBE-DEN-FILE4\inventory"
        OUs = @(
            "OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com"
        )
    }
    
    return [PSCustomObject]$Config
}

Export-ModuleMember -Function Get-PatchConfig
```

**Location:** `C:\PatchManagement\Scripts\PatchConfig.psm1`

**Used By:** All scripts and GUI

---

### **4. PatchManagement-GUI.ps1** ⭐ CRITICAL (UPDATE EXISTING)

**Purpose:** Main GUI - needs file-based integration code added

**Location:** `C:\PatchManagement\Scripts\PatchManagement-GUI.ps1`

**Changes Needed:**
1. Add file-based update section to Deploy tab (after line ~360)
2. Insert code from `File-Based-Update-Integration.ps1`
3. Keep all existing functionality intact

---

## 📋 Recommended Scripts (Optional but Useful)

### **5. Deploy-UpdateBatch.ps1**

**Purpose:** Deploy to multiple computers in batch

**Parameters:**
- `-UpdatePath` - Path to .msu file
- `-ComputerNames` - Array of computer names
- `-AutoReboot` - Optional auto-reboot

**Location:** `C:\PatchManagement\Scripts\Deploy-UpdateBatch.ps1`

**Used By:** Future batch deployment features

---

### **6. Get-AvailableUpdates.ps1**

**Purpose:** Scan repository and list .msu files (alternative to inline function)

**Parameters:**
- `-RepositoryPath` - Repository path
- `-OS` - OS filter
- `-ExportToCSV` - Optional export

**Location:** `C:\PatchManagement\Scripts\Get-AvailableUpdates.ps1`

**Used By:** Command-line repository queries

---

### **7. Test-ComputerConnectivity.ps1**

**Purpose:** Test if computers are online

**Parameters:**
- `-ComputerNames` - Array of computer names

**Location:** `C:\PatchManagement\Scripts\Test-ComputerConnectivity.ps1`

**Used By:** Pre-deployment validation

---

### **8. Get-InstalledUpdates.ps1**

**Purpose:** Check what updates are installed on a computer

**Parameters:**
- `-ComputerName` - Target computer
- `-KB` - Optional specific KB to check

**Location:** `C:\PatchManagement\Scripts\Get-InstalledUpdates.ps1`

**Used By:** Post-deployment verification

---

## 🚀 Quick Installation

### **Method 1: Automated (Easiest)**

```powershell
cd C:\Users\$env:USERNAME\Downloads

# Run master deployment script
.\Deploy-FileBasedScripts.ps1

# This will:
# 1. Backup existing files
# 2. Copy all scripts to C:\PatchManagement\Scripts\
# 3. Update PatchConfig.psm1
# 4. Create necessary folders
# 5. Create test script
```

---

### **Method 2: Manual**

```powershell
# 1. Copy scripts to folder
Copy-Item .\Deploy-FileBasedUpdate.ps1 -Destination "C:\PatchManagement\Scripts\"
Copy-Item .\Create-USBPackage.ps1 -Destination "C:\PatchManagement\Scripts\"
Copy-Item .\Test-ComputerConnectivity.ps1 -Destination "C:\PatchManagement\Scripts\"
Copy-Item .\Get-InstalledUpdates.ps1 -Destination "C:\PatchManagement\Scripts\"

# 2. Update PatchConfig.psm1
# Add RepositoryPath, USBPackagePath, LogPath

# 3. Create folders
New-Item -Path "C:\PatchManagement\Logs" -ItemType Directory -Force
New-Item -Path "C:\PatchManagement\USBPackages" -ItemType Directory -Force

# 4. Update GUI
# Insert File-Based-Update-Integration.ps1 code into PatchManagement-GUI.ps1
```

---

## ✅ Verification Checklist

### **Scripts Present:**
```powershell
cd C:\PatchManagement\Scripts

# Check required scripts
Test-Path .\Deploy-FileBasedUpdate.ps1
Test-Path .\Create-USBPackage.ps1
Test-Path .\PatchConfig.psm1

# Check optional scripts
Test-Path .\Deploy-UpdateBatch.ps1
Test-Path .\Get-AvailableUpdates.ps1
Test-Path .\Test-ComputerConnectivity.ps1
Test-Path .\Get-InstalledUpdates.ps1
```

### **Folders Present:**
```powershell
Test-Path "C:\PatchManagement\Logs"
Test-Path "C:\PatchManagement\USBPackages"
```

### **Config Updated:**
```powershell
Import-Module .\PatchConfig.psm1 -Force
$Config = Get-PatchConfig

# Should show:
$Config.RepositoryPath    # \\QBE-DEN-WINUP1\UpdateFiles
$Config.USBPackagePath    # C:\PatchManagement\USBPackages
$Config.LogPath           # C:\PatchManagement\Logs
```

### **GUI Updated:**
```powershell
# Launch GUI
.\PatchManagement-GUI.ps1

# Verify:
# 1. Deploy tab loads
# 2. File-Based Update section visible
# 3. Repository path shows: \\QBE-DEN-WINUP1\UpdateFiles
# 4. Buttons present: Scan Updates, Deploy Selected, Create USB Package
```

---

## 🧪 Testing

### **Test 1: Script Presence**
```powershell
cd C:\PatchManagement\Scripts
.\Test-FileBasedInstallation.ps1

# Expected: All ✓ green checkmarks
```

### **Test 2: Repository Access**
```powershell
Test-Path "\\QBE-DEN-WINUP1\UpdateFiles"

# Expected: True
```

### **Test 3: GUI Launches**
```powershell
.\PatchManagement-GUI.ps1

# Expected: GUI opens without errors
# File-Based section visible in Deploy tab
```

### **Test 4: Scan Repository**
```
In GUI:
1. Click Deploy tab
2. Click "Scan Updates"
3. Should list .msu files if any exist in repository
```

### **Test 5: Create USB Package**
```
In GUI:
1. Select an update
2. Click "Create USB Package"
3. Should create folder in C:\PatchManagement\USBPackages\
4. Folder should contain .msu, INSTALL.bat, README.txt
```

---

## 📊 Script Dependencies

```
PatchManagement-GUI.ps1
    ↓ calls
    Deploy-FileBasedUpdate.ps1
        ↓ uses
        PatchConfig.psm1
    ↓ calls
    Create-USBPackage.ps1
        ↓ uses
        PatchConfig.psm1
```

**Key Point:** `PatchConfig.psm1` must have repository paths defined!

---

## 🔧 Troubleshooting

### **Issue: "Script not found"**
```
Symptom: GUI says Deploy-FileBasedUpdate.ps1 not found

Fix:
1. Verify script exists:
   Test-Path "C:\PatchManagement\Scripts\Deploy-FileBasedUpdate.ps1"

2. If missing, copy from downloads:
   Copy-Item ".\Deploy-FileBasedUpdate.ps1" `
       -Destination "C:\PatchManagement\Scripts\"
```

### **Issue: "Repository not accessible"**
```
Symptom: Cannot access \\QBE-DEN-WINUP1\UpdateFiles

Fix:
1. On WINUP1, run: Setup-FileBasedRepository.ps1
2. Verify share created: Get-SmbShare -Name "UpdateFiles"
3. Test from workstation: Test-Path "\\QBE-DEN-WINUP1\UpdateFiles"
```

### **Issue: GUI section doesn't appear**
```
Symptom: File-Based section missing from Deploy tab

Fix:
1. Backup GUI: 
   Copy-Item "PatchManagement-GUI.ps1" -Destination "PatchManagement-GUI.ps1.BACKUP"
   
2. Open PatchManagement-GUI.ps1
3. Find Deploy tab section (line ~310-400)
4. Insert File-Based-Update-Integration.ps1 code after existing content
5. Save and test
```

---

## 🎯 Success Criteria

Your installation is complete when:

**Files:**
- [x] Deploy-FileBasedUpdate.ps1 in Scripts folder
- [x] Create-USBPackage.ps1 in Scripts folder
- [x] PatchConfig.psm1 updated with repository paths
- [x] PatchManagement-GUI.ps1 updated with integration code

**Folders:**
- [x] C:\PatchManagement\Logs\ exists
- [x] C:\PatchManagement\USBPackages\ exists

**Functionality:**
- [x] GUI launches without errors
- [x] Deploy tab shows File-Based section
- [x] Can browse repository
- [x] Can scan for updates
- [x] Can select and deploy update
- [x] Can create USB package

**Repository:**
- [x] \\QBE-DEN-WINUP1\UpdateFiles accessible
- [x] At least one .msu file for testing
- [x] GUI can scan and find updates

---

## 📞 Quick Commands

### **Install All Scripts:**
```powershell
.\Deploy-FileBasedScripts.ps1
```

### **Test Installation:**
```powershell
cd C:\PatchManagement\Scripts
.\Test-FileBasedInstallation.ps1
```

### **Launch GUI:**
```powershell
.\PatchManagement-GUI.ps1
```

### **Verify Config:**
```powershell
Import-Module .\PatchConfig.psm1 -Force
Get-PatchConfig
```

---

## 📋 Summary

**Minimum Required (3 files):**
1. ✅ Deploy-FileBasedUpdate.ps1
2. ✅ Create-USBPackage.ps1
3. ✅ PatchConfig.psm1 (updated)
4. ✅ PatchManagement-GUI.ps1 (updated)

**Recommended (4 files):**
5. Deploy-UpdateBatch.ps1
6. Get-AvailableUpdates.ps1
7. Test-ComputerConnectivity.ps1
8. Get-InstalledUpdates.ps1

**Total: 8 files to add/update**

---

**Ready to install? Run `.\Deploy-FileBasedScripts.ps1` to deploy everything automatically!** 🚀
