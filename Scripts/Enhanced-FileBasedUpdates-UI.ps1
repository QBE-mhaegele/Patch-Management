# Enhanced File-Based Updates Section for PatchManagement-GUI.ps1
# Replaces the existing file-based section with better refresh controls

# ============================================================
# FILE-BASED UPDATES SECTION (ENHANCED - WUSA Deployment)
# ============================================================

# Separator Line
$FileSeparator = New-Object System.Windows.Forms.Label
$FileSeparator.Location = New-Object System.Drawing.Point(15, 425)
$FileSeparator.Size = New-Object System.Drawing.Size(1015, 2)
$FileSeparator.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$TabDeploy.Controls.Add($FileSeparator)

# File-Based Updates Group Box
$FileBasedGroupBox = New-Object System.Windows.Forms.GroupBox
$FileBasedGroupBox.Location = New-Object System.Drawing.Point(15, 435)
$FileBasedGroupBox.Size = New-Object System.Drawing.Size(1015, 200)
$FileBasedGroupBox.Text = "File-Based Updates (WUSA) - For Field Machines & Offline Deployment"
$FileBasedGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($FileBasedGroupBox)

# Repository Path
$RepoPathLabel = New-Object System.Windows.Forms.Label
$RepoPathLabel.Location = New-Object System.Drawing.Point(15, 30)
$RepoPathLabel.Size = New-Object System.Drawing.Size(100, 20)
$RepoPathLabel.Text = "Repository:"
$RepoPathLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileBasedGroupBox.Controls.Add($RepoPathLabel)

$RepoPathTextBox = New-Object System.Windows.Forms.TextBox
$RepoPathTextBox.Location = New-Object System.Drawing.Point(115, 28)
$RepoPathTextBox.Size = New-Object System.Drawing.Size(400, 25)
$RepoPathTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$RepoPathTextBox.Text = "\\QBE-DEN-WINUP1\UpdateFiles"
$FileBasedGroupBox.Controls.Add($RepoPathTextBox)

$BrowseRepoButton = New-Object System.Windows.Forms.Button
$BrowseRepoButton.Location = New-Object System.Drawing.Point(525, 26)
$BrowseRepoButton.Size = New-Object System.Drawing.Size(90, 28)
$BrowseRepoButton.Text = "Browse..."
$BrowseRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$BrowseRepoButton.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$BrowseRepoButton.ForeColor = [System.Drawing.Color]::White
$BrowseRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileBasedGroupBox.Controls.Add($BrowseRepoButton)

# ENHANCED: Larger, more prominent Refresh button
$RefreshRepoButton = New-Object System.Windows.Forms.Button
$RefreshRepoButton.Location = New-Object System.Drawing.Point(625, 26)
$RefreshRepoButton.Size = New-Object System.Drawing.Size(140, 28)
$RefreshRepoButton.Text = "🔄 Refresh Updates"
$RefreshRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$RefreshRepoButton.BackColor = [System.Drawing.Color]::FromArgb(46, 204, 113)
$RefreshRepoButton.ForeColor = [System.Drawing.Color]::White
$RefreshRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileBasedGroupBox.Controls.Add($RefreshRepoButton)

# OS Filter
$OSFilterLabel = New-Object System.Windows.Forms.Label
$OSFilterLabel.Location = New-Object System.Drawing.Point(785, 30)
$OSFilterLabel.Size = New-Object System.Drawing.Size(60, 20)
$OSFilterLabel.Text = "Filter OS:"
$OSFilterLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileBasedGroupBox.Controls.Add($OSFilterLabel)

$OSFilterComboBox = New-Object System.Windows.Forms.ComboBox
$OSFilterComboBox.Location = New-Object System.Drawing.Point(845, 27)
$OSFilterComboBox.Size = New-Object System.Drawing.Size(75, 25)
$OSFilterComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$OSFilterComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$OSFilterComboBox.Items.AddRange(@("All", "Win10", "Win11", "Srv19", "Srv22"))
$OSFilterComboBox.SelectedIndex = 0
$FileBasedGroupBox.Controls.Add($OSFilterComboBox)

# NEW: Auto-refresh checkbox
$AutoRefreshCheckBox = New-Object System.Windows.Forms.CheckBox
$AutoRefreshCheckBox.Location = New-Object System.Drawing.Point(930, 29)
$AutoRefreshCheckBox.Size = New-Object System.Drawing.Size(80, 20)
$AutoRefreshCheckBox.Text = "Auto (5m)"
$AutoRefreshCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$AutoRefreshCheckBox.Checked = $false
$FileBasedGroupBox.Controls.Add($AutoRefreshCheckBox)

# NEW: Last refresh timestamp label
$LastRefreshLabel = New-Object System.Windows.Forms.Label
$LastRefreshLabel.Location = New-Object System.Drawing.Point(15, 58)
$LastRefreshLabel.Size = New-Object System.Drawing.Size(450, 15)
$LastRefreshLabel.Text = "Last refreshed: Never (Press F5 or click Refresh)"
$LastRefreshLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Italic)
$LastRefreshLabel.ForeColor = [System.Drawing.Color]::Gray
$FileBasedGroupBox.Controls.Add($LastRefreshLabel)

# Updates List (adjusted Y position)
$UpdatesListView = New-Object System.Windows.Forms.ListView
$UpdatesListView.Location = New-Object System.Drawing.Point(15, 78)
$UpdatesListView.Size = New-Object System.Drawing.Size(980, 72)
$UpdatesListView.Font = New-Object System.Drawing.Font("Consolas", 8)
$UpdatesListView.View = [System.Windows.Forms.View]::Details
$UpdatesListView.FullRowSelect = $true
$UpdatesListView.GridLines = $true
$UpdatesListView.MultiSelect = $false
$UpdatesListView.Columns.Add("KB", 80) | Out-Null
$UpdatesListView.Columns.Add("Product", 120) | Out-Null
$UpdatesListView.Columns.Add("Month", 70) | Out-Null
$UpdatesListView.Columns.Add("File Name", 400) | Out-Null
$UpdatesListView.Columns.Add("Size (MB)", 80) | Out-Null
$UpdatesListView.Columns.Add("Date", 80) | Out-Null
$FileBasedGroupBox.Controls.Add($UpdatesListView)

# Action Buttons (adjusted Y position)
$DeployFileUpdateButton = New-Object System.Windows.Forms.Button
$DeployFileUpdateButton.Location = New-Object System.Drawing.Point(15, 160)
$DeployFileUpdateButton.Size = New-Object System.Drawing.Size(150, 30)
$DeployFileUpdateButton.Text = "Deploy Selected"
$DeployFileUpdateButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$DeployFileUpdateButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$DeployFileUpdateButton.ForeColor = [System.Drawing.Color]::White
$DeployFileUpdateButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileBasedGroupBox.Controls.Add($DeployFileUpdateButton)

$CreateUSBButton = New-Object System.Windows.Forms.Button
$CreateUSBButton.Location = New-Object System.Drawing.Point(175, 160)
$CreateUSBButton.Size = New-Object System.Drawing.Size(150, 30)
$CreateUSBButton.Text = "Create USB Package"
$CreateUSBButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$CreateUSBButton.BackColor = [System.Drawing.Color]::FromArgb(243, 156, 18)
$CreateUSBButton.ForeColor = [System.Drawing.Color]::White
$CreateUSBButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileBasedGroupBox.Controls.Add($CreateUSBButton)

$OpenRepoButton = New-Object System.Windows.Forms.Button
$OpenRepoButton.Location = New-Object System.Drawing.Point(335, 160)
$OpenRepoButton.Size = New-Object System.Drawing.Size(140, 30)
$OpenRepoButton.Text = "Open Repository"
$OpenRepoButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$OpenRepoButton.BackColor = [System.Drawing.Color]::FromArgb(149, 165, 166)
$OpenRepoButton.ForeColor = [System.Drawing.Color]::White
$OpenRepoButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileBasedGroupBox.Controls.Add($OpenRepoButton)

$FileBasedHelpButton = New-Object System.Windows.Forms.Button
$FileBasedHelpButton.Location = New-Object System.Drawing.Point(485, 160)
$FileBasedHelpButton.Size = New-Object System.Drawing.Size(80, 30)
$FileBasedHelpButton.Text = "Help"
$FileBasedHelpButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$FileBasedHelpButton.BackColor = [System.Drawing.Color]::FromArgb(52, 152, 219)
$FileBasedHelpButton.ForeColor = [System.Drawing.Color]::White
$FileBasedHelpButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$FileBasedGroupBox.Controls.Add($FileBasedHelpButton)

# Status Label
$FileDeployStatusLabel = New-Object System.Windows.Forms.Label
$FileDeployStatusLabel.Location = New-Object System.Drawing.Point(575, 165)
$FileDeployStatusLabel.Size = New-Object System.Drawing.Size(420, 20)
$FileDeployStatusLabel.Text = "Ready - Add .msu files to repository and click Refresh (F5)"
$FileDeployStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Gray
$FileBasedGroupBox.Controls.Add($FileDeployStatusLabel)

# Deployment Output (keep existing position)
$DeployOutputGroupBox = New-Object System.Windows.Forms.GroupBox
$DeployOutputGroupBox.Location = New-Object System.Drawing.Point(15, 645)
$DeployOutputGroupBox.Size = New-Object System.Drawing.Size(1015, 80)
$DeployOutputGroupBox.Text = "Deployment Output"
$DeployOutputGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$TabDeploy.Controls.Add($DeployOutputGroupBox)

$DeployOutputTextBox = New-Object System.Windows.Forms.RichTextBox
$DeployOutputTextBox.Location = New-Object System.Drawing.Point(10, 25)
$DeployOutputTextBox.Size = New-Object System.Drawing.Size(995, 45)
$DeployOutputTextBox.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
$DeployOutputTextBox.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$DeployOutputTextBox.ForeColor = [System.Drawing.Color]::White
$DeployOutputTextBox.ReadOnly = $true
$DeployOutputTextBox.ScrollBars = "Vertical"
$DeployOutputGroupBox.Controls.Add($DeployOutputTextBox)
