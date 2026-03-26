# MSU Updates Tab Guide
## QB Energy Patch Management System v3.0

---

## Overview

The MSU Updates tab allows you to deploy standalone Windows update packages directly to servers without WSUS or Intune. Supports:

- **.msu** files - Windows Update Standalone packages (via WUSA.exe)
- **.cab** files - Cabinet files for Office and component updates (via DISM.exe)
- **.exe** files - KB-related executables like MSRT (direct execution)

---

## Interface Layout

```
┌─────────────────────────────────────────────────────────────┐
│ MSU Source                    │ Target Servers              │
│ Path: \\QBE-DEN-WINUP1\...   │ [Server list text box]      │
│ [Browse] [Scan for Updates]   │ [Load File] [From AD]       │
│ Found: 9 files (7 MSU, 2 EXE) │ ☑ No restart  ☑ Quiet mode │
├─────────────────────────────────────────────────────────────┤
│ Discovered MSU Files                                         │
│ ☑ │ File Name              │ Type │ KB      │ Size   │ Path │
│ ☑ │ windows10-kb5073457... │ MSU  │ KB5073457│ 413 MB │ ... │
│ ☑ │ windows11-kb5043080... │ MSU  │ KB5043080│ 509 MB │ ... │
│ ☑ │ office-kb4567890...    │ CAB  │ KB456789 │ 125 MB │ ... │
├─────────────────────────────────────────────────────────────┤
│ [Select All] [Deselect] [Deploy Selected] [Stop] [View Logs]│
├─────────────────────────────────────────────────────────────┤
│ Deployment Output          │ Phased Deployment              │
│ ┌────────────────────────┐ │ Phase 1: Pilot (31)           │
│ │ Deploying to SERVER01  │ │ Phase 2: Early Adopters (8)   │
│ │ Copying file...        │ │ Phase 3: Production (55)      │
│ │ Installing via WUSA... │ │ Phase 4: Stragglers (0)       │
│ │ ✓ Success              │ │ [Edit] [Save] [Load] [Reset]  │
│ └────────────────────────┘ │ [▶Phase 1][▶Phase 2]...       │
└─────────────────────────────────────────────────────────────┘
```

---

## Getting Started

### Step 1: Configure Source Path

The default path is `\\QBE-DEN-WINUP1\Updatefiles`

To change:
1. Edit the path in the text box, or
2. Click **Browse** to select a folder

### Step 2: Scan for Updates

1. Click **🔍 Scan for Updates**
2. System recursively scans for .msu, .cab, and .exe files
3. Results show file name, type, KB number, size, and path

### Step 3: Select Updates

- Check/uncheck individual updates
- Click **Select All** or **Deselect All**
- Files are color-coded:
  - **Black** - MSU files
  - **Blue** - CAB files (Office updates)
  - **Orange** - EXE files (MSRT, etc.)

### Step 4: Configure Targets

Enter server names in the Target Servers box:
- One server per line
- Or click **Load File** to import from text file
- Or click **From AD** to query Active Directory

### Step 5: Set Options

| Option | Description |
|--------|-------------|
| **☑ No restart after installation** | Prevents automatic reboot |
| **☑ Quiet mode (no UI)** | Silent installation |
| **☐ Test mode (WhatIf)** | Simulates without installing |
| **☑ Use Service Account** | Uses stored credentials |

### Step 6: Deploy

Click **🚀 Deploy Selected Updates**

---

## Deployment Methods by File Type

### MSU Files (Windows Updates)
```
WUSA.exe /update "C:\Windows\Temp\update.msu" /quiet /norestart
```

### CAB Files (Office/Component Updates)
```
DISM.exe /Online /Add-Package /PackagePath:"C:\Windows\Temp\update.cab" /Quiet /NoRestart
```

### EXE Files (MSRT, etc.)
```
update.exe /Q
```

---

## Phased Deployment

Deploy updates in controlled waves to minimize risk.

### Configuring Phases

1. Click **✏️ Edit Phase** to configure each phase
2. Add servers manually or import from:
   - Text file (one server per line)
   - Active Directory query

### Phase Structure
| Phase | Name | Purpose | Typical Size |
|-------|------|---------|--------------|
| 1 | Pilot | IT/Test systems | 5-10% |
| 2 | Early Adopters | Non-critical prod | 10-15% |
| 3 | Production | Main systems | 60-70% |
| 4 | Stragglers | Special handling | Remainder |

### Deploying by Phase

1. Configure all phases
2. Click **▶ Phase 1** to deploy to pilot
3. Verify success, check for issues
4. Click **▶ Phase 2** for next wave
5. Continue through all phases

### Saving Phase Configuration

- Click **💾 Save** to save phases
- Phases auto-save to `\\QBE-DEN-FILE4\inventory\MSU\DefaultPhases.json`
- Phases auto-load when GUI starts

---

## Service Account Authentication

For remote deployment, you may need alternate credentials.

### Setting Credentials

1. Check **☑ Use Service Account**
2. Click **Set Credentials**
3. Enter username and password
4. Credentials are stored securely for the session

### When to Use
- Deploying to servers in different domains
- When your account lacks local admin rights
- For scheduled/automated deployments

---

## Deployment Output

Real-time status for each deployment:

### Status Messages
| Message | Meaning |
|---------|---------|
| `Copying file to [server]...` | Transferring update |
| `Installing via WUSA...` | Running installer |
| `✓ SUCCESS: Installed` | Completed successfully |
| `✓ SUCCESS: Reboot required` | Installed, needs restart |
| `⚠ SKIPPED: Already installed` | Update not needed |
| `❌ FAILED: [error]` | Installation failed |

### Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success |
| 3010 | Success, reboot required |
| 2359302 | Already installed |
| -2145124329 | Not applicable |

---

## Logging

All deployments are logged to:
```
C:\PatchManagement\Logs\MSU-Deployment-YYYYMMDD.csv
```

### Log Columns
- Timestamp
- Server Name
- File Name
- KB Number
- File Type
- Status
- Exit Code
- Message

### Viewing Logs

Click **📋 View Logs** to open the log file.

Click **📁 Export** to save deployment results.

---

## Update Repository Structure

Recommended folder structure for `\\QBE-DEN-WINUP1\Updatefiles`:

```
Updatefiles\
├── Windows10\
│   ├── KB5073457-x64.msu
│   └── KB5043080-x64.msu
├── Windows11\
│   ├── KB5078127-x64.msu
│   └── KB5043080-x64.msu
├── Server2019\
│   └── KB5073457-x64.msu
├── Server2022\
│   └── KB5078127-x64.msu
├── Office\
│   ├── outlook-kb4567890.cab
│   └── word-kb4567891.cab
└── Tools\
    └── windows-kb890830-v5.138.exe  (MSRT)
```

---

## Best Practices

### Before Deployment
1. Test updates on pilot machines first
2. Verify updates are applicable to targets
3. Ensure targets have sufficient disk space
4. Schedule during maintenance windows

### During Deployment
1. Monitor deployment output
2. Check for failures immediately
3. Don't deploy to all phases at once
4. Keep rollback plan ready

### After Deployment
1. Verify installations succeeded
2. Schedule reboots if required
3. Document any issues
4. Update KB Warnings if problems found

---

## Troubleshooting

### "Access Denied" Errors
- Check credentials have local admin on target
- Verify WinRM is enabled on target
- Check firewall allows WinRM (5985/5986)

### "Update Not Applicable"
- Update is for different OS version
- Update already installed
- Prerequisites not met

### Deployment Hangs
- Target may be unresponsive
- WinRM service may be stopped
- Click **Stop** to cancel

### File Copy Fails
- Check network share permissions
- Verify target has disk space
- Check path is accessible

---

## Related Documentation

- [Intune Guide](04-Intune-Guide.md) - For cloud-managed devices
- [Settings Guide](05-Settings-Guide.md) - Configuring paths
- [Troubleshooting](07-Troubleshooting.md) - Additional help

---

**Document Version**: 3.0  
**Last Updated**: February 2026
