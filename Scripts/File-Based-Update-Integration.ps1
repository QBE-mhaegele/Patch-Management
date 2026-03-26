# File-Based-Update-Integration.ps1
# Add this code to your existing Deploy tab in PatchManagement-GUI.ps1
# Insert this AFTER your existing Diagnose button code (around line 360-400)

#==============================================================================
# FILE-BASED UPDATE DEPLOYMENT (Add to existing Deploy tab)
#==============================================================================

# Separator Line
$FileSeparator = New-Object System.Windows.Forms.Label
$FileSeparator.Location = New-Object System.Drawing.Point(20, 220)
$FileSeparator.Size = New-Object System.Drawing.Size(750, 2)
$FileSeparator.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$TabDeploy.Controls.Add($FileSeparator)

# Section Title
$FileBasedLabel = New-Object System.Windows.Forms.Label
$FileBasedLabel.Location = New-Object System.Drawing.Point(20, 235)
$FileBasedLabel.Size = New-Object System.Drawing.Size(400, 25)
$FileBasedLabel.Text = "File-Based Updates (WUSA) - For Field Machines & Offline Deployment"
$FileBasedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$FileBasedLabel.ForeColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$TabDeploy.Controls.Add($FileBasedLabel)

#------------------------------------------------------------------------------
# Repository Configuration
#------------------------------------------------------------------------------

$RepoPathLabel = New-Object System.Windows.Forms.Label
$RepoPathLabel.Location = New-Object System.Drawing.Point(20, 270)
$RepoPathLabel.Size = New-Object System.Drawing.Size(120, 20)
$RepoPathLabel.Text = "Repository Path:"
$RepoPathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($RepoPathLabel)

$RepoPathTextBox = New-Object System.Windows.Forms.TextBox
$RepoPathTextBox.Location = New-Object System.Drawing.Point(140, 268)
$RepoPathTextBox.Size = New-Object System.Drawing.Size(400, 25)
$RepoPathTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$RepoPathTextBox.Text = "\\QBE-DEN-WINUP1\UpdateFiles"
$TabDeploy.Controls.Add($RepoPathTextBox)

$BrowseRepoButton = New-Object System.Windows.Forms.Button
$BrowseRepoButton.Location = New-Object System.Drawing.Point(550, 266)
$BrowseRepoButton.Size = New-Object System.Drawing.Size(100, 28)
$BrowseRepoButton.Text = "Browse..."
$BrowseRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($BrowseRepoButton)

$RefreshRepoButton = New-Object System.Windows.Forms.Button
$RefreshRepoButton.Location = New-Object System.Drawing.Point(660, 266)
$RefreshRepoButton.Size = New-Object System.Drawing.Size(110, 28)
$RefreshRepoButton.Text = "Scan Updates"
$RefreshRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$RefreshRepoButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$RefreshRepoButton.ForeColor = [System.Drawing.Color]::White
$RefreshRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($RefreshRepoButton)

#------------------------------------------------------------------------------
# Available Updates List with Filter
#------------------------------------------------------------------------------

$AvailableUpdatesLabel = New-Object System.Windows.Forms.Label
$AvailableUpdatesLabel.Location = New-Object System.Drawing.Point(20, 305)
$AvailableUpdatesLabel.Size = New-Object System.Drawing.Size(200, 20)
$AvailableUpdatesLabel.Text = "Available Updates:"
$AvailableUpdatesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($AvailableUpdatesLabel)

$OSFilterLabel = New-Object System.Windows.Forms.Label
$OSFilterLabel.Location = New-Object System.Drawing.Point(480, 305)
$OSFilterLabel.Size = New-Object System.Drawing.Size(60, 20)
$OSFilterLabel.Text = "Filter OS:"
$OSFilterLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($OSFilterLabel)

$OSFilterComboBox = New-Object System.Windows.Forms.ComboBox
$OSFilterComboBox.Location = New-Object System.Drawing.Point(545, 302)
$OSFilterComboBox.Size = New-Object System.Drawing.Size(150, 25)
$OSFilterComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$OSFilterComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$OSFilterComboBox.Items.AddRange(@("All", "Windows10", "Windows11", "Server2019", "Server2022"))
$OSFilterComboBox.SelectedIndex = 0
$TabDeploy.Controls.Add($OSFilterComboBox)

$UpdatesListView = New-Object System.Windows.Forms.ListView
$UpdatesListView.Location = New-Object System.Drawing.Point(20, 330)
$UpdatesListView.Size = New-Object System.Drawing.Size(750, 150)
$UpdatesListView.Font = New-Object System.Drawing.Font("Consolas", 9)
$UpdatesListView.View = [System.Windows.Forms.View]::Details
$UpdatesListView.FullRowSelect = $true
$UpdatesListView.GridLines = $true
$UpdatesListView.MultiSelect = $false
$UpdatesListView.Columns.Add("KB", 100) | Out-Null
$UpdatesListView.Columns.Add("Product", 120) | Out-Null
$UpdatesListView.Columns.Add("Month", 80) | Out-Null
$UpdatesListView.Columns.Add("File Name", 200) | Out-Null
$UpdatesListView.Columns.Add("Size (MB)", 80) | Out-Null
$UpdatesListView.Columns.Add("Date", 100) | Out-Null
$TabDeploy.Controls.Add($UpdatesListView)

#------------------------------------------------------------------------------
# Action Buttons
#------------------------------------------------------------------------------

$DeployFileUpdateButton = New-Object System.Windows.Forms.Button
$DeployFileUpdateButton.Location = New-Object System.Drawing.Point(20, 490)
$DeployFileUpdateButton.Size = New-Object System.Drawing.Size(180, 35)
$DeployFileUpdateButton.Text = "Deploy Selected Update"
$DeployFileUpdateButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DeployFileUpdateButton.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$DeployFileUpdateButton.ForeColor = [System.Drawing.Color]::White
$DeployFileUpdateButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($DeployFileUpdateButton)

$CreateUSBButton = New-Object System.Windows.Forms.Button
$CreateUSBButton.Location = New-Object System.Drawing.Point(210, 490)
$CreateUSBButton.Size = New-Object System.Drawing.Size(180, 35)
$CreateUSBButton.Text = "Create USB Package"
$CreateUSBButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$CreateUSBButton.BackColor = [System.Drawing.Color]::FromArgb(243, 156, 18)
$CreateUSBButton.ForeColor = [System.Drawing.Color]::White
$CreateUSBButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($CreateUSBButton)

$ViewDetailsButton = New-Object System.Windows.Forms.Button
$ViewDetailsButton.Location = New-Object System.Drawing.Point(400, 490)
$ViewDetailsButton.Size = New-Object System.Drawing.Size(180, 35)
$ViewDetailsButton.Text = "View Update Details"
$ViewDetailsButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$ViewDetailsButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$ViewDetailsButton.ForeColor = [System.Drawing.Color]::White
$ViewDetailsButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($ViewDetailsButton)

$OpenRepoButton = New-Object System.Windows.Forms.Button
$OpenRepoButton.Location = New-Object System.Drawing.Point(590, 490)
$OpenRepoButton.Size = New-Object System.Drawing.Size(180, 35)
$OpenRepoButton.Text = "Open Repository"
$OpenRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$OpenRepoButton.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$OpenRepoButton.ForeColor = [System.Drawing.Color]::White
$OpenRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($OpenRepoButton)

# Status Label
$FileDeployStatusLabel = New-Object System.Windows.Forms.Label
$FileDeployStatusLabel.Location = New-Object System.Drawing.Point(20, 535)
$FileDeployStatusLabel.Size = New-Object System.Drawing.Size(750, 40)
$FileDeployStatusLabel.Text = "Ready - Click 'Scan Updates' to browse repository"
$FileDeployStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Gray
$TabDeploy.Controls.Add($FileDeployStatusLabel)

#==============================================================================
# EVENT HANDLERS FOR FILE-BASED UPDATES
#==============================================================================

# Function to load updates from repository
function Load-RepositoryUpdates {
    param(
        [string]$RepositoryPath,
        [string]$OSFilter = "All"
    )
    
    $UpdatesListView.Items.Clear()
    $FileDeployStatusLabel.Text = "Scanning repository..."
    $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    if (-not (Test-Path $RepositoryPath)) {
        $FileDeployStatusLabel.Text = "ERROR: Cannot access repository: $RepositoryPath"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        return
    }
    
    # Build search patterns based on filter
    $SearchPaths = @()
    
    if ($OSFilter -eq "All" -or $OSFilter -eq "Windows10") {
        $SearchPaths += "$RepositoryPath\Windows10\*\*.msu"
    }
    if ($OSFilter -eq "All" -or $OSFilter -eq "Windows11") {
        $SearchPaths += "$RepositoryPath\Windows11\*\*.msu"
    }
    if ($OSFilter -eq "All" -or $OSFilter -eq "Server2019") {
        $SearchPaths += "$RepositoryPath\Server2019\*\*.msu"
    }
    if ($OSFilter -eq "All" -or $OSFilter -eq "Server2022") {
        $SearchPaths += "$RepositoryPath\Server2022\*\*.msu"
    }
    
    $UpdateCount = 0
    
    foreach ($Pattern in $SearchPaths) {
        $Files = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue
        
        foreach ($File in $Files) {
            # Extract KB
            if ($File.Name -match 'KB(\d+)') {
                $KB = "KB$($Matches[1])"
            } else {
                $KB = $File.BaseName
            }
            
            # Determine OS from path
            $OS = "Unknown"
            if ($File.FullName -match '\\Windows10\\') { $OS = "Windows 10 x64" }
            elseif ($File.FullName -match '\\Windows11\\') { $OS = "Windows 11 x64" }
            elseif ($File.FullName -match '\\Server2019\\') { $OS = "Server 2019" }
            elseif ($File.FullName -match '\\Server2022\\') { $OS = "Server 2022" }
            
            # Extract month from path
            $Month = "Unknown"
            if ($File.FullName -match '\\(\d{4}-\d{2})\\') {
                $Month = $Matches[1]
            }
            
            # Get file size
            $SizeMB = [math]::Round($File.Length / 1MB, 2)
            
            # Create list item
            $Item = New-Object System.Windows.Forms.ListViewItem($KB)
            $Item.SubItems.Add($OS) | Out-Null
            $Item.SubItems.Add($Month) | Out-Null
            $Item.SubItems.Add($File.Name) | Out-Null
            $Item.SubItems.Add($SizeMB.ToString()) | Out-Null
            $Item.SubItems.Add($File.LastWriteTime.ToString("yyyy-MM-dd")) | Out-Null
            $Item.Tag = $File.FullName
            
            $UpdatesListView.Items.Add($Item) | Out-Null
            $UpdateCount++
        }
    }
    
    if ($UpdateCount -eq 0) {
        $FileDeployStatusLabel.Text = "No updates found. Download .msu files from Microsoft Update Catalog."
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Orange
    } else {
        $FileDeployStatusLabel.Text = "Found $UpdateCount update(s)"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
    }
}

# Browse Repository
$BrowseRepoButton.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select Update Repository"
    $FolderBrowser.SelectedPath = $RepoPathTextBox.Text
    
    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $RepoPathTextBox.Text = $FolderBrowser.SelectedPath
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
    }
})

# Refresh/Scan Repository
$RefreshRepoButton.Add_Click({
    Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
})

# OS Filter Changed
$OSFilterComboBox.Add_SelectedIndexChanged({
    if ($UpdatesListView.Items.Count -gt 0 -or (Test-Path $RepoPathTextBox.Text)) {
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
    }
})

# Deploy Selected Update
$DeployFileUpdateButton.Add_Click({
    if ($UpdatesListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select an update to deploy.", "No Update Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    $KB = $SelectedItem.Text
    
    # Get computer name from existing textbox
    $ComputerName = $DeployComputerTextBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($ComputerName)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a computer name in the Computer Name field above.", "Computer Name Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Confirm
    $Result = [System.Windows.Forms.MessageBox]::Show(
        "Deploy $KB to $ComputerName?`n`nFile: $(Split-Path $UpdatePath -Leaf)`nSize: $($SelectedItem.SubItems[4].Text) MB`n`nThis will:`n- Copy update to target`n- Install using WUSA`n- Require reboot if needed",
        "Confirm File-Based Deployment",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($Result -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }
    
    $FileDeployStatusLabel.Text = "Deploying $KB to $ComputerName..."
    $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    # Run deployment script
    $DeployScript = Join-Path $Script:BaseDirectory "Scripts\Deploy-FileBasedUpdate.ps1"
    
    if (-not (Test-Path $DeployScript)) {
        [System.Windows.Forms.MessageBox]::Show("Deployment script not found:`n$DeployScript`n`nPlease run Deploy-FileBasedScripts.ps1", "Script Missing", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    try {
        $DeployResult = & $DeployScript -ComputerName $ComputerName -KB $KB -UpdatePath $UpdatePath -ErrorAction Stop
        
        if ($DeployResult.Success) {
            $FileDeployStatusLabel.Text = "SUCCESS: $KB deployed to $ComputerName"
            if ($DeployResult.RebootRequired) {
                $FileDeployStatusLabel.Text += " (Reboot required)"
            }
            $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $FileDeployStatusLabel.Text = "FAILED: $($DeployResult.Error)"
            $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        }
        
    } catch {
        $FileDeployStatusLabel.Text = "ERROR: $_"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Create USB Package
$CreateUSBButton.Add_Click({
    if ($UpdatesListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select an update.", "No Update Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    
    # Output folder
    $USBPackagePath = Join-Path $Script:BaseDirectory "USBPackages\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -Path $USBPackagePath -ItemType Directory -Force | Out-Null
    
    $FileDeployStatusLabel.Text = "Creating USB package..."
    $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        # Copy update file
        $UpdateFile = Get-Item $UpdatePath
        Copy-Item -Path $UpdatePath -Destination $USBPackagePath -Force
        
        # Create INSTALL.bat
        $InstallBat = @"
@echo off
echo ========================================
echo Windows Update USB Installation
echo ========================================
echo.
echo Installing: $($UpdateFile.Name)
echo.

wusa.exe "$($UpdateFile.Name)" /quiet /norestart

if errorlevel 3010 (
    echo.
    echo SUCCESS - Reboot required
) else if errorlevel 2359302 (
    echo.
    echo Already installed
) else if errorlevel 1 (
    echo.
    echo FAILED - Check Windows Update log
) else (
    echo.
    echo SUCCESS
)

echo.
echo ========================================
pause
"@
        
        $InstallBat | Out-File -FilePath (Join-Path $USBPackagePath "INSTALL.bat") -Encoding ASCII
        
        # Create README
        $ReadMe = @"
USB Update Package

File: $($UpdateFile.Name)
Size: $($SelectedItem.SubItems[4].Text) MB
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

INSTRUCTIONS:
1. Copy this folder to USB drive
2. On target machine: Run INSTALL.bat as Administrator
3. Reboot when prompted

QB Energy Patch Management System
"@
        
        $ReadMe | Out-File -FilePath (Join-Path $USBPackagePath "README.txt") -Encoding UTF8
        
        $FileDeployStatusLabel.Text = "USB package created: $USBPackagePath"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        
        [System.Windows.Forms.MessageBox]::Show("USB package created!`n`nLocation: $USBPackagePath`n`nCopy this folder to USB drive and run INSTALL.bat on field machines.", "Package Ready", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Open folder
        Start-Process "explorer.exe" -ArgumentList $USBPackagePath
        
    } catch {
        $FileDeployStatusLabel.Text = "ERROR: $_"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# View Details
$ViewDetailsButton.Add_Click({
    if ($UpdatesListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select an update.", "No Update Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    $KB = $SelectedItem.Text
    
    $Details = "Update: $KB`n"
    $Details += "Product: $($SelectedItem.SubItems[1].Text)`n"
    $Details += "Month: $($SelectedItem.SubItems[2].Text)`n"
    $Details += "File: $($SelectedItem.SubItems[3].Text)`n"
    $Details += "Size: $($SelectedItem.SubItems[4].Text) MB`n"
    $Details += "Date: $($SelectedItem.SubItems[5].Text)`n"
    $Details += "Path: $UpdatePath`n"
    
    # Check for metadata
    $MetadataFile = $UpdatePath -replace '\.msu$', '.txt'
    if (Test-Path $MetadataFile) {
        $Details += "`nMetadata:`n" + ("-" * 50) + "`n"
        $Details += Get-Content $MetadataFile -Raw
    }
    
    [System.Windows.Forms.MessageBox]::Show($Details, "Update Details", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Open Repository
$OpenRepoButton.Add_Click({
    if (Test-Path $RepoPathTextBox.Text) {
        Start-Process "explorer.exe" -ArgumentList $RepoPathTextBox.Text
    } else {
        [System.Windows.Forms.MessageBox]::Show("Repository path not found: $($RepoPathTextBox.Text)", "Path Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

# Auto-load updates when Deploy tab is opened
$TabControl.Add_SelectedIndexChanged({
    if ($TabControl.SelectedTab -eq $TabDeploy -and $UpdatesListView.Items.Count -eq 0) {
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter "All"
    }
})
