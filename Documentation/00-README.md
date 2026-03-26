# QB Energy Patch Management System v3.0
## Complete User Guide & Documentation

---

## 📋 System Overview

The QB Energy Patch Management System provides comprehensive Windows Update management across your organization through:

- **Dashboard** - Collection, analysis, and risk scoring of all machines
- **KB Warnings** - Track problematic updates and hardware compatibility issues  
- **MSU Updates** - Deploy standalone update packages (.msu, .cab, .exe) to servers
- **Intune** - Manage cloud-enrolled devices via Microsoft Endpoint Manager
- **Settings** - Configure paths, credentials, and system options

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              QB Energy Patch Management GUI                  │
│                    (PatchManagement-GUI.ps1)                 │
├─────────────────────────────────────────────────────────────┤
│  Dashboard  │  KB Warnings  │  MSU Updates  │  Intune       │
└─────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Inventory  │ │  Risk Data  │ │  MSU Files  │ │ Graph API   │
│  Collection │ │  Analysis   │ │  WUSA/DISM  │ │ Device Mgmt │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│       \\qbe-den-qnap\File4\Inventory (Network Share)         │
│    Inventory Data │ Analysis Reports │ Configuration        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Quick Start

### First Time Setup
1. Copy all files to `C:\PatchManagement\Scripts\`
2. Run `PatchManagement-GUI.ps1` as Administrator
3. Go to **Settings** tab and verify paths
4. Click **Run Collection** to gather initial inventory
5. Click **Run Analysis** to generate risk report

### Daily/Weekly Operations
1. **Run Collection** - Update inventory from all machines
2. **Run Analysis** - Generate updated risk scores
3. **View HTML Report** - Review machines needing attention

### Monthly Patch Tuesday Workflow
1. Run Collection before Patch Tuesday
2. Run Analysis after patches are released
3. Review KB Warnings for problematic updates
4. Deploy via MSU Updates tab or Intune rings

---

## 📚 Documentation Files

| Document | Tab/Feature | Description |
|----------|-------------|-------------|
| [01-Dashboard-Guide.md](01-Dashboard-Guide.md) | Dashboard | Collection, analysis, reporting |
| [02-KB-Warnings-Guide.md](02-KB-Warnings-Guide.md) | KB Warnings | Managing problematic updates |
| [03-MSU-Updates-Guide.md](03-MSU-Updates-Guide.md) | MSU Updates | Deploying standalone packages |
| [04-Intune-Guide.md](04-Intune-Guide.md) | Intune | Cloud device management |
| [05-Settings-Guide.md](05-Settings-Guide.md) | Settings | Configuration options |
| [06-Installation-Guide.md](06-Installation-Guide.md) | Setup | Initial installation steps |
| [07-Troubleshooting.md](07-Troubleshooting.md) | Support | Common issues and solutions |
| [CHANGELOG.md](CHANGELOG.md) | History | Version history and script changes |

---

## 🔧 System Requirements

### Server Requirements
- Windows Server 2019/2022
- PowerShell 5.1 or later
- Domain-joined to QB-ENERGY
- Network access to target machines
- WinRM enabled for remote management

### Required PowerShell Modules
```powershell
# For MSU deployment (included in Windows)
# WUSA.exe, DISM.exe - built-in

# For Intune integration
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

# For Windows Update management (optional)
Install-Module PSWindowsUpdate -Scope CurrentUser
```

### Network Shares
| Share | Purpose |
|-------|---------|
| `\\qbe-den-qnap\File4\Inventory` | Inventory data storage (migrated from FILE4 — 2026-03-25) |
| `\\QBE-DEN-WINUP1\Updatefiles` | MSU/CAB/EXE update repository |

---

## 🎯 Feature Summary

### Dashboard Tab
- **Run Collection** - Gather inventory from all AD computers
- **Run Analysis** - Calculate risk scores and generate reports
- **View HTML Report** - Interactive report with filtering
- **Previous Reports** - Access historical analysis data

### KB Warnings Tab
- Track Microsoft-acknowledged problematic updates
- Hardware compatibility warnings (Intel RST, TPM issues)
- Export warnings for documentation

### MSU Updates Tab
- Scan for .msu, .cab, .exe update files
- Deploy to individual servers or phased groups
- Credential management for remote deployment
- Deployment logging and history

### Intune Tab
- Connect to Microsoft Endpoint Manager
- View all managed devices
- Create Windows Update for Business rings
- Query device update status

### Settings Tab
- Configure file paths and shares
- Set API credentials
- Manage machine exclusions
- View system logs

---

## 📞 Getting Help

### In-App Help
Click the **❓ Help** button on any tab to view the relevant documentation.

### Log Files
Logs are stored in `C:\PatchManagement\Logs\`:
- `YYYY-MM-DD_HH-mm-ss_Collection.log` - Collection operations
- `YYYY-MM-DD_HH-mm-ss_Analysis.log` - Analysis operations
- `MSU-Deployment-YYYYMMDD.csv` - MSU deployment history

### Support
Contact IT Infrastructure team for assistance.

---

**Document Version**: 3.1
**Last Updated**: March 2026
**System Version**: PatchManagement-GUI v3.1

---

## 📝 Change Log

| Date | Change |
|------|--------|
| 2026-03-25 | Inventory path migrated from `\\QBE-DEN-FILE4\inventory` to `\\qbe-den-qnap\File4\Inventory` |
| 2026-03-25 | SMB1 detection fixed — now uses `Get-SmbServerConfiguration` instead of Windows Optional Feature state |
| 2026-03-25 | AV detection scoring disabled — QB Energy uses network-level AV; check no longer penalises servers |
| 2026-03-25 | `Config\SuppressedServers.txt` added — servers listed here are excluded from analysis and HTML report |
| 2026-03-25 | HTML risk report — column sorting added for Computer Name, OS, Platform, Score |
