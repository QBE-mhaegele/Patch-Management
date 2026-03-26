# Installation Guide
## QB Energy Patch Management System v3.0

---

## Prerequisites

### Server Requirements
- Windows Server 2019 or 2022
- PowerShell 5.1 or later
- Domain-joined to QB-ENERGY
- Administrator access
- Minimum 4GB RAM, 50GB free disk space

### Network Requirements
- Access to all target machines (WinRM)
- Access to network shares:
  - `\\QBE-DEN-FILE4\inventory`
  - `\\QBE-DEN-WINUP1\Updatefiles`
- Internet access (for CVE data download)

### Account Requirements
- Domain account with:
  - Local admin on target machines (for WinRM)
  - Read/Write to inventory share
  - Read from update repository

---

## Step 1: Create Directory Structure

```powershell
# Run as Administrator

# Create base directory
$BaseDir = "C:\PatchManagement"
New-Item -Path $BaseDir -ItemType Directory -Force

# Create subdirectories
$Subdirs = @("Scripts", "Config", "Analysis", "Logs", "Data")
foreach ($Dir in $Subdirs) {
    New-Item -Path "$BaseDir\$Dir" -ItemType Directory -Force
}

# Verify structure
Get-ChildItem $BaseDir
```

Expected output:
```
Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d-----        2/3/2026   2:30 PM                Analysis
d-----        2/3/2026   2:30 PM                Config
d-----        2/3/2026   2:30 PM                Data
d-----        2/3/2026   2:30 PM                Logs
d-----        2/3/2026   2:30 PM                Scripts
```

---

## Step 2: Copy Script Files

Copy all script files to `C:\PatchManagement\Scripts\`:

### Required Files
| File | Purpose |
|------|---------|
| `PatchManagement-GUI.ps1` | Main GUI application |
| `Invoke-RiskAnalysis.ps1` | Risk analysis engine |
| `Get-MicrosoftPatches.ps1` | CVE data collector |
| `PatchConfig.psm1` | Configuration module |

### Optional Files
| File | Purpose |
|------|---------|
| `IntuneIntegration.psm1` | Intune connectivity |
| `Schedule-Collection.ps1` | Scheduled task setup |

---

## Step 3: Install PowerShell Modules

```powershell
# Run as Administrator

# Set execution policy
Set-ExecutionPolicy RemoteSigned -Force

# For Intune integration (optional)
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser -Force
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force

# For Windows Update management (optional)
Install-Module PSWindowsUpdate -Scope CurrentUser -Force

# Verify installations
Get-Module -ListAvailable Microsoft.Graph*, PSWindowsUpdate
```

---

## Step 4: Configure Network Shares

### Verify Inventory Share
```powershell
# Test access to inventory share
$InventoryShare = "\\QBE-DEN-FILE4\inventory"
Test-Path $InventoryShare

# Create OU subfolders if needed
$OUs = @("Denver-Servers", "Denver-Workstations", "Paris-Servers", "Parachute-Servers")
foreach ($OU in $OUs) {
    $Path = Join-Path $InventoryShare $OU
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force
    }
}

# Create MSU config folder
New-Item -Path "$InventoryShare\MSU" -ItemType Directory -Force
```

### Verify Update Repository
```powershell
# Test access to update repository
$MSUShare = "\\QBE-DEN-WINUP1\Updatefiles"
Test-Path $MSUShare

# List available updates
Get-ChildItem $MSUShare -Recurse -Include *.msu, *.cab, *.exe | 
    Select-Object Name, Length, LastWriteTime
```

---

## Step 5: Configure WinRM on Targets

Target machines must have WinRM enabled for remote inventory collection.

### Enable via Group Policy (Recommended)
```
Computer Configuration
  → Administrative Templates
    → Windows Components
      → Windows Remote Management (WinRM)
        → WinRM Service
          → Allow remote server management through WinRM: Enabled
          → IPv4 filter: * (or your subnet)
```

### Enable Manually (Single Machine)
```powershell
# Run on target machine as Administrator
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

### Test Connectivity
```powershell
# From management server
$TestPC = "DEN-SERVER01"
Test-WSMan -ComputerName $TestPC
Invoke-Command -ComputerName $TestPC -ScriptBlock { hostname }
```

---

## Step 6: First Run

### Launch the GUI
```powershell
# Run as Administrator
C:\PatchManagement\Scripts\PatchManagement-GUI.ps1
```

### Initial Configuration
1. Go to **Settings** tab
2. Verify all paths are correct
3. Add or verify target OUs
4. Add any machine exclusions
5. Click **Save Settings**

### First Collection
1. Go to **Dashboard** tab
2. Click **Run Collection**
3. Wait for collection to complete (20-45 minutes)
4. Verify inventory files are created

### First Analysis
1. Click **Run Analysis**
2. Wait for analysis to complete
3. Click **View HTML Report**
4. Verify machines appear correctly

---

## Step 7: Create Scheduled Task (Optional)

Automate daily collection:

```powershell
# Create scheduled task for daily collection at 6 AM
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\PatchManagement\Scripts\Schedule-Collection.ps1"

$Trigger = New-ScheduledTaskTrigger -Daily -At "06:00"

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "PatchManagement-DailyCollection" `
    -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
```

---

## Step 8: Configure Intune (Optional)

If using Intune integration:

1. Go to **Intune** tab
2. Enter Tenant ID: `41643dbd-bb87-47a6-a3b9-83642bbeba77`
3. Enter Tenant Name: `QB ENERGY`
4. Click **Connect to Intune**
5. Authenticate in browser when prompted
6. Click **Save Config**

See [Intune Guide](04-Intune-Guide.md) for detailed setup.

---

## Verification Checklist

After installation, verify:

- [ ] GUI launches without errors
- [ ] Settings tab shows correct paths
- [ ] Collection completes successfully
- [ ] Inventory files appear in share
- [ ] Analysis generates HTML report
- [ ] Report opens in browser
- [ ] MSU tab can scan for updates
- [ ] Intune tab connects (if configured)

---

## File Locations Summary

| Component | Location |
|-----------|----------|
| Scripts | `C:\PatchManagement\Scripts\` |
| Configuration | `C:\PatchManagement\Config\` |
| Analysis Reports | `C:\PatchManagement\Analysis\` |
| Log Files | `C:\PatchManagement\Logs\` |
| CVE Data | `C:\PatchManagement\Data\` |
| Inventory Data | `\\QBE-DEN-FILE4\inventory\` |
| Update Files | `\\QBE-DEN-WINUP1\Updatefiles\` |

---

## Troubleshooting Installation

### GUI Won't Launch
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set if needed
Set-ExecutionPolicy RemoteSigned -Force

# Check for errors
& "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"
```

### "Module not found" Errors
```powershell
# Reimport modules
Import-Module ActiveDirectory
Import-Module "$env:PatchManagement\Scripts\PatchConfig.psm1" -Force
```

### Can't Access Network Shares
```powershell
# Test with explicit credentials
$Cred = Get-Credential
New-PSDrive -Name "Test" -PSProvider FileSystem -Root "\\QBE-DEN-FILE4\inventory" -Credential $Cred
```

---

## Upgrading from Previous Version

1. Backup current configuration:
   ```powershell
   Copy-Item C:\PatchManagement\Config\* C:\PatchManagement\Backup\ -Recurse
   ```

2. Copy new script files (overwrite existing)

3. Launch GUI and verify settings

4. Re-run collection and analysis

---

## Uninstallation

To remove the system:

```powershell
# Remove scheduled tasks
Unregister-ScheduledTask -TaskName "PatchManagement-*" -Confirm:$false

# Backup configuration (optional)
Copy-Item C:\PatchManagement\Config\* C:\Backup\

# Remove local files
Remove-Item C:\PatchManagement -Recurse -Force

# Note: Inventory data on network share is preserved
```

---

## Support

For installation issues:
1. Check the [Troubleshooting Guide](07-Troubleshooting.md)
2. Review log files in `C:\PatchManagement\Logs\`
3. Contact IT Infrastructure team

---

**Document Version**: 3.0  
**Last Updated**: February 2026
