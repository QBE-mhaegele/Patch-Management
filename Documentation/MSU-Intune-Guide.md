# MSU Updates & Intune Integration Guide

## Overview

Version 3.0 of the QB Energy Patch Management System adds two new major features:

1. **MSU Updates Tab** - Deploy Microsoft Update Standalone (.msu) packages to remote servers using WUSA.exe
2. **Intune Tab** - Manage Windows updates for Intune-enrolled devices not connected to the domain network

---

## MSU Updates Tab

### Purpose
Deploy standalone Windows updates (MSU files) directly to servers using WUSA.exe (Windows Update Standalone Installer). This is useful for:
- Deploying out-of-band security updates
- Installing updates on air-gapped or isolated systems
- Manual deployment of specific KB updates
- Servers not managed by WSUS or Intune

### Prerequisites
- Administrative access to target servers
- WinRM enabled on target servers
- MSU files downloaded to a network-accessible location (default: D:\Updates)
- Network connectivity to target servers

### Usage

#### 1. Scan for MSU Files
1. Set the MSU path (default is `D:\Updates`)
2. Click **Scan for MSU Files**
3. Review the discovered files in the list

#### 2. Select Target Servers
Enter server names in the text box (one per line), or:
- Click **Load File...** to import from a text file
- Click **From AD...** to query Active Directory for all servers

#### 3. Configure Options
- **No restart after installation** - Prevents automatic reboot (recommended)
- **Quiet mode** - Suppresses UI during installation
- **Test mode (WhatIf)** - Simulates deployment without making changes

#### 4. Deploy
1. Select the MSU files to deploy (checkboxes in the list)
2. Click **Deploy Selected Updates**
3. Monitor progress in the output panel

### WUSA Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Success - Restart required |
| 2 | Already installed |
| 3010 | Success - Restart required |
| 2359302 | Already installed |
| 2359303 | Not applicable to this system |
| 1618 | Another installation in progress |
| -2145124329 | Not applicable - wrong OS version (0x80240017) |
| -905928699 | Not applicable - CBS reports wrong OS (0xCA000005) |
| 5 | Access denied - insufficient privileges |

### Using a Service Account for Deployments

For environments where your regular user account doesn't have local admin rights on target servers, you can use a dedicated service account.

#### Setting Up the Service Account

1. **Create a Domain Service Account** (e.g., `SVC-PatchMgmt`)
   - In Active Directory, create a new user account
   - Set password to never expire (or manage via your password policy)
   - Document the credentials securely

2. **Grant Local Admin Rights on Target Servers**
   Option A - Via GPO Restricted Groups:
   - Create/edit a GPO linked to your server OUs
   - Navigate to: Computer Configuration > Policies > Windows Settings > Security Settings > Restricted Groups
   - Add Group: `Administrators`
   - Add the service account: `YOURDOMAIN\SVC-PatchMgmt`

   Option B - Via Local Group Policy on each server:
   ```powershell
   Add-LocalGroupMember -Group "Administrators" -Member "DOMAIN\SVC-PatchMgmt"
   ```

3. **Grant "Log on as a batch job" Right** (if using scheduled tasks)

#### Using the Service Account in the GUI

1. Check **"Use Service Account"** in the MSU Updates tab
2. Click **"Set Credentials"**
3. Enter the service account username and password
4. The credentials will be used for all deployments in this session

The confirmation dialog will show which account will be used for deployment. Credentials are stored only for the current session and are never saved to disk.

#### Security Considerations

- Credentials are held in memory only during the GUI session
- Password is never written to config files or logs
- Each GUI session requires re-entering credentials
- Consider using a dedicated workstation for patch management
- Audit service account usage via Windows Security logs

---

## Intune Tab

### Purpose
Manage Windows updates for devices enrolled in Microsoft Intune (Azure AD/Entra ID joined devices). This provides:
- Device inventory and compliance status
- Update deployment and expediting
- Problematic update blocking/bypass
- Risk-based deployment groups

### Prerequisites

#### Required Modules
```powershell
# Install Microsoft Graph PowerShell module
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Verify installation
Get-Module Microsoft.Graph -ListAvailable
```

#### Required Azure AD/Intune Permissions
The account connecting to Intune needs these permissions:
- `DeviceManagementManagedDevices.Read.All`
- `DeviceManagementManagedDevices.ReadWrite.All`
- `DeviceManagementConfiguration.Read.All`
- `DeviceManagementConfiguration.ReadWrite.All`
- `Group.ReadWrite.All`
- `Device.Read.All`

### Initial Setup

#### 1. Configure Tenant
1. Enter your Azure AD Tenant ID (GUID format)
2. Enter your tenant name (e.g., `qbenergy.onmicrosoft.com`)
3. Click **Save Config** to store settings

#### 2. Connect to Intune
1. Click **Connect to Intune**
2. Complete the Azure AD authentication prompt
3. Verify "Connected" status appears

### Device Management

#### Poll Devices
Click **Poll Devices** to retrieve all Intune-managed Windows devices. The list shows:
- Device name
- OS version
- Compliance state (color-coded)
- Last sync time
- Primary user
- Device ID

#### Sync Devices
Select one or more devices and click **Sync Selected** to trigger an immediate device sync.

#### Export Device List
Click **Export CSV** to save the device list for reporting.

### Update Bypass (Blocking Problematic KBs)

If an update is causing issues, you can block it:

1. Enter the KB number (e.g., `KB5012345`)
2. Click **Block KB**
3. The KB is added to the blocked list

**Note:** This creates a local record. To actually block the update in Intune, you need to:
1. Create a Windows Update policy with the KB excluded
2. Or use the `Manage-IntuneUpdates.ps1` script with `-Action Decline`

### Update Deployment

#### Expedite an Update
To fast-track a critical update:
1. Enter the KB number
2. Select the target group (All, Pilot, Standard, Delayed)
3. Click **Expedite Update**

This creates a Windows Update policy with 0-day deferral for immediate deployment.

#### Pause Updates
Click **Pause Updates** to pause all quality updates for the selected group for 35 days (maximum allowed by policy).

### Risk Groups

Click **Create Risk Groups** to create Azure AD security groups for risk-based deployment:
- `QB-PatchMgmt-Critical` - Machines with critical risk scores
- `QB-PatchMgmt-High` - High risk machines
- `QB-PatchMgmt-Medium` - Medium risk machines
- `QB-PatchMgmt-Low` - Low risk machines
- `QB-PatchMgmt-Pilot` - Pilot/test machines

---

## Command-Line Scripts

### Deploy-MSUUpdates.ps1
```powershell
# Deploy MSU files to specific servers
.\Deploy-MSUUpdates.ps1 -MSUPath "D:\Updates" -ComputerNames "Server1","Server2" -NoRestart

# Deploy to servers listed in a file
.\Deploy-MSUUpdates.ps1 -ComputerListFile "C:\servers.txt" -Quiet

# Test mode (no changes)
.\Deploy-MSUUpdates.ps1 -ComputerNames "Server1" -WhatIf
```

### IntuneManagement.psm1 Functions
```powershell
# Import the module
Import-Module "C:\PatchManagement\Scripts\IntuneManagement.psm1"

# Connect to Intune
Connect-IntuneService -TenantId "your-tenant-id"

# Get all Windows devices
$Devices = Get-IntuneManagedDevices -WindowsOnly

# Block a problematic update
Add-IntuneBlockedUpdate -KBNumber "KB5012345" -Reason "Causes BSOD on Dell systems"

# Get blocked updates
Get-IntuneBlockedUpdates

# Create risk groups
New-IntuneRiskGroup -RiskLevel "Pilot"

# Expedite an update
Deploy-IntuneUpdate -KBNumber "KB5034441" -GroupId "group-id-here"

# Pause updates for a group
Set-IntuneDeviceUpdatePause -GroupId "group-id" -PauseDays 35
```

---

## Troubleshooting

### MSU Deployment Issues

**"Cannot reach server"**
- Verify network connectivity: `Test-Connection ServerName`
- Check WinRM: `Test-WSMan ServerName`
- Ensure firewall allows WinRM (port 5985/5986)

**"Access denied"**
- Run PowerShell as Administrator
- Verify admin credentials for target server
- Check that admin$ share is accessible

**Exit code 2359303 (Not applicable)**
- The update doesn't apply to the server's OS version
- The update supersedes an already-installed update

### Intune Connection Issues

**"Failed to connect"**
- Ensure Microsoft.Graph module is installed
- Verify Azure AD credentials have required permissions
- Check if MFA is required and complete the prompt

**"No devices found"**
- Verify devices are enrolled in Intune
- Check "Windows only" filter
- Ensure your account has device read permissions

**"Group not found"**
- Run **Create Risk Groups** first
- Verify group was created in Azure AD portal

---

## File Locations

| File | Purpose |
|------|---------|
| `C:\PatchManagement\Config\settings.json` | Main configuration |
| `C:\PatchManagement\Config\intune-settings.json` | Intune-specific settings |
| `C:\PatchManagement\Logs\MSUDeployment_*.log` | MSU deployment logs |
| `C:\PatchManagement\Analysis\IntuneDeviceMap.json` | Intune device mapping |

---

## Best Practices

1. **Always test first** - Use WhatIf mode before deploying to production
2. **Pilot group first** - Deploy to pilot group and monitor before wider rollout
3. **Monitor compliance** - Check device compliance status after deployments
4. **Document blocks** - Keep records of why updates were blocked
5. **Review regularly** - Periodically review blocked updates and unblock if issues are resolved
6. **Backup before patching** - Ensure VM snapshots or backups exist for critical systems
