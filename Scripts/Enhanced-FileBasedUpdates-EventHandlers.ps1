# Enhanced Event Handlers for File-Based Updates
# Add these after the ViewLogsButton event handler in your GUI

# ============================================================
# ENHANCED FILE-BASED UPDATES EVENT HANDLERS
# ============================================================

# Global variable for auto-refresh timer
$Script:AutoRefreshTimer = $null

# Enhanced helper function to load updates from repository
function Global:Load-RepositoryUpdates {
    param(
        [string]$RepositoryPath,
        [string]$OSFilter = "All",
        [bool]$Silent = $false
    )
    
    $UpdatesListView.Items.Clear()
    
    if (-not $Silent) {
        $FileDeployStatusLabel.Text = "🔄 Scanning repository..."
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
        $RefreshRepoButton.Enabled = $false
        $RefreshRepoButton.Text = "⏳ Scanning..."
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    if (-not (Test-Path $RepositoryPath)) {
        $FileDeployStatusLabel.Text = "❌ ERROR: Cannot access repository: $RepositoryPath"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        $LastRefreshLabel.Text = "Last refreshed: Failed - Repository not accessible"
        $LastRefreshLabel.ForeColor = [System.Drawing.Color]::Red
        $RefreshRepoButton.Enabled = $true
        $RefreshRepoButton.Text = "🔄 Refresh Updates"
        return
    }
    
    # Build search patterns
    $SearchPaths = @()
    
    if ($OSFilter -eq "All" -or $OSFilter -eq "Win10") {
        $SearchPaths += "$RepositoryPath\Windows10\*\*.msu"
    }
    if ($OSFilter -eq "All" -or $OSFilter -eq "Win11") {
        $SearchPaths += "$RepositoryPath\Windows11\*\*.msu"
    }
    if ($OSFilter -eq "All" -or $OSFilter -eq "Srv19") {
        $SearchPaths += "$RepositoryPath\Server2019\*\*.msu"
    }
    if ($OSFilter -eq "All" -or $OSFilter -eq "Srv22") {
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
            if ($File.FullName -match '\\Windows10\\') { $OS = "Windows 10" }
            elseif ($File.FullName -match '\\Windows11\\') { $OS = "Windows 11" }
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
    
    # Update status
    $RefreshRepoButton.Enabled = $true
    $RefreshRepoButton.Text = "🔄 Refresh Updates"
    
    if ($UpdateCount -eq 0) {
        $FileDeployStatusLabel.Text = "⚠️ No updates found - Add .msu files to repository and refresh"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Orange
    } else {
        $FileDeployStatusLabel.Text = "✅ Found $UpdateCount update(s) - Ready to deploy"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
    }
    
    # Update last refresh timestamp
    $LastRefreshLabel.Text = "Last refreshed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Found $UpdateCount update(s)"
    $LastRefreshLabel.ForeColor = [System.Drawing.Color]::Green
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

# ENHANCED: Refresh/Scan Repository
$RefreshRepoButton.Add_Click({
    Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
})

# OS Filter Changed
$OSFilterComboBox.Add_SelectedIndexChanged({
    if ($UpdatesListView.Items.Count -gt 0 -or (Test-Path $RepoPathTextBox.Text)) {
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
    }
})

# NEW: Auto-refresh checkbox handler
$AutoRefreshCheckBox.Add_CheckedChanged({
    if ($AutoRefreshCheckBox.Checked) {
        # Start auto-refresh timer (5 minutes = 300000 ms)
        if ($Script:AutoRefreshTimer) {
            $Script:AutoRefreshTimer.Stop()
            $Script:AutoRefreshTimer.Dispose()
        }
        
        $Script:AutoRefreshTimer = New-Object System.Windows.Forms.Timer
        $Script:AutoRefreshTimer.Interval = 300000  # 5 minutes
        $Script:AutoRefreshTimer.Add_Tick({
            Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem -Silent $true
        })
        $Script:AutoRefreshTimer.Start()
        
        $FileDeployStatusLabel.Text = "🔄 Auto-refresh enabled (every 5 minutes)"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
        
        # Do an immediate refresh
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
    }
    else {
        # Stop auto-refresh timer
        if ($Script:AutoRefreshTimer) {
            $Script:AutoRefreshTimer.Stop()
            $Script:AutoRefreshTimer.Dispose()
            $Script:AutoRefreshTimer = $null
        }
        
        $FileDeployStatusLabel.Text = "Auto-refresh disabled"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Gray
    }
})

# NEW: F5 key handler for entire form
$Form.Add_KeyDown({
    param($sender, $e)
    
    # Check if F5 was pressed and we're on the Deploy tab
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::F5 -and $TabControl.SelectedTab -eq $TabDeploy) {
        # Refresh the repository
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
        
        # Prevent default F5 behavior
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

# Make form accept keyboard input
$Form.KeyPreview = $true

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
    $ComputerName = $ComputerNameTextBox.Text.Trim()
    
    if ([string]::IsNullOrEmpty($ComputerName)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter a computer name in the 'Deploy to Individual Machine' section.",
            "Computer Name Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Confirm
    $Result = [System.Windows.Forms.MessageBox]::Show(
        "Deploy $KB to $ComputerName?`n`nFile: $(Split-Path $UpdatePath -Leaf)`nSize: $($SelectedItem.SubItems[4].Text) MB`n`nThis will:`n- Copy update to target`n- Install using WUSA`n- May require reboot",
        "Confirm Deployment",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($Result -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }
    
    $FileDeployStatusLabel.Text = "⏳ Deploying $KB to $ComputerName..."
    $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Blue
    [System.Windows.Forms.Application]::DoEvents()
    
    # Call deployment script
    $DeployScript = Join-Path $Script:BaseDirectory "Scripts\Deploy-FileBasedUpdate.ps1"
    
    if (-not (Test-Path $DeployScript)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Deployment script not found:`n$DeployScript`n`nPlease run Deploy-FileBasedScripts.ps1",
            "Script Missing",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }
    
    try {
        $DeployResult = & $DeployScript -ComputerName $ComputerName -UpdatePath $UpdatePath -ErrorAction Stop
        
        if ($DeployResult.Success) {
            $FileDeployStatusLabel.Text = "✅ SUCCESS: $KB deployed to $ComputerName"
            if ($DeployResult.RebootRequired) {
                $FileDeployStatusLabel.Text += " (Reboot required)"
            }
            $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
            
            # Add to output
            $DeployOutputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: $KB deployed to $ComputerName`n")
        } else {
            $FileDeployStatusLabel.Text = "❌ FAILED: $($DeployResult.Error)"
            $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
            
            # Add to output
            $DeployOutputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] FAILED: $KB to $ComputerName - $($DeployResult.Error)`n")
        }
        
    } catch {
        $FileDeployStatusLabel.Text = "❌ ERROR: $_"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
        
        # Add to output
        $DeployOutputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ERROR: $KB to $ComputerName - $_`n")
    }
})

# Create USB Package
$CreateUSBButton.Add_Click({
    if ($UpdatesListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select an update.",
            "No Update Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $SelectedItem = $UpdatesListView.SelectedItems[0]
    $UpdatePath = $SelectedItem.Tag
    
    # Create package folder
    $USBPackagesDir = Join-Path $Script:BaseDirectory "USBPackages"
    if (-not (Test-Path $USBPackagesDir)) {
        New-Item -Path $USBPackagesDir -ItemType Directory -Force | Out-Null
    }
    
    $USBPackagePath = Join-Path $USBPackagesDir (Get-Date -Format 'yyyyMMdd-HHmmss')
    New-Item -Path $USBPackagePath -ItemType Directory -Force | Out-Null
    
    $FileDeployStatusLabel.Text = "📦 Creating USB package..."
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
KB: $($SelectedItem.Text)
Product: $($SelectedItem.SubItems[1].Text)
Size: $($SelectedItem.SubItems[4].Text) MB
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

INSTRUCTIONS:
1. Copy this entire folder to USB drive
2. On target machine: Right-click INSTALL.bat and "Run as administrator"
3. Wait for installation to complete
4. Reboot when prompted

QB Energy Patch Management System
Repository: $($RepoPathTextBox.Text)
"@
        
        $ReadMe | Out-File -FilePath (Join-Path $USBPackagePath "README.txt") -Encoding UTF8
        
        $FileDeployStatusLabel.Text = "✅ SUCCESS: USB package created"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Green
        
        [System.Windows.Forms.MessageBox]::Show(
            "USB package created!`n`nLocation: $USBPackagePath`n`nCopy this folder to USB drive and run INSTALL.bat on field machines.",
            "Package Ready",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
        # Open folder
        Start-Process "explorer.exe" -ArgumentList $USBPackagePath
        
    } catch {
        $FileDeployStatusLabel.Text = "❌ ERROR: $_"
        $FileDeployStatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
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
$FileBasedHelpButton.Add_Click({
    $HelpText = @"
FILE-BASED UPDATE DEPLOYMENT HELP

REFRESH UPDATES:
• Click 'Refresh Updates' button or press F5
• Enable 'Auto (5m)' for automatic refresh every 5 minutes
• Repository scans for new .msu files when refreshed

SETUP:
1. Run Setup-FileBasedRepository.ps1 on WINUP1
2. Download .msu files from Microsoft Update Catalog
3. Save to: \\QBE-DEN-WINUP1\UpdateFiles\[OS]\[Month]\
4. Click 'Refresh Updates' to see new files

NETWORK DEPLOYMENT:
1. Enter computer name in 'Deploy to Individual Machine' section
2. Click "Refresh Updates" to find available updates
3. Select update from list
4. Click "Deploy Selected"
5. Wait for completion

USB DEPLOYMENT (for field machines):
1. Select update from list
2. Click "Create USB Package"
3. Copy package folder to USB drive
4. On field machine: Run INSTALL.bat as administrator
5. Reboot when prompted

KEYBOARD SHORTCUTS:
• F5 - Refresh update list

REPOSITORY STRUCTURE:
\\QBE-DEN-WINUP1\UpdateFiles\
├── Windows10\YYYY-MM\*.msu
├── Windows11\YYYY-MM\*.msu
├── Server2019\YYYY-MM\*.msu
└── Server2022\YYYY-MM\*.msu

TIPS:
• Use auto-refresh when actively downloading updates
• Press F5 after adding new files to repository
• Last refresh time shown below repository path

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

# Auto-load updates when Deploy tab is selected (but not every time)
$Script:DeployTabFirstLoad = $true
$TabControl.Add_SelectedIndexChanged({
    if ($TabControl.SelectedTab -eq $TabDeploy) {
        if ($Script:DeployTabFirstLoad) {
            # Only auto-load on first activation
            if (Test-Path $RepoPathTextBox.Text) {
                Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter "All" -Silent $true
            }
            $Script:DeployTabFirstLoad = $false
        }
    }
})

# Cleanup timer when form closes
$Form.Add_FormClosing({
    if ($Script:AutoRefreshTimer) {
        $Script:AutoRefreshTimer.Stop()
        $Script:AutoRefreshTimer.Dispose()
    }
})
