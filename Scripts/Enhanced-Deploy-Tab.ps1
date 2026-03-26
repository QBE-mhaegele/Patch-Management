# Enhanced-Deploy-Tab.ps1
# Updated Deploy tab code for Patch Management GUI
# Integrates file-based WUSA deployment with existing functionality

# This code replaces the existing Deploy tab in PatchManagement-GUI.ps1

#==============================================================================
# TAB: Deploy Updates (Enhanced with File-Based Updates)
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
# Deployment Method Selection
#------------------------------------------------------------------------------

$DeployMethodGroupBox = New-Object System.Windows.Forms.GroupBox
$DeployMethodGroupBox.Location = New-Object System.Drawing.Point(20, 50)
$DeployMethodGroupBox.Size = New-Object System.Drawing.Size(500, 80)
$DeployMethodGroupBox.Text = "Deployment Method"
$DeployMethodGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($DeployMethodGroupBox)

# Radio: Windows Update (original method)
$DeployMethodWU = New-Object System.Windows.Forms.RadioButton
$DeployMethodWU.Location = New-Object System.Drawing.Point(20, 30)
$DeployMethodWU.Size = New-Object System.Drawing.Size(200, 20)
$DeployMethodWU.Text = "Windows Update (online)"
$DeployMethodWU.Checked = $false
$DeployMethodWU.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployMethodGroupBox.Controls.Add($DeployMethodWU)

# Radio: File-Based (WUSA)
$DeployMethodFile = New-Object System.Windows.Forms.RadioButton
$DeployMethodFile.Location = New-Object System.Drawing.Point(20, 50)
$DeployMethodFile.Size = New-Object System.Drawing.Size(250, 20)
$DeployMethodFile.Text = "File-Based (WUSA) - Recommended"
$DeployMethodFile.Checked = $true
$DeployMethodFile.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DeployMethodFile.ForeColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$DeployMethodGroupBox.Controls.Add($DeployMethodFile)

# Info label
$DeployMethodInfoLabel = New-Object System.Windows.Forms.Label
$DeployMethodInfoLabel.Location = New-Object System.Drawing.Point(280, 30)
$DeployMethodInfoLabel.Size = New-Object System.Drawing.Size(200, 40)
$DeployMethodInfoLabel.Text = "File-Based works offline,`nfor field machines, and`nremote locations"
$DeployMethodInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$DeployMethodInfoLabel.ForeColor = [System.Drawing.Color]::Gray
$DeployMethodGroupBox.Controls.Add($DeployMethodInfoLabel)

#------------------------------------------------------------------------------
# File-Based Update Selection (WUSA)
#------------------------------------------------------------------------------

$FileUpdateGroupBox = New-Object System.Windows.Forms.GroupBox
$FileUpdateGroupBox.Location = New-Object System.Drawing.Point(20, 140)
$FileUpdateGroupBox.Size = New-Object System.Drawing.Size(500, 200)
$FileUpdateGroupBox.Text = "File-Based Update Selection"
$FileUpdateGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($FileUpdateGroupBox)

# Repository path
$FileRepoLabel = New-Object System.Windows.Forms.Label
$FileRepoLabel.Location = New-Object System.Drawing.Point(20, 30)
$FileRepoLabel.Size = New-Object System.Drawing.Size(100, 20)
$FileRepoLabel.Text = "Repository:"
$FileRepoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileUpdateGroupBox.Controls.Add($FileRepoLabel)

$FileRepoTextBox = New-Object System.Windows.Forms.TextBox
$FileRepoTextBox.Location = New-Object System.Drawing.Point(120, 27)
$FileRepoTextBox.Size = New-Object System.Drawing.Size(350, 25)
$FileRepoTextBox.Text = "\\QBE-DEN-WINUP1\UpdateFiles"
$FileRepoTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileUpdateGroupBox.Controls.Add($FileRepoTextBox)

# Browse button
$FileBrowseRepoButton = New-Object System.Windows.Forms.Button
$FileBrowseRepoButton.Location = New-Object System.Drawing.Point(420, 25)
$FileBrowseRepoButton.Size = New-Object System.Drawing.Size(60, 25)
$FileBrowseRepoButton.Text = "..."
$FileBrowseRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileUpdateGroupBox.Controls.Add($FileBrowseRepoButton)

# Refresh available updates button
$FileRefreshButton = New-Object System.Windows.Forms.Button
$FileRefreshButton.Location = New-Object System.Drawing.Point(20, 60)
$FileRefreshButton.Size = New-Object System.Drawing.Size(150, 30)
$FileRefreshButton.Text = "Refresh Updates"
$FileRefreshButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileRefreshButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$FileRefreshButton.ForeColor = [System.Drawing.Color]::White
$FileRefreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileUpdateGroupBox.Controls.Add($FileRefreshButton)

# Available updates list
$FileUpdatesLabel = New-Object System.Windows.Forms.Label
$FileUpdatesLabel.Location = New-Object System.Drawing.Point(20, 100)
$FileUpdatesLabel.Size = New-Object System.Drawing.Size(150, 20)
$FileUpdatesLabel.Text = "Available Updates:"
$FileUpdatesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileUpdateGroupBox.Controls.Add($FileUpdatesLabel)

$FileUpdatesListBox = New-Object System.Windows.Forms.ListBox
$FileUpdatesListBox.Location = New-Object System.Drawing.Point(20, 125)
$FileUpdatesListBox.Size = New-Object System.Drawing.Size(460, 60)
$FileUpdatesListBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$FileUpdatesListBox.SelectionMode = [System.Windows.Forms.SelectionMode]::One
$FileUpdateGroupBox.Controls.Add($FileUpdatesListBox)

#------------------------------------------------------------------------------
# Target Computer Selection
#------------------------------------------------------------------------------

$TargetGroupBox = New-Object System.Windows.Forms.GroupBox
$TargetGroupBox.Location = New-Object System.Drawing.Point(540, 50)
$TargetGroupBox.Size = New-Object System.Drawing.Size(500, 290)
$TargetGroupBox.Text = "Target Computers"
$TargetGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($TargetGroupBox)

# Single computer radio
$TargetSingleRadio = New-Object System.Windows.Forms.RadioButton
$TargetSingleRadio.Location = New-Object System.Drawing.Point(20, 30)
$TargetSingleRadio.Size = New-Object System.Drawing.Size(150, 20)
$TargetSingleRadio.Text = "Single Computer"
$TargetSingleRadio.Checked = $true
$TargetSingleRadio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetGroupBox.Controls.Add($TargetSingleRadio)

$TargetSingleTextBox = New-Object System.Windows.Forms.TextBox
$TargetSingleTextBox.Location = New-Object System.Drawing.Point(40, 55)
$TargetSingleTextBox.Size = New-Object System.Drawing.Size(300, 25)
$TargetSingleTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetGroupBox.Controls.Add($TargetSingleTextBox)

$TargetBrowseADButton = New-Object System.Windows.Forms.Button
$TargetBrowseADButton.Location = New-Object System.Drawing.Point(350, 53)
$TargetBrowseADButton.Size = New-Object System.Drawing.Size(130, 25)
$TargetBrowseADButton.Text = "Browse AD..."
$TargetBrowseADButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetGroupBox.Controls.Add($TargetBrowseADButton)

# Multiple computers radio
$TargetMultipleRadio = New-Object System.Windows.Forms.RadioButton
$TargetMultipleRadio.Location = New-Object System.Drawing.Point(20, 90)
$TargetMultipleRadio.Size = New-Object System.Drawing.Size(180, 20)
$TargetMultipleRadio.Text = "Multiple Computers (CSV)"
$TargetMultipleRadio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetGroupBox.Controls.Add($TargetMultipleRadio)

$TargetMultipleTextBox = New-Object System.Windows.Forms.TextBox
$TargetMultipleTextBox.Location = New-Object System.Drawing.Point(40, 115)
$TargetMultipleTextBox.Size = New-Object System.Drawing.Size(300, 25)
$TargetMultipleTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetMultipleTextBox.PlaceholderText = "Path to CSV file with computer names"
$TargetGroupBox.Controls.Add($TargetMultipleTextBox)

$TargetBrowseCSVButton = New-Object System.Windows.Forms.Button
$TargetBrowseCSVButton.Location = New-Object System.Drawing.Point(350, 113)
$TargetBrowseCSVButton.Size = New-Object System.Drawing.Size(130, 25)
$TargetBrowseCSVButton.Text = "Browse CSV..."
$TargetBrowseCSVButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetGroupBox.Controls.Add($TargetBrowseCSVButton)

# OU Selection radio
$TargetOURadio = New-Object System.Windows.Forms.RadioButton
$TargetOURadio.Location = New-Object System.Drawing.Point(20, 150)
$TargetOURadio.Size = New-Object System.Drawing.Size(180, 20)
$TargetOURadio.Text = "Active Directory OU"
$TargetOURadio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetGroupBox.Controls.Add($TargetOURadio)

$TargetOUComboBox = New-Object System.Windows.Forms.ComboBox
$TargetOUComboBox.Location = New-Object System.Drawing.Point(40, 175)
$TargetOUComboBox.Size = New-Object System.Drawing.Size(440, 25)
$TargetOUComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetOUComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$TargetGroupBox.Controls.Add($TargetOUComboBox)

# Load OUs from config
try {
    if ($Script:OUs) {
        foreach ($OU in $Script:OUs) {
            $TargetOUComboBox.Items.Add($OU) | Out-Null
        }
        if ($TargetOUComboBox.Items.Count -gt 0) {
            $TargetOUComboBox.SelectedIndex = 0
        }
    }
} catch {
    # Silent fail
}

# Target count label
$TargetCountLabel = New-Object System.Windows.Forms.Label
$TargetCountLabel.Location = New-Object System.Drawing.Point(40, 210)
$TargetCountLabel.Size = New-Object System.Drawing.Size(440, 40)
$TargetCountLabel.Text = "Selected: 0 computers"
$TargetCountLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetCountLabel.ForeColor = [System.Drawing.Color]::Gray
$TargetGroupBox.Controls.Add($TargetCountLabel)

# Test connectivity button
$TargetTestButton = New-Object System.Windows.Forms.Button
$TargetTestButton.Location = New-Object System.Drawing.Point(40, 250)
$TargetTestButton.Size = New-Object System.Drawing.Size(150, 30)
$TargetTestButton.Text = "Test Connectivity"
$TargetTestButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$TargetTestButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$TargetTestButton.ForeColor = [System.Drawing.Color]::White
$TargetTestButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TargetGroupBox.Controls.Add($TargetTestButton)

#------------------------------------------------------------------------------
# Deployment Options
#------------------------------------------------------------------------------

$DeployOptionsGroupBox = New-Object System.Windows.Forms.GroupBox
$DeployOptionsGroupBox.Location = New-Object System.Drawing.Point(20, 350)
$DeployOptionsGroupBox.Size = New-Object System.Drawing.Size(500, 120)
$DeployOptionsGroupBox.Text = "Deployment Options"
$DeployOptionsGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($DeployOptionsGroupBox)

# Auto-reboot checkbox
$DeployAutoRebootCheckBox = New-Object System.Windows.Forms.CheckBox
$DeployAutoRebootCheckBox.Location = New-Object System.Drawing.Point(20, 30)
$DeployAutoRebootCheckBox.Size = New-Object System.Drawing.Size(200, 20)
$DeployAutoRebootCheckBox.Text = "Auto-reboot after installation"
$DeployAutoRebootCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployAutoRebootCheckBox.Checked = $false
$DeployOptionsGroupBox.Controls.Add($DeployAutoRebootCheckBox)

# Reboot delay
$DeployRebootDelayLabel = New-Object System.Windows.Forms.Label
$DeployRebootDelayLabel.Location = New-Object System.Drawing.Point(40, 55)
$DeployRebootDelayLabel.Size = New-Object System.Drawing.Size(150, 20)
$DeployRebootDelayLabel.Text = "Reboot delay (minutes):"
$DeployRebootDelayLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployOptionsGroupBox.Controls.Add($DeployRebootDelayLabel)

$DeployRebootDelayNumeric = New-Object System.Windows.Forms.NumericUpDown
$DeployRebootDelayNumeric.Location = New-Object System.Drawing.Point(190, 53)
$DeployRebootDelayNumeric.Size = New-Object System.Drawing.Size(60, 25)
$DeployRebootDelayNumeric.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployRebootDelayNumeric.Minimum = 1
$DeployRebootDelayNumeric.Maximum = 60
$DeployRebootDelayNumeric.Value = 5
$DeployOptionsGroupBox.Controls.Add($DeployRebootDelayNumeric)

# Log location
$DeployLogLabel = New-Object System.Windows.Forms.Label
$DeployLogLabel.Location = New-Object System.Drawing.Point(20, 85)
$DeployLogLabel.Size = New-Object System.Drawing.Size(460, 20)
$DeployLogLabel.Text = "Logs: C:\PatchManagement\Logs\"
$DeployLogLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$DeployLogLabel.ForeColor = [System.Drawing.Color]::Gray
$DeployOptionsGroupBox.Controls.Add($DeployLogLabel)

#------------------------------------------------------------------------------
# Action Buttons
#------------------------------------------------------------------------------

$DeployActionGroupBox = New-Object System.Windows.Forms.GroupBox
$DeployActionGroupBox.Location = New-Object System.Drawing.Point(540, 350)
$DeployActionGroupBox.Size = New-Object System.Drawing.Size(500, 120)
$DeployActionGroupBox.Text = "Actions"
$DeployActionGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($DeployActionGroupBox)

# Deploy button
$DeployButton = New-Object System.Windows.Forms.Button
$DeployButton.Location = New-Object System.Drawing.Point(20, 30)
$DeployButton.Size = New-Object System.Drawing.Size(220, 40)
$DeployButton.Text = "Deploy Update"
$DeployButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$DeployButton.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$DeployButton.ForeColor = [System.Drawing.Color]::White
$DeployButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DeployActionGroupBox.Controls.Add($DeployButton)

# Create USB Package button
$DeployUSBButton = New-Object System.Windows.Forms.Button
$DeployUSBButton.Location = New-Object System.Drawing.Point(260, 30)
$DeployUSBButton.Size = New-Object System.Drawing.Size(220, 40)
$DeployUSBButton.Text = "Create USB Package"
$DeployUSBButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$DeployUSBButton.BackColor = [System.Drawing.Color]::FromArgb(243, 156, 18)
$DeployUSBButton.ForeColor = [System.Drawing.Color]::White
$DeployUSBButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DeployActionGroupBox.Controls.Add($DeployUSBButton)

# View logs button
$DeployViewLogsButton = New-Object System.Windows.Forms.Button
$DeployViewLogsButton.Location = New-Object System.Drawing.Point(20, 75)
$DeployViewLogsButton.Size = New-Object System.Drawing.Size(150, 30)
$DeployViewLogsButton.Text = "View Logs"
$DeployViewLogsButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployViewLogsButton.BackColor = [System.Drawing.Color]::FromArgb(127, 140, 141)
$DeployViewLogsButton.ForeColor = [System.Drawing.Color]::White
$DeployViewLogsButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DeployActionGroupBox.Controls.Add($DeployViewLogsButton)

# Open repository button
$DeployOpenRepoButton = New-Object System.Windows.Forms.Button
$DeployOpenRepoButton.Location = New-Object System.Drawing.Point(180, 75)
$DeployOpenRepoButton.Size = New-Object System.Drawing.Size(150, 30)
$DeployOpenRepoButton.Text = "Open Repository"
$DeployOpenRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployOpenRepoButton.BackColor = [System.Drawing.Color]::FromArgb(127, 140, 141)
$DeployOpenRepoButton.ForeColor = [System.Drawing.Color]::White
$DeployOpenRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DeployActionGroupBox.Controls.Add($DeployOpenRepoButton)

# Help button
$DeployHelpButton = New-Object System.Windows.Forms.Button
$DeployHelpButton.Location = New-Object System.Drawing.Point(340, 75)
$DeployHelpButton.Size = New-Object System.Drawing.Size(140, 30)
$DeployHelpButton.Text = "Help"
$DeployHelpButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$DeployHelpButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$DeployHelpButton.ForeColor = [System.Drawing.Color]::White
$DeployHelpButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$DeployActionGroupBox.Controls.Add($DeployHelpButton)

#------------------------------------------------------------------------------
# Status and Progress
#------------------------------------------------------------------------------

$DeployStatusLabel = New-Object System.Windows.Forms.Label
$DeployStatusLabel.Location = New-Object System.Drawing.Point(20, 480)
$DeployStatusLabel.Size = New-Object System.Drawing.Size(1020, 25)
$DeployStatusLabel.Text = "Ready to deploy"
$DeployStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$DeployStatusLabel.ForeColor = [System.Drawing.Color]::Gray
$TabDeploy.Controls.Add($DeployStatusLabel)

$DeployProgressBar = New-Object System.Windows.Forms.ProgressBar
$DeployProgressBar.Location = New-Object System.Drawing.Point(20, 510)
$DeployProgressBar.Size = New-Object System.Drawing.Size(1020, 25)
$DeployProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$TabDeploy.Controls.Add($DeployProgressBar)

# Results text box
$DeployResultsLabel = New-Object System.Windows.Forms.Label
$DeployResultsLabel.Location = New-Object System.Drawing.Point(20, 545)
$DeployResultsLabel.Size = New-Object System.Drawing.Size(200, 20)
$DeployResultsLabel.Text = "Deployment Results:"
$DeployResultsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($DeployResultsLabel)

$DeployResultsTextBox = New-Object System.Windows.Forms.TextBox
$DeployResultsTextBox.Location = New-Object System.Drawing.Point(20, 570)
$DeployResultsTextBox.Size = New-Object System.Drawing.Size(1020, 80)
$DeployResultsTextBox.Multiline = $true
$DeployResultsTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$DeployResultsTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$DeployResultsTextBox.ReadOnly = $true
$DeployResultsTextBox.BackColor = [System.Drawing.Color]::White
$TabDeploy.Controls.Add($DeployResultsTextBox)

#==============================================================================
# EVENT HANDLERS
#==============================================================================

# Refresh available updates
$FileRefreshButton.Add_Click({
    $FileUpdatesListBox.Items.Clear()
    $DeployStatusLabel.Text = "Scanning repository..."
    $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    $RepoPath = $FileRepoTextBox.Text
    
    if (-not (Test-Path $RepoPath)) {
        $DeployStatusLabel.Text = "ERROR: Cannot access repository: $RepoPath"
        $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        return
    }
    
    try {
        # Search for .msu files
        $Updates = Get-ChildItem -Path "$RepoPath\*\*\*.msu" -ErrorAction Stop
        
        if ($Updates.Count -eq 0) {
            $DeployStatusLabel.Text = "No updates found in repository"
            $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Orange
            return
        }
        
        foreach ($Update in $Updates) {
            # Extract KB from filename
            if ($Update.Name -match '(KB\d+)') {
                $KB = $Matches[1]
            } else {
                $KB = $Update.BaseName
            }
            
            # Get OS from path
            $OS = "Unknown"
            if ($Update.DirectoryName -match 'Windows10') { $OS = "Win10" }
            elseif ($Update.DirectoryName -match 'Windows11') { $OS = "Win11" }
            elseif ($Update.DirectoryName -match 'Server2019') { $OS = "Srv2019" }
            elseif ($Update.DirectoryName -match 'Server2022') { $OS = "Srv2022" }
            
            # Get month
            if ($Update.DirectoryName -match '(\d{4}-\d{2})') {
                $Month = $Matches[1]
            } else {
                $Month = "Unknown"
            }
            
            $SizeMB = [math]::Round($Update.Length / 1MB, 0)
            
            $DisplayText = "$KB [$OS] [$Month] ($SizeMB MB)"
            $FileUpdatesListBox.Items.Add($DisplayText) | Out-Null
            
            # Store full path in tag
            $FileUpdatesListBox.Items[$FileUpdatesListBox.Items.Count - 1] = $Update.FullName
        }
        
        $DeployStatusLabel.Text = "Found $($Updates.Count) update(s) in repository"
        $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        
    } catch {
        $DeployStatusLabel.Text = "ERROR: Failed to scan repository - $_"
        $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Browse repository
$FileBrowseRepoButton.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select Update Repository"
    $FolderBrowser.ShowNewFolderButton = $false
    
    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $FileRepoTextBox.Text = $FolderBrowser.SelectedPath
        $FileRefreshButton.PerformClick()
    }
})

# Browse CSV
$TargetBrowseCSVButton.Add_Click({
    $OpenFile = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFile.Filter = "CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $OpenFile.Title = "Select Computer List"
    
    if ($OpenFile.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TargetMultipleTextBox.Text = $OpenFile.FileName
        $TargetMultipleRadio.Checked = $true
        
        # Count computers in CSV
        try {
            $Computers = Import-Csv $OpenFile.FileName
            $TargetCountLabel.Text = "Selected: $($Computers.Count) computers from CSV"
            $TargetCountLabel.ForeColor = [System.Drawing.Color]::Green
        } catch {
            $TargetCountLabel.Text = "ERROR: Invalid CSV format"
            $TargetCountLabel.ForeColor = [System.Drawing.Color]::Red
        }
    }
})

# Test connectivity
$TargetTestButton.Add_Click({
    $DeployStatusLabel.Text = "Testing connectivity..."
    $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    $DeployResultsTextBox.Clear()
    [System.Windows.Forms.Application]::DoEvents()
    
    # Get target computers
    $Targets = @()
    
    if ($TargetSingleRadio.Checked) {
        $Targets = @($TargetSingleTextBox.Text.Trim())
    } elseif ($TargetMultipleRadio.Checked) {
        $CSVPath = $TargetMultipleTextBox.Text
        if (Test-Path $CSVPath) {
            $CSV = Import-Csv $CSVPath
            $Targets = $CSV.ComputerName
        }
    } elseif ($TargetOURadio.Checked) {
        $OU = $TargetOUComboBox.SelectedItem
        if ($OU) {
            $Targets = Get-ADComputer -Filter * -SearchBase $OU | Select-Object -ExpandProperty Name
        }
    }
    
    if ($Targets.Count -eq 0) {
        $DeployStatusLabel.Text = "No targets specified"
        $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        return
    }
    
    $Online = 0
    $Offline = 0
    
    foreach ($Target in $Targets) {
        if ([string]::IsNullOrEmpty($Target)) { continue }
        
        $Result = Test-Connection -ComputerName $Target -Count 1 -Quiet
        
        if ($Result) {
            $DeployResultsTextBox.AppendText("✓ $Target - Online`r`n")
            $Online++
        } else {
            $DeployResultsTextBox.AppendText("✗ $Target - Offline`r`n")
            $Offline++
        }
        
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    $DeployStatusLabel.Text = "Test complete: $Online online, $Offline offline"
    $DeployStatusLabel.ForeColor = $(if($Offline -gt 0){"Orange"}else{"Green"})
})

# Deploy button
$DeployButton.Add_Click({
    # Validation
    if ($DeployMethodFile.Checked -and $FileUpdatesListBox.SelectedIndex -eq -1) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an update to deploy.",
            "No Update Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Get targets
    $Targets = @()
    
    if ($TargetSingleRadio.Checked) {
        if ([string]::IsNullOrWhiteSpace($TargetSingleTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a computer name.", "No Target", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $Targets = @($TargetSingleTextBox.Text.Trim())
    } elseif ($TargetMultipleRadio.Checked) {
        $CSVPath = $TargetMultipleTextBox.Text
        if (-not (Test-Path $CSVPath)) {
            [System.Windows.Forms.MessageBox]::Show("CSV file not found.", "File Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $CSV = Import-Csv $CSVPath
        $Targets = $CSV.ComputerName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    } elseif ($TargetOURadio.Checked) {
        $OU = $TargetOUComboBox.SelectedItem
        if (-not $OU) {
            [System.Windows.Forms.MessageBox]::Show("Please select an OU.", "No OU Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $Targets = Get-ADComputer -Filter * -SearchBase $OU | Select-Object -ExpandProperty Name
    }
    
    if ($Targets.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No target computers found.", "No Targets", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Confirm
    $Result = [System.Windows.Forms.MessageBox]::Show(
        "Deploy update to $($Targets.Count) computer(s)?`n`nThis will:`n- Copy update file to targets`n- Install using WUSA`n- $(if($DeployAutoRebootCheckBox.Checked){'Reboot after installation'}else{'No automatic reboot'})",
        "Confirm Deployment",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($Result -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }
    
    # Get update path
    $UpdatePath = $FileUpdatesListBox.SelectedItem
    
    # Start deployment
    $DeployResultsTextBox.Clear()
    $DeployProgressBar.Value = 0
    $DeployProgressBar.Maximum = $Targets.Count
    
    $DeployStatusLabel.Text = "Deploying to $($Targets.Count) computer(s)..."
    $DeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    
    $Success = 0
    $Failed = 0
    $Offline = 0
    
    foreach ($Target in $Targets) {
        $DeployStatusLabel.Text = "Deploying to: $Target"
        [System.Windows.Forms.Application]::DoEvents()
        
        # Call deployment script
        $ScriptPath = Join-Path $Script:BaseDirectory "Scripts\Deploy-FileBasedUpdate.ps1"
        
        if (Test-Path $ScriptPath) {
            try {
                $DeployResult = & $ScriptPath -ComputerName $Target -UpdatePath $UpdatePath -AutoReboot:$DeployAutoRebootCheckBox.Checked -ErrorAction Stop
                
                if ($DeployResult.Success) {
                    $DeployResultsTextBox.AppendText("✓ $Target - SUCCESS`r`n")
                    $Success++
                } else {
                    $DeployResultsTextBox.AppendText("✗ $Target - FAILED: $($DeployResult.Error)`r`n")
                    $Failed++
                }
            } catch {
                $DeployResultsTextBox.AppendText("✗ $Target - ERROR: $_`r`n")
                $Failed++
            }
        } else {
            $DeployResultsTextBox.AppendText("✗ $Target - Script not found`r`n")
            $Failed++
        }
        
        $DeployProgressBar.Value++
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    $DeployStatusLabel.Text = "Deployment complete: $Success success, $Failed failed"
    $DeployStatusLabel.ForeColor = $(if($Failed -gt 0){"Orange"}else{"Green"})
    
    $DeployResultsTextBox.AppendText("`r`n========================================`r`n")
    $DeployResultsTextBox.AppendText("Summary: $Success success, $Failed failed`r`n")
})

# Create USB Package
$DeployUSBButton.Add_Click({
    if ($FileUpdatesListBox.SelectedIndex -eq -1) {
        [System.Windows.Forms.MessageBox]::Show("Please select an update.", "No Update", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $UpdatePath = $FileUpdatesListBox.SelectedItem
    $UpdateFile = Get-Item $UpdatePath
    
    # Create USB package folder
    $USBPackagePath = Join-Path $Script:BaseDirectory "USBPackages\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -Path $USBPackagePath -ItemType Directory -Force | Out-Null
    
    # Copy update file
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
    echo Please reboot this computer to complete installation.
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
    
    # Show result
    [System.Windows.Forms.MessageBox]::Show(
        "USB Package created!`n`nLocation: $USBPackagePath`n`nCopy this folder to USB drive and run INSTALL.bat on field machines.",
        "USB Package Ready",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    # Open folder
    Start-Process "explorer.exe" -ArgumentList $USBPackagePath
})

# View logs
$DeployViewLogsButton.Add_Click({
    $LogsPath = Join-Path $Script:BaseDirectory "Logs"
    if (Test-Path $LogsPath) {
        Start-Process "explorer.exe" -ArgumentList $LogsPath
    } else {
        [System.Windows.Forms.MessageBox]::Show("Logs folder not found.", "Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

# Open repository
$DeployOpenRepoButton.Add_Click({
    $RepoPath = $FileRepoTextBox.Text
    if (Test-Path $RepoPath) {
        Start-Process "explorer.exe" -ArgumentList $RepoPath
    } else {
        [System.Windows.Forms.MessageBox]::Show("Repository not found: $RepoPath", "Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

# Help button
$DeployHelpButton.Add_Click({
    $HelpText = @"
FILE-BASED UPDATE DEPLOYMENT

SETUP:
1. Run Setup-FileBasedRepository.ps1 on WINUP1
2. Download .msu files from Microsoft Update Catalog
3. Save to \\QBE-DEN-WINUP1\UpdateFiles\[OS]\[Month]

NETWORK DEPLOYMENT:
1. Click "Refresh Updates" to scan repository
2. Select update from list
3. Choose target computers
4. Click "Deploy Update"

USB DEPLOYMENT (Field Machines):
1. Select update from list
2. Click "Create USB Package"
3. Copy folder to USB drive
4. On field machine: Run INSTALL.bat

BENEFITS:
✓ Works offline (USB deployment)
✓ No WSUS complexity
✓ Perfect for field machines
✓ Simple file management

For full documentation, see:
File-Based-Update-Management-Guide.md
"@
    
    [System.Windows.Forms.MessageBox]::Show($HelpText, "File-Based Deployment Help", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Auto-load updates when tab is opened
$TabControl.Add_SelectedIndexChanged({
    if ($TabControl.SelectedTab -eq $TabDeploy -and $DeployMethodFile.Checked) {
        if ($FileUpdatesListBox.Items.Count -eq 0) {
            $FileRefreshButton.PerformClick()
        }
    }
})
