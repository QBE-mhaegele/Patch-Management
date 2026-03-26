# ============================================================
# QB ENERGY - INTUNE APP REGISTRATION SETUP GUIDE
# For Patch Management System Application Authentication
# ============================================================

## Overview

This guide walks through setting up Azure AD App Registration for the 
QB Energy Patch Management System to use **Application Authentication** 
(client credentials flow) instead of delegated user authentication.

**Benefits of Application Authentication:**
- End users don't need Intune Administrator roles
- Access is controlled at the RDS/application level
- Single service principal for all users
- Credentials stored securely on the server
- No interactive login prompts

---

## Prerequisites

- Global Administrator or Application Administrator role in Azure AD
- Access to Azure Portal (portal.azure.com)

---

## Step 1: Create or Update App Registration

### If creating a NEW app registration:

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **+ New registration**
3. Configure:
   - **Name:** `QB Energy Patch Management`
   - **Supported account types:** `Accounts in this organizational directory only`
   - **Redirect URI:** Leave blank (not needed for client credentials)
4. Click **Register**

### If using EXISTING app ("Graph API for Powershell"):

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Find and click on **Graph API for Powershell**

---

## Step 2: Add API Permissions (Application Type)

1. In the app registration, click **API permissions** in the left menu
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Select **Application permissions** (NOT Delegated)
5. Search for and add these permissions:

| Permission | Description |
|------------|-------------|
| `DeviceManagementManagedDevices.Read.All` | Read Intune devices |
| `DeviceManagementManagedDevices.ReadWrite.All` | Manage Intune devices |
| `DeviceManagementConfiguration.Read.All` | Read device configuration |
| `DeviceManagementConfiguration.ReadWrite.All` | Manage device configuration |
| `Group.ReadWrite.All` | Manage risk groups |
| `Device.Read.All` | Read Azure AD devices |

6. Click **Add permissions**

### Grant Admin Consent

7. Click the **Grant admin consent for QB ENERGY** button
8. Confirm by clicking **Yes**
9. Verify all permissions show a green checkmark under "Status"

---

## Step 3: Create Client Secret

1. In the app registration, click **Certificates & secrets**
2. Click **+ New client secret**
3. Configure:
   - **Description:** `Patch Management System`
   - **Expires:** `24 months` (recommended) or your security policy
4. Click **Add**
5. **IMPORTANT:** Copy the secret **Value** immediately!
   - You will NOT be able to see it again after leaving this page
   - Store it securely (you'll need it for the Patch Management tool)

---

## Step 4: Collect Required Information

You need these three values for the Patch Management System:

| Setting | Where to Find | Example |
|---------|---------------|---------|
| **Tenant ID** | Azure AD → Overview → Tenant ID | `41643dbd-bb87-47a6-a3b9-83642bbeba77` |
| **Client ID** | App Registration → Overview → Application (client) ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **Client Secret** | Created in Step 3 (copy immediately!) | `abc123~xxxxxxxxxxxxxxxxxxxxx` |

---

## Step 5: Configure Patch Management System

### On the RDS Server running the Patch Management GUI:

1. Launch **QB Energy Patch Management**
2. Go to the **Settings** tab
3. In the **Intune / Microsoft Graph Settings** section:
   - Set **Authentication Mode:** `Application (Recommended)`
   - Enter **Tenant ID**
   - Enter **Client ID**
   - Enter **Client Secret**
4. Click **Save Credentials**
5. Click **Test Connection** to verify

### Expected Result:
- "✓ Connection successful!"
- Device count displayed
- Status shows green checkmark

---

## Step 6: Verify in Intune Tab

1. Go to the **Intune** tab
2. Click **Connect to Intune**
3. Connection should succeed automatically (no login prompt)
4. Click **Poll Devices** to retrieve device list

---

## Troubleshooting

### Error: "Invalid client secret"
- The secret may have expired
- Generate a new secret in Azure Portal → Certificates & secrets
- Update the secret in the Patch Management Settings tab

### Error: "Access denied (401/403)"
- Verify permissions are **Application** type, not Delegated
- Ensure admin consent was granted (green checkmarks)
- Wait 5-10 minutes after granting consent for propagation

### Error: "Application not found"
- Verify the Client ID is correct
- Check you're in the right Azure AD tenant

### Error: "No devices found"
- Verify there are Windows devices enrolled in Intune
- Check the app has `DeviceManagementManagedDevices.Read.All` permission

---

## Security Considerations

### Credential Storage
- Credentials are encrypted using Windows DPAPI
- Can only be decrypted on the same machine by administrators
- Stored in: `C:\ProgramData\QB Energy\PatchManagement\intune-credentials.xml`

### Access Control
- Only users with access to the RDS server can use the tool
- The service principal's access is controlled by Azure AD permissions
- Consider using Conditional Access policies for the app registration

### Audit Trail
- Azure AD logs all authentication attempts
- Monitor in: Azure Portal → Azure AD → Sign-in logs → Service principal sign-ins

### Secret Rotation
- Create a new secret before the current one expires
- Update the Patch Management Settings tab with the new secret
- Delete the old secret from Azure after confirming the new one works

---

## Quick Reference - PowerShell Verification

Run this from PowerShell to verify the app can authenticate:

```powershell
# Install module if needed
Install-Module Microsoft.Graph -Scope CurrentUser

# Test connection (replace with your values)
$TenantId = "41643dbd-bb87-47a6-a3b9-83642bbeba77"
$ClientId = "your-client-id-here"
$ClientSecret = "your-client-secret-here" | ConvertTo-SecureString -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($ClientId, $ClientSecret)

Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $Credential

# Test device access
Get-MgDeviceManagementManagedDevice -Top 5 | Select-Object DeviceName, OperatingSystem

# Disconnect
Disconnect-MgGraph
```

---

## Contact

For assistance with Azure configuration:
- IT Infrastructure Team
- Azure Administrator

For assistance with Patch Management tool:
- IT Infrastructure Team

---

Document Version: 2.0
Last Updated: January 2026
