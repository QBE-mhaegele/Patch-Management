# Complete-Deploy-Tab-Replacement.ps1
# COMPLETE Deploy tab for PatchManagement-GUI.ps1
# Includes: Existing Windows Update deployment + NEW File-Based deployment

#==============================================================================
# TAB: Deploy Updates (COMPLETE - Replace entire Deploy tab section)
#==============================================================================

$TabDeploy = New-Object System.Windows.Forms.TabPage
$TabDeploy.Text = "Deploy"
$TabControl.Controls.Add($TabDeploy)

# Title
$DeployTitleLabel = New-Object System.Windows.Forms.Label
$DeployTitleLabel.Location = New-Object System.Drawing.Point(20, 10)
$DeployTitleLabel.Size = New-Object System.Drawing.Size(400, 30)
$DeployTitleLabel.Text = "Deploy Windows Updates"
$DeployTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($DeployTitleLabel)

#------------------------------------------------------------------------------
# SECTION 1: Traditional Windows Update Deployment (Existing functionality)
#------------------------------------------------------------------------------

# Computer Name Label
$DeployComputerLabel = New-Object System.Windows.Forms.Label
$DeployComputerLabel.Location = New-Object System.Drawing.Point(20, 50)
$DeployComputerLabel.Size = New-Object System.Drawing.Size(120, 20)
$DeployComputerLabel.Text = "Computer Name:"
$DeployComputerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($DeployComputerLabel)

# Computer Name TextBox
$DeployComputerTextBox = New-Object System.Windows.Forms.TextBox
$DeployComputerTextBox.Location = New-Object System.Drawing.Point(140, 48)
$DeployComputerTextBox.Size = New-Object System.Drawing.Size(300, 25)
$DeployComputerTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($DeployComputerTextBox)

# Browse AD Button
$DeployBrowseADButton = New-Object System.Windows.Forms.Button
$DeployBrowseADButton.Location = New-Object System.Drawing.Point(450, 46)
$DeployBrowseADButton.Size = New-Object System.Drawing.Size(100, 28)
$DeployBrowseADButton.Text = "Browse AD..."
$DeployBrowseADButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployBrowseADButton.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$DeployBrowseADButton.ForeColor = [System.Drawing.Color]::White
$DeployBrowseADButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($DeployBrowseADButton)

# Deployment Method Label
$DeployMethodLabel = New-Object System.Windows.Forms.Label
$DeployMethodLabel.Location = New-Object System.Drawing.Point(20, 85)
$DeployMethodLabel.Size = New-Object System.Drawing.Size(150, 20)
$DeployMethodLabel.Text = "Deployment Method:"
$DeployMethodLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($DeployMethodLabel)

# Method Description
$DeployMethodDescLabel = New-Object System.Windows.Forms.Label
$DeployMethodDescLabel.Location = New-Object System.Drawing.Point(40, 110)
$DeployMethodDescLabel.Size = New-Object System.Drawing.Size(700, 35)
$DeployMethodDescLabel.Text = "Traditional: Triggers Windows Update on the target computer to download and install updates from Microsoft or your internal WSUS server. Requires internet or WSUS connectivity."
$DeployMethodDescLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$DeployMethodDescLabel.ForeColor = [System.Drawing.Color]::Gray
$TabDeploy.Controls.Add($DeployMethodDescLabel)

# Deploy Windows Updates Button
$DeployWindowsUpdateButton = New-Object System.Windows.Forms.Button
$DeployWindowsUpdateButton.Location = New-Object System.Drawing.Point(20, 155)
$DeployWindowsUpdateButton.Size = New-Object System.Drawing.Size(200, 40)
$DeployWindowsUpdateButton.Text = "Deploy Windows Updates"
$DeployWindowsUpdateButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$DeployWindowsUpdateButton.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$DeployWindowsUpdateButton.ForeColor = [System.Drawing.Color]::White
$DeployWindowsUpdateButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($DeployWindowsUpdateButton)

# Diagnose Button
$DiagnoseButton = New-Object System.Windows.Forms.Button
$DiagnoseButton.Location = New-Object System.Drawing.Point(230, 155)
$DiagnoseButton.Size = New-Object System.Drawing.Size(140, 40)
$DiagnoseButton.Text = "Diagnose"
$DiagnoseButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DiagnoseButton.BackColor = [System.Drawing.Color]::FromArgb(243, 156, 18)
$DiagnoseButton.ForeColor = [System.Drawing.Color]::White
$DiagnoseButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($DiagnoseButton)

# Traditional Deploy Status Label
$TraditionalDeployStatusLabel = New-Object System.Windows.Forms.Label
$TraditionalDeployStatusLabel.Location = New-Object System.Drawing.Point(20, 205)
$TraditionalDeployStatusLabel.Size = New-Object System.Drawing.Size(750, 20)
$TraditionalDeployStatusLabel.Text = ""
$TraditionalDeployStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Gray
$TabDeploy.Controls.Add($TraditionalDeployStatusLabel)

#------------------------------------------------------------------------------
# SECTION 2: File-Based Updates (NEW - WUSA Deployment)
#------------------------------------------------------------------------------

# Separator Line
$FileSeparator = New-Object System.Windows.Forms.Label
$FileSeparator.Location = New-Object System.Drawing.Point(20, 240)
$FileSeparator.Size = New-Object System.Drawing.Size(1020, 2)
$FileSeparator.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$TabDeploy.Controls.Add($FileSeparator)

# File-Based Section Title
$FileBasedTitleLabel = New-Object System.Windows.Forms.Label
$FileBasedTitleLabel.Location = New-Object System.Drawing.Point(20, 255)
$FileBasedTitleLabel.Size = New-Object System.Drawing.Size(500, 25)
$FileBasedTitleLabel.Text = "File-Based Updates (WUSA) - For Field Machines & Offline Deployment"
$FileBasedTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$FileBasedTitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$TabDeploy.Controls.Add($FileBasedTitleLabel)

# Info Label
$FileBasedInfoLabel = New-Object System.Windows.Forms.Label
$FileBasedInfoLabel.Location = New-Object System.Drawing.Point(40, 285)
$FileBasedInfoLabel.Size = New-Object System.Drawing.Size(900, 20)
$FileBasedInfoLabel.Text = "Deploy .msu update files via network OR create USB packages for offline installation on field machines"
$FileBasedInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$FileBasedInfoLabel.ForeColor = [System.Drawing.Color]::Gray
$TabDeploy.Controls.Add($FileBasedInfoLabel)

# Repository Path Label
$RepoPathLabel = New-Object System.Windows.Forms.Label
$RepoPathLabel.Location = New-Object System.Drawing.Point(20, 315)
$RepoPathLabel.Size = New-Object System.Drawing.Size(120, 20)
$RepoPathLabel.Text = "Repository Path:"
$RepoPathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($RepoPathLabel)

# Repository Path TextBox
$RepoPathTextBox = New-Object System.Windows.Forms.TextBox
$RepoPathTextBox.Location = New-Object System.Drawing.Point(140, 313)
$RepoPathTextBox.Size = New-Object System.Drawing.Size(500, 25)
$RepoPathTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$RepoPathTextBox.Text = "\\QBE-DEN-WINUP1\UpdateFiles"
$TabDeploy.Controls.Add($RepoPathTextBox)

# Browse Repository Button
$BrowseRepoButton = New-Object System.Windows.Forms.Button
$BrowseRepoButton.Location = New-Object System.Drawing.Point(650, 311)
$BrowseRepoButton.Size = New-Object System.Drawing.Size(100, 28)
$BrowseRepoButton.Text = "Browse..."
$BrowseRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$BrowseRepoButton.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$BrowseRepoButton.ForeColor = [System.Drawing.Color]::White
$BrowseRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($BrowseRepoButton)

# Scan Updates Button
$RefreshRepoButton = New-Object System.Windows.Forms.Button
$RefreshRepoButton.Location = New-Object System.Drawing.Point(760, 311)
$RefreshRepoButton.Size = New-Object System.Drawing.Size(130, 28)
$RefreshRepoButton.Text = "Scan Updates"
$RefreshRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$RefreshRepoButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$RefreshRepoButton.ForeColor = [System.Drawing.Color]::White
$RefreshRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($RefreshRepoButton)

# Available Updates Label
$AvailableUpdatesLabel = New-Object System.Windows.Forms.Label
$AvailableUpdatesLabel.Location = New-Object System.Drawing.Point(20, 355)
$AvailableUpdatesLabel.Size = New-Object System.Drawing.Size(200, 20)
$AvailableUpdatesLabel.Text = "Available Updates:"
$AvailableUpdatesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($AvailableUpdatesLabel)

# OS Filter Label
$OSFilterLabel = New-Object System.Windows.Forms.Label
$OSFilterLabel.Location = New-Object System.Drawing.Point(730, 355)
$OSFilterLabel.Size = New-Object System.Drawing.Size(60, 20)
$OSFilterLabel.Text = "Filter OS:"
$OSFilterLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TabDeploy.Controls.Add($OSFilterLabel)

# OS Filter ComboBox
$OSFilterComboBox = New-Object System.Windows.Forms.ComboBox
$OSFilterComboBox.Location = New-Object System.Drawing.Point(795, 352)
$OSFilterComboBox.Size = New-Object System.Drawing.Size(150, 25)
$OSFilterComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$OSFilterComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$OSFilterComboBox.Items.AddRange(@("All", "Windows10", "Windows11", "Server2019", "Server2022"))
$OSFilterComboBox.SelectedIndex = 0
$TabDeploy.Controls.Add($OSFilterComboBox)

# Updates ListView
$UpdatesListView = New-Object System.Windows.Forms.ListView
$UpdatesListView.Location = New-Object System.Drawing.Point(20, 380)
$UpdatesListView.Size = New-Object System.Drawing.Size(1020, 150)
$UpdatesListView.Font = New-Object System.Drawing.Font("Consolas", 9)
$UpdatesListView.View = [System.Windows.Forms.View]::Details
$UpdatesListView.FullRowSelect = $true
$UpdatesListView.GridLines = $true
$UpdatesListView.MultiSelect = $false
$UpdatesListView.Columns.Add("KB", 100) | Out-Null
$UpdatesListView.Columns.Add("Product", 150) | Out-Null
$UpdatesListView.Columns.Add("Month", 80) | Out-Null
$UpdatesListView.Columns.Add("File Name", 350) | Out-Null
$UpdatesListView.Columns.Add("Size (MB)", 90) | Out-Null
$UpdatesListView.Columns.Add("Date", 100) | Out-Null
$TabDeploy.Controls.Add($UpdatesListView)

# Action Buttons Row 1
$DeployFileUpdateButton = New-Object System.Windows.Forms.Button
$DeployFileUpdateButton.Location = New-Object System.Drawing.Point(20, 540)
$DeployFileUpdateButton.Size = New-Object System.Drawing.Size(200, 40)
$DeployFileUpdateButton.Text = "Deploy Selected Update"
$DeployFileUpdateButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DeployFileUpdateButton.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$DeployFileUpdateButton.ForeColor = [System.Drawing.Color]::White
$DeployFileUpdateButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($DeployFileUpdateButton)

$CreateUSBButton = New-Object System.Windows.Forms.Button
$CreateUSBButton.Location = New-Object System.Drawing.Point(230, 540)
$CreateUSBButton.Size = New-Object System.Drawing.Size(200, 40)
$CreateUSBButton.Text = "Create USB Package"
$CreateUSBButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$CreateUSBButton.BackColor = [System.Drawing.Color]::FromArgb(243, 156, 18)
$CreateUSBButton.ForeColor = [System.Drawing.Color]::White
$CreateUSBButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($CreateUSBButton)

# Action Buttons Row 2
$ViewDetailsButton = New-Object System.Windows.Forms.Button
$ViewDetailsButton.Location = New-Object System.Drawing.Point(440, 540)
$ViewDetailsButton.Size = New-Object System.Drawing.Size(180, 40)
$ViewDetailsButton.Text = "View Update Details"
$ViewDetailsButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$ViewDetailsButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$ViewDetailsButton.ForeColor = [System.Drawing.Color]::White
$ViewDetailsButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($ViewDetailsButton)

$OpenRepoButton = New-Object System.Windows.Forms.Button
$OpenRepoButton.Location = New-Object System.Drawing.Point(630, 540)
$OpenRepoButton.Size = New-Object System.Drawing.Size(180, 40)
$OpenRepoButton.Text = "Open Repository"
$OpenRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$OpenRepoButton.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$OpenRepoButton.ForeColor = [System.Drawing.Color]::White
$OpenRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($OpenRepoButton)

$HelpButton = New-Object System.Windows.Forms.Button
$HelpButton.Location = New-Object System.Drawing.Point(820, 540)
$HelpButton.Size = New-Object System.Drawing.Size(120, 40)
$HelpButton.Text = "Help"
$HelpButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$HelpButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$HelpButton.ForeColor = [System.Drawing.Color]::White
$HelpButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabDeploy.Controls.Add($HelpButton)

# File-Based Status Label
$FileDeployStatusLabel = New-Object System.Windows.Forms.Label
$FileDeployStatusLabel.Location = New-Object System.Drawing.Point(20, 590)
$FileDeployStatusLabel.Size = New-Object System.Drawing.Size(1020, 40)
$FileDeployStatusLabel.Text = "Ready - Click 'Scan Updates' to browse repository"
$FileDeployStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Gray
$TabDeploy.Controls.Add($FileDeployStatusLabel)

#==============================================================================
# EVENT HANDLERS
#==============================================================================

#------------------------------------------------------------------------------
# Traditional Windows Update Deployment Handlers
#------------------------------------------------------------------------------

# Browse AD Button
$DeployBrowseADButton.Add_Click({
    # Add your existing AD browse functionality here
    # This would typically open a computer picker dialog
    [System.Windows.Forms.MessageBox]::Show(
        "AD Computer Browser functionality goes here",
        "Browse Active Directory",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Deploy Windows Updates Button
$DeployWindowsUpdateButton.Add_Click({
    $ComputerName = $DeployComputerTextBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($ComputerName)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a computer name.",
            "Computer Name Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $TraditionalDeployStatusLabel.Text = "Triggering Windows Update on $ComputerName..."
    $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    # Add your existing deployment script call here
    # Example: .\Deploy-WindowsUpdates.ps1 -ComputerName $ComputerName
    
    try {
        $DeployScript = Join-Path $Script:BaseDirectory "Scripts\Deploy-WindowsUpdates.ps1"
        
        if (Test-Path $DeployScript) {
            & $DeployScript -ComputerName $ComputerName
            $TraditionalDeployStatusLabel.Text = "Windows Update deployment initiated on $ComputerName"
            $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $TraditionalDeployStatusLabel.Text = "Deployment script not found"
            $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        }
    } catch {
        $TraditionalDeployStatusLabel.Text = "ERROR: $_"
        $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Diagnose Button
$DiagnoseButton.Add_Click({
    $ComputerName = $DeployComputerTextBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($ComputerName)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a computer name.",
            "Computer Name Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $TraditionalDeployStatusLabel.Text = "Running diagnostics on $ComputerName..."
    $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    # Add your existing diagnose script call here
    # Example: .\Diagnose-WindowsUpdate.ps1 -ComputerName $ComputerName
    
    try {
        $DiagnoseScript = Join-Path $Script:BaseDirectory "Scripts\Diagnose-WindowsUpdate.ps1"
        
        if (Test-Path $DiagnoseScript) {
            & $DiagnoseScript -ComputerName $ComputerName
            $TraditionalDeployStatusLabel.Text = "Diagnostics completed for $ComputerName"
            $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $TraditionalDeployStatusLabel.Text = "Diagnose script not found"
            $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        }
    } catch {
        $TraditionalDeployStatusLabel.Text = "ERROR: $_"
        $TraditionalDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

#------------------------------------------------------------------------------
# File-Based Update Handlers
#------------------------------------------------------------------------------

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
    
    # Build search patterns
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
        $FileDeployStatusLabel.Text = "No updates found. Download .msu files from Microsoft Update Catalog to: $RepositoryPath"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Orange
    } else {
        $FileDeployStatusLabel.Text = "Found $UpdateCount update(s) in repository"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
    }
}

# Browse Repository
$BrowseRepoButton.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select Update Repository Folder"
    $FolderBrowser.SelectedPath = $RepoPathTextBox.Text
    
    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $RepoPathTextBox.Text = $FolderBrowser.SelectedPath
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
    }
})

# Scan Updates
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
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an update to deploy.",
            "No Update Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    $KB = $SelectedItem.Text
    
    # Get computer name
    $ComputerName = $DeployComputerTextBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($ComputerName)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a computer name in the Computer Name field above.",
            "Computer Name Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Confirm
    $Result = [System.Windows.Forms.MessageBox]::Show(
        "Deploy $KB to $ComputerName?`n`nFile: $(Split-Path $UpdatePath -Leaf)`nSize: $($SelectedItem.SubItems[4].Text) MB`n`nThis will:`n- Copy update to target computer`n- Install using WUSA`n- May require reboot",
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
    
    # Call deployment script
    $DeployScript = Join-Path $Script:BaseDirectory "Scripts\Deploy-FileBasedUpdate.ps1"
    
    if (-not (Test-Path $DeployScript)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Deployment script not found:`n$DeployScript`n`nPlease run Deploy-FileBasedScripts.ps1 to install required scripts.",
            "Script Missing",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
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
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an update to package.",
            "No Update Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    
    # Create package folder
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
        $InstallBatContent = @"
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
    echo Please reboot this computer to complete installation.
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
        
        $InstallBatContent | Out-File -FilePath (Join-Path $USBPackagePath "INSTALL.bat") -Encoding ASCII
        
        # Create README
        $ReadMe = @"
USB Update Package

File: $($UpdateFile.Name)
Size: $($SelectedItem.SubItems[4].Text) MB
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

INSTRUCTIONS:
1. Copy this entire folder to USB drive
2. On target machine: Right-click INSTALL.bat and "Run as administrator"
3. Wait for installation to complete
4. Reboot when prompted

QB Energy Patch Management System
"@
        
        $ReadMe | Out-File -FilePath (Join-Path $USBPackagePath "README.txt") -Encoding UTF8
        
        $FileDeployStatusLabel.Text = "SUCCESS: USB package created: $USBPackagePath"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        
        [System.Windows.Forms.MessageBox]::Show(
            "USB package created successfully!`n`nLocation: $USBPackagePath`n`nCopy this folder to USB drive and run INSTALL.bat on field machines.",
            "Package Ready",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
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
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an update to view details.",
            "No Update Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    $KB = $SelectedItem.Text
    
    $Details = "Update Details`n"
    $Details += "=" * 50 + "`n`n"
    $Details += "KB:       $KB`n"
    $Details += "Product:  $($SelectedItem.SubItems[1].Text)`n"
    $Details += "Month:    $($SelectedItem.SubItems[2].Text)`n"
    $Details += "File:     $($SelectedItem.SubItems[3].Text)`n"
    $Details += "Size:     $($SelectedItem.SubItems[4].Text) MB`n"
    $Details += "Date:     $($SelectedItem.SubItems[5].Text)`n"
    $Details += "Path:     $UpdatePath`n`n"
    
    # Check for metadata file
    $MetadataFile = $UpdatePath -replace '\.msu$', '.txt'
    if (Test-Path $MetadataFile) {
        $Details += "Metadata:`n" + ("-" * 50) + "`n"
        $Details += Get-Content $MetadataFile -Raw
    } else {
        $Details += "No metadata file found.`n"
        $Details += "Create a .txt file with the same name as the .msu file for additional information."
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        $Details,
        "Update Details - $KB",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Open Repository
$OpenRepoButton.Add_Click({
    if (Test-Path $RepoPathTextBox.Text) {
        Start-Process "explorer.exe" -ArgumentList $RepoPathTextBox.Text
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Repository path not found:`n$($RepoPathTextBox.Text)`n`nPlease verify the path or run Setup-FileBasedRepository.ps1 on WINUP1.",
            "Path Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
})

# Help Button
$HelpButton.Add_Click({
    $HelpText = @"
FILE-BASED UPDATE DEPLOYMENT HELP

SETUP:
1. Run Setup-FileBasedRepository.ps1 on WINUP1
2. Download .msu files from Microsoft Update Catalog
3. Save to: \\QBE-DEN-WINUP1\UpdateFiles\[OS]\[Month]\

NETWORK DEPLOYMENT:
1. Enter computer name at top
2. Click "Scan Updates" to find available updates
3. Select update from list
4. Click "Deploy Selected Update"
5. Wait for completion

USB DEPLOYMENT (for field machines):
1. Select update from list
2. Click "Create USB Package"
3. Copy package folder to USB drive
4. On field machine: Run INSTALL.bat as administrator
5. Reboot when prompted

REPOSITORY STRUCTURE:
\\QBE-DEN-WINUP1\UpdateFiles\
├── Windows10\YYYY-MM\*.msu
├── Windows11\YYYY-MM\*.msu
├── Server2019\YYYY-MM\*.msu
└── Server2022\YYYY-MM\*.msu

BENEFITS:
✓ Works offline (USB deployment)
✓ No WSUS complexity
✓ Perfect for field machines
✓ Simple file management

For full documentation see:
File-Based-Update-Management-Guide.md
"@
    
    [System.Windows.Forms.MessageBox]::Show(
        $HelpText,
        "File-Based Deployment Help",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Auto-load updates when Deploy tab is selected
$TabControl.Add_SelectedIndexChanged({
    if ($TabControl.SelectedTab -eq $TabDeploy) {
        if ($UpdatesListView.Items.Count -eq 0) {
            # Auto-scan repository on first tab activation
            if (Test-Path $RepoPathTextBox.Text) {
                Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter "All"
            }
        }
    }
})