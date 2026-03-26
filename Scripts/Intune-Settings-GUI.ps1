# ============================================================
# INTUNE SETTINGS - GUI CODE SNIPPET
# Add this to the Settings tab in PatchManagement-GUI.ps1
# ============================================================

#region Intune Settings Group Box (Add to Settings Tab)

# Create Intune Settings GroupBox
$IntuneSettingsGroup = New-Object System.Windows.Forms.GroupBox
$IntuneSettingsGroup.Text = "Intune / Microsoft Graph Settings"
$IntuneSettingsGroup.Location = New-Object System.Drawing.Point(10, 200)  # Adjust Y position as needed
$IntuneSettingsGroup.Size = New-Object System.Drawing.Size(560, 220)
$IntuneSettingsGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Authentication Mode Selection
$AuthModeLabel = New-Object System.Windows.Forms.Label
$AuthModeLabel.Text = "Authentication Mode:"
$AuthModeLabel.Location = New-Object System.Drawing.Point(15, 25)
$AuthModeLabel.Size = New-Object System.Drawing.Size(130, 20)
$IntuneSettingsGroup.Controls.Add($AuthModeLabel)

$AuthModeCombo = New-Object System.Windows.Forms.ComboBox
$AuthModeCombo.Location = New-Object System.Drawing.Point(150, 22)
$AuthModeCombo.Size = New-Object System.Drawing.Size(200, 25)
$AuthModeCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$AuthModeCombo.Items.AddRange(@("Application (Recommended)", "Delegated (User Login)"))
$AuthModeCombo.SelectedIndex = 0
$IntuneSettingsGroup.Controls.Add($AuthModeCombo)

# Tenant ID
$TenantIdLabel = New-Object System.Windows.Forms.Label
$TenantIdLabel.Text = "Tenant ID:"
$TenantIdLabel.Location = New-Object System.Drawing.Point(15, 55)
$TenantIdLabel.Size = New-Object System.Drawing.Size(130, 20)
$IntuneSettingsGroup.Controls.Add($TenantIdLabel)

$TenantIdTextBox = New-Object System.Windows.Forms.TextBox
$TenantIdTextBox.Location = New-Object System.Drawing.Point(150, 52)
$TenantIdTextBox.Size = New-Object System.Drawing.Size(390, 25)
$TenantIdTextBox.Text = "41643dbd-bb87-47a6-a3b9-83642bbeba77"  # Pre-fill with QB Energy tenant
$IntuneSettingsGroup.Controls.Add($TenantIdTextBox)

# Client ID
$ClientIdLabel = New-Object System.Windows.Forms.Label
$ClientIdLabel.Text = "Client ID (App ID):"
$ClientIdLabel.Location = New-Object System.Drawing.Point(15, 85)
$ClientIdLabel.Size = New-Object System.Drawing.Size(130, 20)
$IntuneSettingsGroup.Controls.Add($ClientIdLabel)

$ClientIdTextBox = New-Object System.Windows.Forms.TextBox
$ClientIdTextBox.Location = New-Object System.Drawing.Point(150, 82)
$ClientIdTextBox.Size = New-Object System.Drawing.Size(390, 25)
$IntuneSettingsGroup.Controls.Add($ClientIdTextBox)

# Client Secret
$ClientSecretLabel = New-Object System.Windows.Forms.Label
$ClientSecretLabel.Text = "Client Secret:"
$ClientSecretLabel.Location = New-Object System.Drawing.Point(15, 115)
$ClientSecretLabel.Size = New-Object System.Drawing.Size(130, 20)
$IntuneSettingsGroup.Controls.Add($ClientSecretLabel)

$ClientSecretTextBox = New-Object System.Windows.Forms.TextBox
$ClientSecretTextBox.Location = New-Object System.Drawing.Point(150, 112)
$ClientSecretTextBox.Size = New-Object System.Drawing.Size(390, 25)
$ClientSecretTextBox.UseSystemPasswordChar = $true  # Mask the secret
$IntuneSettingsGroup.Controls.Add($ClientSecretTextBox)

# Show/Hide Secret Button
$ShowSecretButton = New-Object System.Windows.Forms.Button
$ShowSecretButton.Text = "👁"
$ShowSecretButton.Location = New-Object System.Drawing.Point(520, 110)
$ShowSecretButton.Size = New-Object System.Drawing.Size(30, 25)
$ShowSecretButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$ShowSecretButton.Add_Click({
    $ClientSecretTextBox.UseSystemPasswordChar = -not $ClientSecretTextBox.UseSystemPasswordChar
})
$IntuneSettingsGroup.Controls.Add($ShowSecretButton)

# Credentials Status Label
$CredentialsStatusLabel = New-Object System.Windows.Forms.Label
$CredentialsStatusLabel.Text = "Status: No saved credentials"
$CredentialsStatusLabel.Location = New-Object System.Drawing.Point(15, 145)
$CredentialsStatusLabel.Size = New-Object System.Drawing.Size(400, 20)
$CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Gray
$IntuneSettingsGroup.Controls.Add($CredentialsStatusLabel)

# Save Credentials Button
$SaveCredentialsButton = New-Object System.Windows.Forms.Button
$SaveCredentialsButton.Text = "💾 Save Credentials"
$SaveCredentialsButton.Location = New-Object System.Drawing.Point(15, 175)
$SaveCredentialsButton.Size = New-Object System.Drawing.Size(130, 30)
$SaveCredentialsButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$SaveCredentialsButton.ForeColor = [System.Drawing.Color]::White
$SaveCredentialsButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$IntuneSettingsGroup.Controls.Add($SaveCredentialsButton)

# Test Connection Button
$TestIntuneButton = New-Object System.Windows.Forms.Button
$TestIntuneButton.Text = "🔗 Test Connection"
$TestIntuneButton.Location = New-Object System.Drawing.Point(155, 175)
$TestIntuneButton.Size = New-Object System.Drawing.Size(130, 30)
$TestIntuneButton.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
$TestIntuneButton.ForeColor = [System.Drawing.Color]::White
$TestIntuneButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$IntuneSettingsGroup.Controls.Add($TestIntuneButton)

# Clear Credentials Button
$ClearCredentialsButton = New-Object System.Windows.Forms.Button
$ClearCredentialsButton.Text = "🗑 Clear Saved"
$ClearCredentialsButton.Location = New-Object System.Drawing.Point(295, 175)
$ClearCredentialsButton.Size = New-Object System.Drawing.Size(110, 30)
$ClearCredentialsButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$IntuneSettingsGroup.Controls.Add($ClearCredentialsButton)

# Help Link
$IntuneHelpLink = New-Object System.Windows.Forms.LinkLabel
$IntuneHelpLink.Text = "📖 Setup Instructions"
$IntuneHelpLink.Location = New-Object System.Drawing.Point(420, 182)
$IntuneHelpLink.Size = New-Object System.Drawing.Size(120, 20)
$IntuneHelpLink.Add_Click({
    Start-Process "https://learn.microsoft.com/en-us/graph/auth-register-app-v2"
})
$IntuneSettingsGroup.Controls.Add($IntuneHelpLink)

# Add GroupBox to Settings Tab
$SettingsTab.Controls.Add($IntuneSettingsGroup)

#endregion

#region Intune Settings Event Handlers

# Toggle visibility of app auth fields based on mode
$AuthModeCombo.Add_SelectedIndexChanged({
    $IsAppAuth = ($AuthModeCombo.SelectedIndex -eq 0)
    $ClientIdTextBox.Enabled = $IsAppAuth
    $ClientSecretTextBox.Enabled = $IsAppAuth
    $SaveCredentialsButton.Enabled = $IsAppAuth
    $ShowSecretButton.Enabled = $IsAppAuth
    
    if (-not $IsAppAuth) {
        $CredentialsStatusLabel.Text = "Delegated mode: Users will sign in interactively"
        $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    }
})

# Load saved credentials on form load
$Form.Add_Load({
    try {
        if (Get-Command Get-IntuneCredentials -ErrorAction SilentlyContinue) {
            $SavedCreds = Get-IntuneCredentials
            if ($SavedCreds.Success) {
                $TenantIdTextBox.Text = $SavedCreds.Credentials.TenantId
                $ClientIdTextBox.Text = $SavedCreds.Credentials.ClientId
                # Don't load secret into text box for security
                $CredentialsStatusLabel.Text = "✓ Credentials saved (by $($SavedCreds.Credentials.SavedBy) on $($SavedCreds.Credentials.SavedAt))"
                $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Green
                
                # Store the secure string for later use
                $Script:SavedClientSecret = $SavedCreds.Credentials.ClientSecret
            }
        }
    } catch {
        Write-Log "Error loading Intune credentials: $_" -Level Warning
    }
})

# Save Credentials Button Click
$SaveCredentialsButton.Add_Click({
    $TenantId = $TenantIdTextBox.Text.Trim()
    $ClientId = $ClientIdTextBox.Text.Trim()
    $ClientSecretPlain = $ClientSecretTextBox.Text
    
    # Validation
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a Tenant ID.",
            "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a Client ID (Application ID).",
            "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($ClientSecretPlain)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a Client Secret.",
            "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Validate GUID format
    try {
        $null = [System.Guid]::Parse($TenantId)
        $null = [System.Guid]::Parse($ClientId)
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Tenant ID and Client ID must be valid GUIDs.",
            "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Convert to SecureString
    $SecureSecret = ConvertTo-SecureString -String $ClientSecretPlain -AsPlainText -Force
    
    try {
        $Result = Save-IntuneCredentials -TenantId $TenantId -ClientId $ClientId -ClientSecret $SecureSecret
        
        if ($Result.Success) {
            $CredentialsStatusLabel.Text = "✓ Credentials saved successfully"
            $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Green
            
            # Clear the plain text secret from the textbox
            $ClientSecretTextBox.Text = ""
            
            # Store for later use
            $Script:SavedClientSecret = $SecureSecret
            
            [System.Windows.Forms.MessageBox]::Show(
                "Credentials saved successfully.`n`nPath: $($Result.Path)`n`nCredentials are encrypted and can only be used on this machine.",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            Write-Log "Intune credentials saved by $env:USERNAME" -Level Info
        } else {
            throw $Result.Message
        }
    } catch {
        $CredentialsStatusLabel.Text = "✗ Failed to save credentials"
        $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to save credentials:`n`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Test Connection Button Click
$TestIntuneButton.Add_Click({
    $TenantId = $TenantIdTextBox.Text.Trim()
    $ClientId = $ClientIdTextBox.Text.Trim()
    $UseAppAuth = ($AuthModeCombo.SelectedIndex -eq 0)
    
    $TestIntuneButton.Enabled = $false
    $TestIntuneButton.Text = "Testing..."
    $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    
    try {
        if ($UseAppAuth) {
            # Get secret from textbox or saved credentials
            $SecureSecret = $null
            
            if (-not [string]::IsNullOrWhiteSpace($ClientSecretTextBox.Text)) {
                $SecureSecret = ConvertTo-SecureString -String $ClientSecretTextBox.Text -AsPlainText -Force
            } elseif ($Script:SavedClientSecret) {
                $SecureSecret = $Script:SavedClientSecret
            } else {
                # Try to load from saved credentials
                $SavedCreds = Get-IntuneCredentials
                if ($SavedCreds.Success) {
                    $SecureSecret = $SavedCreds.Credentials.ClientSecret
                }
            }
            
            if (-not $SecureSecret) {
                throw "No client secret available. Please enter the secret or save credentials first."
            }
            
            $Result = Connect-IntuneService -TenantId $TenantId -ClientId $ClientId -ClientSecret $SecureSecret -UseApplicationAuth
        } else {
            $Result = Connect-IntuneService -TenantId $TenantId
        }
        
        if ($Result.Success) {
            # Try to get device count
            $Devices = Get-IntuneManagedDevices -WindowsOnly
            $DeviceCount = if ($Devices) { $Devices.Count } else { 0 }
            
            [System.Windows.Forms.MessageBox]::Show(
                "✓ Connection successful!`n`n" +
                "Tenant ID: $($Result.TenantId)`n" +
                "Account: $($Result.Account)`n" +
                "Mode: $($Result.ConnectionMode)`n" +
                "Windows Devices Found: $DeviceCount",
                "Connection Test Passed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            $CredentialsStatusLabel.Text = "✓ Connection verified - $DeviceCount devices found"
            $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Green
            
            # Disconnect after test
            Disconnect-IntuneService | Out-Null
        } else {
            throw $Result.Message
        }
    } catch {
        $ErrorMessage = $_.Exception.Message
        
        # Provide helpful guidance based on error
        $Guidance = ""
        if ($ErrorMessage -match "Invalid client secret|AADSTS7000215") {
            $Guidance = "`n`nThe client secret may have expired. Generate a new secret in Azure Portal → App registrations → Certificates & secrets."
        } elseif ($ErrorMessage -match "Application not found|AADSTS700016") {
            $Guidance = "`n`nVerify the Client ID is correct. Find it in Azure Portal → App registrations."
        } elseif ($ErrorMessage -match "Tenant not found|AADSTS90002") {
            $Guidance = "`n`nVerify the Tenant ID is correct. Find it in Azure Portal → Azure Active Directory → Overview."
        } elseif ($ErrorMessage -match "401|403|Access denied") {
            $Guidance = "`n`nThe app may not have the required permissions. In Azure Portal → App registrations → API permissions, add:`n" +
                        "• DeviceManagementManagedDevices.Read.All (Application)`n" +
                        "• DeviceManagementConfiguration.Read.All (Application)`n`n" +
                        "Then click 'Grant admin consent'."
        }
        
        [System.Windows.Forms.MessageBox]::Show(
            "✗ Connection failed:`n`n$ErrorMessage$Guidance",
            "Connection Test Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        $CredentialsStatusLabel.Text = "✗ Connection test failed"
        $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Red
    } finally {
        $TestIntuneButton.Enabled = $true
        $TestIntuneButton.Text = "🔗 Test Connection"
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# Clear Credentials Button Click
$ClearCredentialsButton.Add_Click({
    $Confirm = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to delete the saved Intune credentials?`n`nThis action cannot be undone.",
        "Confirm Delete",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($Confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            $Removed = Remove-IntuneCredentials
            $Script:SavedClientSecret = $null
            
            $ClientIdTextBox.Text = ""
            $ClientSecretTextBox.Text = ""
            $CredentialsStatusLabel.Text = "Credentials removed"
            $CredentialsStatusLabel.ForeColor = [System.Drawing.Color]::Gray
            
            Write-Log "Intune credentials removed by $env:USERNAME" -Level Info
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to remove credentials: $($_.Exception.Message)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
})

#endregion

#region Updated Intune Tab - Connect Button Handler

# Replace the existing $IntuneConnectButton.Add_Click handler with this:

$IntuneConnectButton.Add_Click({
    Write-Log "Intune Connect button clicked" -Level Info
    
    $IntuneConnectButton.Enabled = $false
    $IntuneStatusLabel.Text = "Connecting..."
    $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Orange
    $Form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    
    try {
        # Check if we should use application auth (check Settings tab selection)
        $UseAppAuth = ($AuthModeCombo.SelectedIndex -eq 0)
        $TenantId = $TenantIdTextBox.Text.Trim()
        
        if ($UseAppAuth) {
            # Application authentication
            $ClientId = $ClientIdTextBox.Text.Trim()
            $SecureSecret = $null
            
            # Get secret from textbox, memory, or saved file
            if (-not [string]::IsNullOrWhiteSpace($ClientSecretTextBox.Text)) {
                $SecureSecret = ConvertTo-SecureString -String $ClientSecretTextBox.Text -AsPlainText -Force
            } elseif ($Script:SavedClientSecret) {
                $SecureSecret = $Script:SavedClientSecret
            } else {
                $SavedCreds = Get-IntuneCredentials
                if ($SavedCreds.Success) {
                    $TenantId = $SavedCreds.Credentials.TenantId
                    $ClientId = $SavedCreds.Credentials.ClientId
                    $SecureSecret = $SavedCreds.Credentials.ClientSecret
                }
            }
            
            if (-not $SecureSecret) {
                throw "No credentials available. Please configure Intune settings in the Settings tab first."
            }
            
            $Result = Connect-IntuneService -TenantId $TenantId -ClientId $ClientId -ClientSecret $SecureSecret -UseApplicationAuth
        } else {
            # Delegated authentication
            $Result = Connect-IntuneService -TenantId $TenantId
        }
        
        if ($Result.Success) {
            $IntuneStatusLabel.Text = "Status: Connected to $($Result.TenantId)"
            $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Green
            $IntuneConnectButton.Enabled = $false
            $IntuneDisconnectButton.Enabled = $true
            $IntunePollDevicesButton.Enabled = $true
            
            # Update the Intune tab tenant display if it exists
            if ($IntuneTenantIdTextBox) {
                $IntuneTenantIdTextBox.Text = $TenantId
            }
            
            Write-Log "Connected to Intune using $($Result.ConnectionMode) authentication" -Level Info
        } else {
            throw $Result.Message
        }
    } catch {
        $ErrorMessage = $_.Exception.Message
        
        $IntuneStatusLabel.Text = "Status: Connection failed"
        $IntuneStatusLabel.ForeColor = [System.Drawing.Color]::Red
        $IntuneConnectButton.Enabled = $true
        
        # Determine if this is a permission/configuration error
        if ($ErrorMessage -match "401|403|Access denied|permissions|consent") {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to connect to Intune:`n`n$ErrorMessage`n`n" +
                "Please verify:`n" +
                "1. App registration has correct API permissions (Application type)`n" +
                "2. Admin consent has been granted`n" +
                "3. Client secret is valid and not expired`n`n" +
                "Configure settings in the Settings tab.",
                "Intune Connection Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        } elseif ($ErrorMessage -match "No credentials") {
            [System.Windows.Forms.MessageBox]::Show(
                "No Intune credentials configured.`n`n" +
                "Please go to the Settings tab and configure:`n" +
                "• Tenant ID`n" +
                "• Client ID (from Azure App Registration)`n" +
                "• Client Secret`n`n" +
                "Then save the credentials and try again.",
                "Configuration Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to connect to Intune:`n`n$ErrorMessage",
                "Connection Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        
        Write-Log "Intune connection failed: $ErrorMessage" -Level Error
    } finally {
        $IntuneConnectButton.Enabled = -not (Test-IntuneConnection).Connected
        $Form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

#endregion
