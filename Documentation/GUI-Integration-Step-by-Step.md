# GUI Integration Guide
## Add File-Based Updates to Deploy Tab - Step by Step

---

## 🎯 What You're Doing

**Adding file-based update deployment to your existing Deploy tab:**
- Browse update repository (\\QBE-DEN-WINUP1\UpdateFiles)
- List available .msu files
- Deploy selected update to computer
- Create USB packages for field machines

**Keeps all existing functionality:**
- Windows Update deployment still works
- Diagnose button still works
- Computer selection still works

---

## 📦 Files You Need

Before starting, ensure you have:
- [x] `File-Based-Update-Integration.ps1` (integration code)
- [x] `Deploy-FileBasedUpdate.ps1` (deployment script)
- [x] `Create-USBPackage.ps1` (USB package creator)
- [x] Updated `PatchConfig.psm1` (with repository path)

---

## 🚀 Step-by-Step Integration (15 Minutes)

### **Step 1: Backup Current GUI**

```powershell
cd C:\PatchManagement\Scripts

# Create backup
$Date = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item "PatchManagement-GUI.ps1" `
    -Destination "PatchManagement-GUI.ps1.BACKUP_$Date"

Write-Host "✓ Backup created: PatchManagement-GUI.ps1.BACKUP_$Date" -ForegroundColor Green
```

---

### **Step 2: Locate Insertion Point**

```powershell
# Open GUI file
notepad C:\PatchManagement\Scripts\PatchManagement-GUI.ps1

# OR use VS Code if available
code C:\PatchManagement\Scripts\PatchManagement-GUI.ps1
```

**Find the insertion point:**

Search for: `"Diagnose"` or `"Diagnose Windows Updates"`

You'll find code that looks like this (around line 110-130 in Deploy tab):

```powershell
# Diagnose button
$DiagnoseButton = New-Object System.Windows.Forms.Button
$DiagnoseButton.Location = New-Object System.Drawing.Point(360, 125)
$DiagnoseButton.Size = New-Object System.Drawing.Size(110, 35)
$DiagnoseButton.Text = "Diagnose"
$DiagnoseButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DiagnoseButton.BackColor = [System.Drawing.Color]::FromArgb(243, 156, 18)
$DiagnoseButton.ForeColor = [System.Drawing.Color]::White
$DiagnoseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($DiagnoseButton)

# ... Diagnose button event handler ...
# This code continues for ~20-30 lines

# ← INSERT FILE-BASED CODE HERE (after all Diagnose code)
```

---

### **Step 3: Insert Integration Code**

**Open** `File-Based-Update-Integration.ps1`

**Copy** the ENTIRE contents

**Paste** into `PatchManagement-GUI.ps1` immediately after the Diagnose button section

**Your Deploy tab structure should look like this:**

```
Deploy Tab:
├── [Title and computer selection - EXISTING]
├── [Deploy button - EXISTING]  
├── [Diagnose button - EXISTING]
│   └── Event handlers
├── [FILE-BASED UPDATE SECTION - NEW!] ← INSERTED HERE
│   ├── Repository path configuration
│   ├── Updates list view
│   ├── Action buttons
│   └── Event handlers
└── [Rest of Deploy tab - EXISTING]
```

---

### **Step 4: Verify Insertion**

**Check your GUI file now has:**

1. **Separator line** (around line 220):
```powershell
$FileSeparator = New-Object System.Windows.Forms.Label
$FileSeparator.Location = New-Object System.Drawing.Point(20, 220)
```

2. **Section title**:
```powershell
$FileBasedLabel = New-Object System.Windows.Forms.Label
$FileBasedLabel.Text = "File-Based Updates (WUSA)..."
```

3. **Repository textbox**:
```powershell
$RepoPathTextBox = New-Object System.Windows.Forms.TextBox
$RepoPathTextBox.Text = "\\QBE-DEN-WINUP1\UpdateFiles"
```

4. **ListView for updates**:
```powershell
$UpdatesListView = New-Object System.Windows.Forms.ListView
```

5. **Action buttons**:
```powershell
$DeployFileUpdateButton = New-Object System.Windows.Forms.Button
$CreateUSBButton = New-Object System.Windows.Forms.Button
```

6. **Event handlers** (at bottom of inserted code):
```powershell
# Browse Repository
$BrowseRepoButton.Add_Click({
    ...
})

# Deploy Selected Update
$DeployFileUpdateButton.Add_Click({
    ...
})
```

---

### **Step 5: Save GUI File**

```
File → Save
```

Or in VS Code: `Ctrl+S`

---

### **Step 6: Test Launch**

```powershell
cd C:\PatchManagement\Scripts

# Launch GUI
.\PatchManagement-GUI.ps1
```

**Expected Result:**
- GUI opens without errors
- Deploy tab loads
- New "File-Based Updates" section visible
- Repository path shows: `\\QBE-DEN-WINUP1\UpdateFiles`
- Buttons visible: Scan Updates, Deploy Selected, Create USB Package

**If errors:**
- Check for syntax errors (missing brackets, quotes)
- Verify insertion point was correct
- Restore backup and try again

---

## 🧪 Testing the Integration

### **Test 1: GUI Structure**

```
✓ Launch GUI
✓ Click Deploy tab
✓ Scroll down past Diagnose button
✓ See "File-Based Updates (WUSA)" section
✓ See repository path textbox
✓ See Scan Updates button
✓ See empty updates list
✓ See action buttons below
```

---

### **Test 2: Scan Repository**

```powershell
# First, ensure repository has at least one .msu file
# On WINUP1, put test file:
# \\QBE-DEN-WINUP1\UpdateFiles\Windows10\2026-01\KB5073457.msu
```

```
In GUI:
1. Click "Scan Updates" button
2. Status should show: "Scanning repository..."
3. Then: "Found X update(s)" (green)
4. Updates list populates with KB, Product, Month, Size
```

**If "No updates found":**
- Download .msu file from Microsoft Update Catalog
- Save to `\\QBE-DEN-WINUP1\UpdateFiles\Windows10\2026-01\`
- Click Scan Updates again

---

### **Test 3: Deploy Update**

```
In GUI:
1. Enter computer name: QBE-DEN-TSGW1 (in existing textbox at top)
2. Select an update from list (click to highlight)
3. Click "Deploy Selected Update"
4. Confirm deployment dialog appears
5. Click Yes
6. Status shows: "Deploying KB... to computer..."
7. Result: SUCCESS or FAILED with details
```

**Prerequisites:**
- Deploy-FileBasedUpdate.ps1 must be in Scripts folder
- Target computer must be online
- WinRM must be enabled on target

---

### **Test 4: Create USB Package**

```
In GUI:
1. Select an update from list
2. Click "Create USB Package"
3. Folder browser appears (default: C:\PatchManagement\USBPackages)
4. Click OK
5. Status shows: "Creating USB package..."
6. Success message with folder path
7. Explorer opens showing package folder
8. Folder contains: .msu file, INSTALL.bat, README.txt
```

---

### **Test 5: Browse Repository**

```
In GUI:
1. Click "Browse..." button next to repository path
2. Folder browser opens
3. Select different folder
4. Click OK
5. Repository path updates
6. Click Scan Updates
7. Lists updates from new location
```

---

### **Test 6: OS Filter**

```
In GUI:
1. Click Scan Updates (shows all updates)
2. Change filter dropdown: "All" → "Windows10"
3. List updates updates to show only Windows 10
4. Change to "Windows11" → shows only Windows 11
5. Change to "All" → shows everything again
```

---

## 🎨 What It Looks Like

```
┌─────────────────────────────────────────────────────────┐
│ Deploy Windows Updates                                   │
│                                                          │
│ Computer Name: [QBE-DEN-TSGW1        ] [Browse] [Deploy]│
│                                     [Diagnose]           │
│                                                          │
│ ──────────────────────────────────────────────────────  │ ← Separator
│                                                          │
│ File-Based Updates (WUSA) - For Field Machines...       │ ← NEW!
│                                                          │
│ Repository Path: [\\QBE-DEN-WINUP1\UpdateFiles]         │
│                  [Browse...] [Scan Updates]             │
│                                                          │
│ Available Updates:              Filter OS: [All     ▼]  │
│ ┌────────────────────────────────────────────────────┐  │
│ │ KB       │Product    │Month  │File     │Size │Date││  │
│ ├──────────┼───────────┼───────┼─────────┼─────┼────┤│  │
│ │KB5073457│Win 10 x64│2026-01│KB507...│487MB│2026││  │
│ │KB5073458│Win 11 x64│2026-01│KB507...│512MB│2026││  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ [Deploy Selected] [Create USB] [View Details] [Open]    │
│                                                          │
│ Status: Found 2 update(s)                               │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 Troubleshooting

### **Issue 1: GUI won't launch**

**Symptom:** Error when launching GUI

**Cause:** Syntax error in inserted code

**Fix:**
```powershell
# Restore backup
Copy-Item "PatchManagement-GUI.ps1.BACKUP_*" `
    -Destination "PatchManagement-GUI.ps1"

# Check for errors
Get-Content "PatchManagement-GUI.ps1" | Select-String "error"

# Try integration again, carefully check brackets and quotes
```

---

### **Issue 2: File-Based section doesn't appear**

**Symptom:** Deploy tab shows but no File-Based section

**Cause:** Code inserted in wrong location or not at all

**Fix:**
1. Search GUI file for `$FileSeparator`
2. If not found, code wasn't inserted
3. Re-insert File-Based-Update-Integration.ps1 code
4. Make sure it's in Deploy tab section, not another tab

---

### **Issue 3: "Script not found" error**

**Symptom:** Deploy button says "Deploy-FileBasedUpdate.ps1 not found"

**Cause:** Required scripts not in Scripts folder

**Fix:**
```powershell
# Verify scripts exist
cd C:\PatchManagement\Scripts
Test-Path .\Deploy-FileBasedUpdate.ps1
Test-Path .\Create-USBPackage.ps1

# If missing, copy from downloads
Copy-Item "C:\Users\$env:USERNAME\Downloads\Deploy-FileBasedUpdate.ps1" .
Copy-Item "C:\Users\$env:USERNAME\Downloads\Create-USBPackage.ps1" .
```

---

### **Issue 4: "Repository not found"**

**Symptom:** Scan Updates says "Cannot access repository"

**Cause:** WINUP1 repository not set up

**Fix:**
```powershell
# On QBE-DEN-WINUP1
.\Setup-FileBasedRepository.ps1

# Test from workstation
Test-Path "\\QBE-DEN-WINUP1\UpdateFiles"
```

---

### **Issue 5: Deploy fails**

**Symptom:** Deploy Selected Update shows FAILED

**Common Causes & Fixes:**

**Cause 1: Computer offline**
```
Fix: Test connectivity first
Test-Connection -ComputerName QBE-DEN-TSGW1
```

**Cause 2: WinRM not enabled**
```
Fix: On target computer:
Enable-PSRemoting -Force
```

**Cause 3: Wrong KB number**
```
Fix: Verify KB matches .msu file name
KB5073457.msu → KB = "KB5073457"
```

---

## ✅ Success Checklist

**Integration Complete:**
- [x] GUI file backed up
- [x] Integration code inserted
- [x] GUI launches without errors
- [x] Deploy tab shows File-Based section
- [x] Repository path configured
- [x] Scan Updates button works
- [x] Updates list populates
- [x] Deploy Selected works
- [x] Create USB Package works
- [x] All buttons functional

**Repository Ready:**
- [x] WINUP1 setup complete
- [x] \\QBE-DEN-WINUP1\UpdateFiles accessible
- [x] At least one .msu file present
- [x] GUI can scan and find updates

**Scripts Present:**
- [x] Deploy-FileBasedUpdate.ps1 in Scripts folder
- [x] Create-USBPackage.ps1 in Scripts folder
- [x] PatchConfig.psm1 updated
- [x] All scripts return correct objects

---

## 🎯 Final Test Sequence

**Run this complete test:**

```powershell
# 1. Launch GUI
cd C:\PatchManagement\Scripts
.\PatchManagement-GUI.ps1

# In GUI:
# 2. Click Deploy tab
# 3. Verify File-Based section visible
# 4. Click "Scan Updates"
# 5. Verify updates appear in list
# 6. Enter computer name: QBE-DEN-TSGW1
# 7. Select an update
# 8. Click "Deploy Selected Update"
# 9. Confirm deployment
# 10. Watch status - should show SUCCESS
# 11. Click "Create USB Package"
# 12. Verify package created
# 13. Check USB package contains .msu, INSTALL.bat, README.txt

# ✓ All tests passed = Integration successful!
```

---

## 📞 Quick Reference

### **Insertion Point:**
- After Diagnose button code
- Before next tab or event handlers section
- Approximately line 200-250 in Deploy tab

### **Key Variables:**
- `$RepoPathTextBox.Text` - Repository path
- `$UpdatesListView` - List of updates
- `$DeployFileUpdateButton` - Deploy button
- `$CreateUSBButton` - USB package button

### **Required Scripts:**
- `Deploy-FileBasedUpdate.ps1`
- `Create-USBPackage.ps1`
- `PatchConfig.psm1` (updated)

### **Repository Path:**
- Default: `\\QBE-DEN-WINUP1\UpdateFiles`
- Configurable via Browse button

---

## 🎉 You're Done!

**Integration complete when:**
1. ✅ GUI launches with File-Based section
2. ✅ Can scan repository for updates
3. ✅ Can select and deploy update
4. ✅ Can create USB package
5. ✅ All existing functionality still works

**Now you have:**
- Network deployment for connected machines
- USB deployment for field machines
- No WSUS complexity!
- Perfect for your remote locations!

---

**Need help? Check Required-Scripts-Final-Checklist.md for detailed script requirements!** 📚
