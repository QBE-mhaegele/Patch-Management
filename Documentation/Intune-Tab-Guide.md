# QB Energy Patch Management System
# Intune Tab - User Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Connecting to Intune](#connecting-to-intune)
4. [Managing Devices](#managing-devices)
5. [Creating Update Rings](#creating-update-rings)
6. [Managing Update Rings](#managing-update-rings)
7. [Device Update Status](#device-update-status)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The Intune Tab provides integration with Microsoft Intune (Microsoft Endpoint Manager) for managing Windows Update deployments across your organization's cloud-managed devices. This feature allows you to:

- View and monitor all Intune-managed devices
- Check device compliance status
- Create Windows Update for Business (WUfB) deployment rings
- Manage update deferral and deadline policies
- Query individual devices for update status
- Perform bulk queries across all devices

---

## Prerequisites

### Required Modules
Before using the Intune tab, ensure the following PowerShell modules are installed:

```powershell
# Install Microsoft Graph modules
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

### Required Permissions
Your Azure AD account needs the following permissions:
- **DeviceManagementManagedDevices.Read.All** - To view managed devices
- **DeviceManagementConfiguration.ReadWrite.All** - To create/modify update rings

### Network Requirements
- Access to Microsoft Graph API endpoints
- Access to your Azure AD tenant

---

## Connecting to Intune

### Step 1: Configure Tenant Information

1. Navigate to the **Intune** tab
2. In the **Intune Connection** panel:
   - **Tenant ID**: Enter your Azure AD Tenant ID (GUID format)
     - Default for QB Energy: `41643dbd-bb87-47a6-a3b9-83642bbeba77`
   - **Tenant Name**: Enter a friendly name (e.g., "QB ENERGY")

### Step 2: Connect

1. Click **🔗 Connect to Intune**
2. A browser window may open for Azure AD authentication
3. Sign in with your admin credentials
4. Grant the requested permissions if prompted

### Connection Status Indicators
| Status | Color | Meaning |
|--------|-------|---------|
| "Status: Connected to [TenantID]" | 🟢 Green | Successfully connected |
| "Status: Not Connected" | 🔴 Red | Not connected or connection failed |

### Step 3: Save Configuration

Click **Save Config** to save your Tenant ID and Name for future sessions.

---

## Managing Devices

### Polling Devices

1. Click **🔄 Poll Devices** to retrieve all managed devices from Intune
2. Check **☑ Windows devices only** to filter to Windows devices
3. The device list will populate with:
   - Device Name
   - OS Version
   - Compliance State
   - Last Sync DateTime
   - User Principal Name
   - Device ID

### Device List Color Coding
| Color | Meaning |
|-------|---------|
| 🟢 Green | Compliant |
| 🔴 Red | Non-compliant |
| Black | Unknown/Pending |

### Exporting Device List

Click **Export CSV** to export the device list to a CSV file for reporting.

---

## Creating Update Rings

Update Rings define how Windows Updates are deployed to groups of devices. The system uses a **7-day compliance window** approach.

### Step 1: Configure Ring Settings

In the **Update Ring Deployment (7-Day Reboot Window)** section:

#### Ring Name
- Enter a descriptive name (e.g., `QB-Updates-202602`)
- This name will appear in Intune

#### Deferral Settings
| Setting | Options | Recommended |
|---------|---------|-------------|
| **Quality Deferral** | 0-30 days | 7 days (wait for known issues) |
| **Reboot Deadline** | 3, 5, 7, 14 days | 7 days (balance security vs. user experience) |

#### User Experience Options
| Option | Description | Default |
|--------|-------------|---------|
| **☑ Notify user of pending reboot** | Shows notification before reboot | ✅ Enabled |
| **☑ Allow snooze (until deadline)** | User can postpone reboot | ✅ Enabled |
| **☑ Respect active hours (8AM-5PM)** | Won't reboot during work hours | ✅ Enabled |
| **☑ Force reboot after deadline** | Mandatory reboot at deadline | ✅ Enabled |

### Step 2: Select Target

Choose the deployment target from the **Target** dropdown:
| Target | Description |
|--------|-------------|
| **All Windows Devices** | All Intune-managed Windows devices |
| **Pilot Group** | Small test group (requires Azure AD group) |
| **Production Group** | Main production devices |
| **Selected Devices** | Only devices selected in the list |

### Step 3: Create the Ring

1. Review your settings
2. Click **🔧 Create Update Ring**
3. Wait for confirmation message
4. The ring will appear in Intune's Device Configuration profiles

### Example: Standard Enterprise Configuration

```
Ring Name: QB-Updates-202602
Quality Deferral: 7 days
Reboot Deadline: 7 days
Target: All Windows Devices

User Experience:
☑ Notify user of pending reboot
☑ Allow snooze (until deadline)
☑ Respect active hours (8AM-5PM)
☑ Force reboot after deadline
```

This configuration:
- Waits 7 days after update release before installing (catches early bugs)
- Gives users 7 days to reboot voluntarily
- Respects working hours (8AM-5PM)
- Forces reboot after the deadline passes

---

## Managing Update Rings

### Viewing Existing Rings

1. Click **📋 View Rings**
2. Existing rings will populate in the **Manage Ring** dropdown
3. Select a ring to manage it

### Ring Management Actions

| Button | Action |
|--------|--------|
| **⏸ Pause** | Temporarily stops update deployment |
| **▶ Resume** | Resumes a paused deployment |
| **🗑 Delete** | Permanently removes the update ring |

### When to Pause Updates
- A problematic update is causing issues
- During critical business periods (end of quarter, etc.)
- While troubleshooting deployment issues

### Resuming Updates
After pausing, always remember to resume updates to maintain security compliance.

---

## Device Update Status

### Single Device Query

1. Select a device from the **Device List**
2. The **Device Update Status** panel shows:
   - Device name and risk score
   - OS Version
   - Intune Status
   - Device Info (reachability, offline status)

3. Click **🔍 Query Device** to get detailed status via WinRM:
   - Pending update count
   - Last installed update
   - Recent update history

4. Click **🔄 Refresh Info** to update the Intune-reported status

### Bulk Query All Devices

1. Click **📊 Bulk Query All Devices**
2. The system will query each device via WinRM
3. Progress is shown in real-time
4. Results include:
   - Reachability status
   - Pending updates count
   - Last update date
   - Recent KB installations

5. Click **📁 Export** to save results to CSV

### Understanding Device Status

| Status | Meaning |
|--------|---------|
| "Device not reachable" | Device is offline or WinRM blocked |
| "X pending updates" | Updates waiting to install |
| "Last update: [date]" | Most recent successful update |

---

## Troubleshooting

### "Not connected to Intune" Error

**Symptoms**: Functions show "Not connected" despite green status

**Solution**: 
1. Click **Poll Devices** first - this validates the connection
2. If that fails, click **Disconnect** then **Connect to Intune** again
3. Ensure your Azure AD account has the required permissions

### Connection Fails

**Symptoms**: Can't connect to Intune

**Checklist**:
1. Verify Tenant ID is correct (GUID format)
2. Check internet connectivity
3. Verify Microsoft.Graph modules are installed:
   ```powershell
   Get-Module -ListAvailable Microsoft.Graph*
   ```
4. Try connecting manually:
   ```powershell
   Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"
   ```

### No Devices Appear

**Symptoms**: Poll Devices returns 0 devices

**Checklist**:
1. Ensure devices are enrolled in Intune
2. Check "Windows devices only" filter
3. Verify your account has Device Read permissions
4. Check Azure AD group assignments

### Update Ring Creation Fails

**Symptoms**: Ring doesn't appear in Intune

**Checklist**:
1. Verify DeviceManagementConfiguration.ReadWrite.All permission
2. Check the ring name doesn't contain special characters
3. Ensure target group exists in Azure AD
4. Review Intune audit logs for error details

### Device Query Fails

**Symptoms**: "Device not reachable" for online devices

**Checklist**:
1. WinRM must be enabled on target devices
2. Firewall must allow WinRM (port 5985/5986)
3. Your account needs admin rights on target devices
4. For Azure AD-joined devices, use device name not FQDN

---

## Best Practices

### Update Ring Strategy

1. **Create multiple rings** for phased deployment:
   - Pilot Ring (IT/Early Adopters) - 0 day deferral
   - Early Production - 3 day deferral
   - Production - 7 day deferral
   - Critical Systems - 14 day deferral

2. **Monitor pilot devices** before wider deployment

3. **Keep deadline reasonable** - 7 days balances security and user experience

### Compliance Monitoring

1. Poll devices weekly to track compliance
2. Export non-compliant devices for follow-up
3. Investigate devices that remain non-compliant

### Emergency Procedures

If a bad update is released:
1. Immediately **Pause** all update rings
2. Identify affected devices via Bulk Query
3. Create remediation plan
4. **Resume** rings only after Microsoft releases fix

---

## Quick Reference

### Keyboard Shortcuts
- **F5**: Refresh device list
- **Ctrl+E**: Export current view

### Common Deferral Values
| Scenario | Quality Deferral | Deadline |
|----------|------------------|----------|
| Aggressive (Security-first) | 0 days | 3 days |
| Balanced | 7 days | 7 days |
| Conservative | 14 days | 14 days |
| Critical Systems | 30 days | 14 days |

### Status Bar Messages
| Message | Meaning |
|---------|---------|
| "Polling devices..." | Retrieving device list |
| "Loading rings..." | Fetching existing update rings |
| "Creating ring..." | Deploying new update ring |
| "Found X devices" | Device count from Intune |

---

## Support

For issues with the Intune integration:
1. Check the troubleshooting section above
2. Review Intune audit logs in Azure Portal
3. Contact IT Infrastructure team

**Document Version**: 1.0  
**Last Updated**: February 2026  
**Author**: IT Infrastructure Team
