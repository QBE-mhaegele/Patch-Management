# ============================================================
# INTUNE TAB - ENHANCED EVENT HANDLERS
# Replace the existing Intune event handlers in PatchManagement-GUI.ps1
# with these improved versions
# ============================================================

# Helper function to update Intune connection status UI
function Update-IntuneStatus {
    try {
        if (Get-Command Test-IntuneConnection -ErrorAction SilentlyContinue) {
            $ConnectionTest = Test-IntuneConnection
            
            if ($ConnectionTest.Connected) {
                if ($ConnectionTest.HasRequiredScopes) {
                    $IntuneStatusLabel.Text = "Status: Connected to $($ConnectionTest.TenantId)"
                    $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Green
                    $IntuneConnectButton.Enabled = $false
                    $IntuneDisconnectButton.Enabled = $true
                    $IntunePollDevicesButton.Enabled = $true
                    return $true
                } else {
                    $IntuneStatusLabel.Text = "Status: Connected but missing permissions"
                    $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Orange
                    $IntuneConnectButton.Enabled = $true
                    $IntuneDisconnectButton.Enabled = $true
                    $IntunePollDevicesButton.Enabled = $false
                    return $false
                }
            }
        }
        
        # Not connected
        $IntuneStatusLabel.Text = "Status: Not Connected"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
        $IntuneConnectButton.Enabled = $true
        $IntuneDisconnectButton.Enabled = $false
        $IntunePollDevicesButton.Enabled = $false
        return $false
        
    } catch {
        Write-Log "Error updating Intune status: $_" -Level Error
        $IntuneStatusLabel.Text = "Status: Error checking connection"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
        return $false
    }
}

# Initialize Intune status on tab load
Update-IntuneStatus

# ============================================================
# CONNECT BUTTON - Enhanced with better error handling
# ============================================================
$IntuneConnectButton.Add_Click({
    $IntuneStatusLabel.Text = "Connecting to Intune..."
    $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $TenantId = $IntuneTenantTextBox.Text.Trim()
        
        if (Get-Command Connect-IntuneService -ErrorAction SilentlyContinue) {
            Write-Log "Connecting to Intune (Tenant: $TenantId)..." -Level Info
            
            $Result = if ($TenantId) {
                Connect-IntuneService -TenantId $TenantId
            } else {
                Connect-IntuneService
            }
            
            if ($Result.Success) {
                Write-Log "Successfully connected to Intune (Tenant: $($Result.TenantId))" -Level Info
                $IntuneStatusLabel.Text = "Connected to: $($Result.TenantId)"
                $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Green
                Update-IntuneStatus
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Successfully connected to Microsoft Graph!`n`n" +
                    "Tenant: $($Result.TenantId)`n" +
                    "Account: $($Result.Account)`n`n" +
                    "You can now poll devices.",
                    "Connection Successful",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            } 
            elseif ($Result.StatusCode -eq 401 -or $Result.StatusCode -eq 403) {
                # Permission error - provide detailed guidance
                Write-Log "Intune connection failed due to insufficient permissions" -Level Warning
                $IntuneStatusLabel.Text = "Connected but access denied (check permissions)"
                $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Orange
                
                $PermissionsList = $Result.RequiredPermissions -join "`n   - "
                
                $MessageText = "Authentication Successful but API Access Denied`n`n" +
                    "The connection to Microsoft Graph succeeded, but the app registration `n" +
                    "does not have the required permissions to access Intune device data.`n`n" +
                    "Required API Permissions:`n   - $PermissionsList`n`n" +
                    "Action Required:`n" +
                    "1. Go to Azure Portal > Azure Active Directory > App registrations`n" +
                    "2. Find your app registration (Tenant: $($Result.TenantId))`n" +
                    "3. Navigate to 'API permissions'`n" +
                    "4. Click 'Add a permission' > Microsoft Graph > Application permissions`n" +
                    "5. Add all the permissions listed above`n" +
                    "6. Click 'Grant admin consent for [Your Org]' (Important!)`n" +
                    "7. Wait 5-10 minutes for changes to propagate`n" +
                    "8. Disconnect and reconnect to Intune`n`n" +
                    "If you've just granted consent, please wait and try again in a few minutes.`n`n" +
                    "Contact your Azure administrator if you need assistance."
                
                [System.Windows.Forms.MessageBox]::Show(
                    $MessageText,
                    "Intune Permission Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            }
            else {
                # Other connection error
                Write-Log "Intune connection failed: $($Result.Message)" -Level Error
                $IntuneStatusLabel.Text = "Connection failed"
                $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to connect to Microsoft Graph.`n`n" +
                    "Error: $($Result.Message)`n`n" +
                    "Please check:`n" +
                    "- You have the Microsoft.Graph PowerShell module installed`n" +
                    "- Your internet connection is working`n" +
                    "- The Tenant ID is correct (if specified)`n" +
                    "- You have the necessary permissions to authenticate",
                    "Connection Failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        } else {
            # Fallback - try direct Graph connection
            Write-Log "IntuneManagement module not loaded, attempting direct connection..." -Level Warning
            
            try {
                Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
                
                $Scopes = @(
                    "DeviceManagementManagedDevices.Read.All",
                    "DeviceManagementConfiguration.Read.All"
                )
                
                if ($TenantId) {
                    Connect-MgGraph -Scopes $Scopes -TenantId $TenantId
                } else {
                    Connect-MgGraph -Scopes $Scopes
                }
                
                $Context = Get-MgContext
                $IntuneStatusLabel.Text = "Connected via Graph (Fallback)"
                $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Green
                Update-IntuneStatus
                
                Write-Log "Connected to Microsoft Graph directly (Tenant: $($Context.TenantId))" -Level Info
                
            } catch {
                Write-Log "Fallback connection failed: $_" -Level Error
                $IntuneStatusLabel.Text = "Connection failed"
                $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Connection failed using direct method.`n`n" +
                    "Error: $_`n`n" +
                    "Make sure the Microsoft.Graph PowerShell module is installed:`n" +
                    "Install-Module Microsoft.Graph -Scope CurrentUser",
                    "Connection Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    } catch {
        Write-Log "Unexpected error during Intune connection: $_" -Level Error
        $IntuneStatusLabel.Text = "Error: $_"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "An unexpected error occurred during connection.`n`n" +
            "Error: $_`n`n" +
            "Please check the application logs for more details.",
            "Unexpected Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ============================================================
# DISCONNECT BUTTON
# ============================================================
$IntuneDisconnectButton.Add_Click({
    try {
        Write-Log "Disconnecting from Intune..." -Level Info
        
        if (Get-Command Disconnect-IntuneService -ErrorAction SilentlyContinue) {
            Disconnect-IntuneService
        } else {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
        }
        
        $IntuneStatusLabel.Text = "Status: Disconnected"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Gray
        Update-IntuneStatus
        
        # Clear device list
        $IntuneDeviceListView.Items.Clear()
        $IntuneDeviceCountLabel.Text = "Total Devices: Not polled"
        
        Write-Log "Disconnected from Intune" -Level Info
        
    } catch {
        Write-Log "Error during disconnect: $_" -Level Error
        $IntuneStatusLabel.Text = "Error: $_"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# ============================================================
# SAVE CONFIG BUTTON
# ============================================================
$IntuneSaveConfigButton.Add_Click({
    try {
        if (Get-Command Get-IntuneConfig -ErrorAction SilentlyContinue) {
            $Config = Get-IntuneConfig
            $Config.TenantId = $IntuneTenantTextBox.Text.Trim()
            $Config.TenantName = $IntuneTenantNameTextBox.Text.Trim()
            
            if (Set-IntuneConfig -Config $Config) {
                Write-Log "Intune configuration saved" -Level Info
                [System.Windows.Forms.MessageBox]::Show(
                    "Configuration saved successfully!",
                    "Configuration Saved",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to save configuration.",
                    "Save Failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    } catch {
        Write-Log "Error saving Intune config: $_" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving configuration: $_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ============================================================
# POLL DEVICES BUTTON - Enhanced with graceful error handling
# ============================================================
$IntunePollDevicesButton.Add_Click({
    $IntuneDeviceListView.Items.Clear()
    $IntuneDeviceCountLabel.Text = "Polling devices..."
    $IntuneLastSyncLabel.Text = "Please wait..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        # Verify connection first
        if (-not (Update-IntuneStatus)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please connect to Intune first before polling devices.",
                "Not Connected",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $IntuneDeviceCountLabel.Text = "Total Devices: Not connected"
            $IntuneLastSyncLabel.Text = "Last Sync: Never"
            return
        }
        
        Write-Log "Polling Intune devices..." -Level Info
        
        $WindowsOnly = $IntuneWindowsOnlyCheckBox.Checked
        
        # Use enhanced function from module
        if (Get-Command Get-IntuneManagedDevices -ErrorAction SilentlyContinue) {
            try {
                $Devices = Get-IntuneManagedDevices -WindowsOnly:$WindowsOnly -ErrorAction Stop
            } catch {
                # Check if it's a permission error
                if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*403*" -or 
                    $_.Exception.Message -like "*Unauthorized*" -or $_.Exception.Message -like "*Forbidden*") {
                    
                    Write-Log "Device polling failed due to insufficient permissions" -Level Error
                    
                    $IntuneStatusLabel.Text = "Connected but insufficient permissions"
                    $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Orange
                    $IntuneDeviceCountLabel.Text = "Total Devices: Permission denied"
                    $IntuneLastSyncLabel.Text = "Last Sync: Failed"
                    
                    # Show detailed error message from the module
                    [System.Windows.Forms.MessageBox]::Show(
                        $_.Exception.Message,
                        "Intune Permission Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    return
                } else {
                    # Other error - re-throw
                    throw $_
                }
            }
        } else {
            # Fallback to direct API call
            Write-Log "Using fallback device enumeration method..." -Level Warning
            
            $Filter = if ($WindowsOnly) { "operatingSystem eq 'Windows'" } else { $null }
            $Devices = if ($Filter) {
                Get-MgDeviceManagementManagedDevice -Filter $Filter -All -ErrorAction Stop
            } else {
                Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
            }
        }
        
        Write-Log "Retrieved $($Devices.Count) devices from Intune" -Level Info
        
        if ($Devices.Count -eq 0) {
            $IntuneDeviceCountLabel.Text = "Total Devices: 0 (No devices found)"
            $IntuneLastSyncLabel.Text = "Last Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            
            [System.Windows.Forms.MessageBox]::Show(
                "No devices found in Intune.`n`n" +
                "This could mean:`n" +
                "- No devices are enrolled in Intune`n" +
                "- The Windows filter is excluding all devices`n" +
                "- There's a synchronization delay",
                "No Devices Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Update UI with device count and sync time
        $IntuneDeviceCountLabel.Text = "Total Devices: $($Devices.Count)"
        $IntuneLastSyncLabel.Text = "Last Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        
        # Populate the device list
        foreach ($Device in $Devices) {
            try {
                # Get device name - handle null
                $DeviceName = if ($Device.DeviceName) { [string]$Device.DeviceName } else { "Unknown" }
                $Item = New-Object System.Windows.Forms.ListViewItem($DeviceName)
                
                # OS Version - convert to string, handle null
                $OSVersion = if ($Device.OSVersion) { [string]$Device.OSVersion } else { "N/A" }
                $Item.SubItems.Add($OSVersion) | Out-Null
                
                # Compliance State - MUST convert enum to string
                $ComplianceState = if ($Device.ComplianceState) { [string]$Device.ComplianceState } else { "Unknown" }
                $Item.SubItems.Add($ComplianceState) | Out-Null
                
                # Last Sync DateTime
                $LastSync = if ($Device.LastSyncDateTime) {
                    try {
                        ([datetime]$Device.LastSyncDateTime).ToString("yyyy-MM-dd HH:mm")
                    } catch { "N/A" }
                } else { "Never" }
                $Item.SubItems.Add($LastSync) | Out-Null
                
                # User Principal Name
                $UserName = if ($Device.UserPrincipalName) { [string]$Device.UserPrincipalName } else { "N/A" }
                $Item.SubItems.Add($UserName) | Out-Null
                
                # Device ID (for selection)
                $DeviceId = if ($Device.DeviceId) { [string]$Device.DeviceId } elseif ($Device.id) { [string]$Device.id } else { "" }
                $Item.SubItems.Add($DeviceId) | Out-Null
                
                # Store full device ID in Tag for later use
                $Item.Tag = $DeviceId
                
                # Color code by compliance state
                if ($ComplianceState -eq "compliant") {
                    $Item.ForeColor = [System.Drawing.Color]::DarkGreen
                } elseif ($ComplianceState -eq "noncompliant") {
                    $Item.ForeColor = [System.Drawing.Color]::Red
                } else {
                    $Item.ForeColor = [System.Drawing.Color]::Black
                }
                
                $IntuneDeviceListView.Items.Add($Item) | Out-Null
                
            } catch {
                Write-Log "Error adding device to list: $_ (Device: $($Device.DeviceName))" -Level Warning
            }
        }
        
        Write-Log "Device list populated with $($IntuneDeviceListView.Items.Count) items" -Level Info
        
    } catch {
        Write-Log "Error polling Intune devices: $_" -Level Error
        
        $IntuneDeviceCountLabel.Text = "Total Devices: Error"
        $IntuneLastSyncLabel.Text = "Last Sync: Failed"
        $IntuneStatusLabel.Text = "Error polling devices"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to retrieve devices from Intune.`n`n" +
            "Error: $_`n`n" +
            "Please check:`n" +
            "- You are connected to Intune`n" +
            "- You have the required permissions`n" +
            "- Your internet connection is stable`n`n" +
            "Try disconnecting and reconnecting if the problem persists.",
            "Device Polling Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ============================================================
# REFRESH BUTTON - Quick re-poll
# ============================================================
$IntuneRefreshButton.Add_Click({
    # Trigger the poll button click
    $IntunePollDevicesButton.PerformClick()
})

# ============================================================
# EXPORT CSV BUTTON
# ============================================================
$IntuneExportButton.Add_Click({
    if ($IntuneDeviceListView.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No devices to export. Please poll devices first.",
            "No Data",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    
    try {
        $SaveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $SaveDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
        $SaveDialog.FileName = "IntuneDevices_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $SaveDialog.InitialDirectory = $env:USERPROFILE
        
        if ($SaveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ExportData = @()
            
            foreach ($Item in $IntuneDeviceListView.Items) {
                $ExportData += [PSCustomObject]@{
                    DeviceName = $Item.Text
                    OSVersion = $Item.SubItems[1].Text
                    ComplianceState = $Item.SubItems[2].Text
                    LastSync = $Item.SubItems[3].Text
                    User = $Item.SubItems[4].Text
                    DeviceId = $Item.SubItems[5].Text
                }
            }
            
            $ExportData | Export-Csv -Path $SaveDialog.FileName -NoTypeInformation -Encoding UTF8
            
            Write-Log "Exported $($ExportData.Count) devices to $($SaveDialog.FileName)" -Level Info
            
            [System.Windows.Forms.MessageBox]::Show(
                "Successfully exported $($ExportData.Count) devices to:`n`n$($SaveDialog.FileName)",
                "Export Successful",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    } catch {
        Write-Log "Error exporting devices: $_" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to export device list.`n`nError: $_",
            "Export Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ============================================================
# Load saved config on startup
# ============================================================
try {
    if (Get-Command Get-IntuneConfig -ErrorAction SilentlyContinue) {
        $LoadedConfig = Get-IntuneConfig
        if ($LoadedConfig.TenantId) {
            $IntuneTenantTextBox.Text = $LoadedConfig.TenantId
        }
        if ($LoadedConfig.TenantName) {
            $IntuneTenantNameTextBox.Text = $LoadedConfig.TenantName
        }
    }
} catch {
    Write-Log "Could not load saved Intune config: $_" -Level Warning
}
