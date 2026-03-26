# Fixed-Handlers-Replacement.ps1
# Replaces the broken event handlers with working ones

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Event Handler Replacement Tool" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$GUIPath = "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"

# Backup
Write-Host "[1] Creating backup..." -ForegroundColor Yellow
$BackupPath = "$GUIPath.BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $GUIPath -Destination $BackupPath
Write-Host "    Saved: $BackupPath" -ForegroundColor Green

# Read file
Write-Host "`n[2] Reading GUI file..." -ForegroundColor Yellow
$Content = Get-Content $GUIPath -Raw

# Find and replace the Refresh handler
Write-Host "`n[3] Replacing Refresh handler..." -ForegroundColor Yellow

$OldRefreshHandler = @'
$RefreshRepoButton.Add_Click({
    Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
})
'@

$NewRefreshHandler = @'
$RefreshRepoButton.Add_Click({
    try {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "[REFRESH] Button clicked!" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        
        Write-Host "[REFRESH] Repository path: $($RepoPathTextBox.Text)" -ForegroundColor Gray
        Write-Host "[REFRESH] OS Filter: $($OSFilterComboBox.SelectedItem)" -ForegroundColor Gray
        
        # Check if controls exist
        if ($null -eq $RepoPathTextBox) {
            Write-Host "[ERROR] RepoPathTextBox is null!" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show("Error: RepoPathTextBox not found", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        if ($null -eq $OSFilterComboBox) {
            Write-Host "[ERROR] OSFilterComboBox is null!" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show("Error: OSFilterComboBox not found", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        $RepoPath = $RepoPathTextBox.Text
        $OSFilter = $OSFilterComboBox.SelectedItem
        
        if ([string]::IsNullOrWhiteSpace($RepoPath)) {
            Write-Host "[ERROR] Repository path is empty!" -ForegroundColor Red
            [System.Windows.Forms.MessageBox]::Show("Repository path is empty", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
        
        if ($null -eq $OSFilter) {
            Write-Host "[WARNING] OS Filter is null, using 'All'" -ForegroundColor Yellow
            $OSFilter = "All"
        }
        
        Write-Host "[REFRESH] Calling Load-RepositoryUpdates..." -ForegroundColor Cyan
        Load-RepositoryUpdates -RepositoryPath $RepoPath -OSFilter $OSFilter
        Write-Host "[REFRESH] Load-RepositoryUpdates completed" -ForegroundColor Green
        
    } catch {
        Write-Host "[ERROR] Exception in Refresh handler:" -ForegroundColor Red
        Write-Host "[ERROR] $_" -ForegroundColor Red
        Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "Error refreshing repository:`n`n$_`n`nCheck PowerShell console for details.",
            "Refresh Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})
'@

if ($Content -match [regex]::Escape($OldRefreshHandler)) {
    $Content = $Content -replace [regex]::Escape($OldRefreshHandler), $NewRefreshHandler
    Write-Host "    ✓ Refresh handler replaced" -ForegroundColor Green
} else {
    Write-Host "    ⚠ Could not find exact match for Refresh handler" -ForegroundColor Yellow
    Write-Host "    Trying alternate method..." -ForegroundColor Gray
    
    # Try to find and replace more liberally
    $Pattern = '\$RefreshRepoButton\.Add_Click\(\{[^\}]*Load-RepositoryUpdates[^\}]*\}\)'
    if ($Content -match $Pattern) {
        $Content = $Content -replace $Pattern, $NewRefreshHandler
        Write-Host "    ✓ Refresh handler replaced (alternate method)" -ForegroundColor Green
    } else {
        Write-Host "    ✗ Could not replace Refresh handler" -ForegroundColor Red
    }
}

# Find and replace the Browse handler
Write-Host "`n[4] Replacing Browse handler..." -ForegroundColor Yellow

$OldBrowseHandler = @'
$BrowseRepoButton.Add_Click({
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select Update Repository"
    $FolderBrowser.SelectedPath = $RepoPathTextBox.Text
    
    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $RepoPathTextBox.Text = $FolderBrowser.SelectedPath
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
    }
})
'@

$NewBrowseHandler = @'
$BrowseRepoButton.Add_Click({
    try {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "[BROWSE] Button clicked!" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        
        $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $FolderBrowser.Description = "Select Update Repository"
        $FolderBrowser.SelectedPath = $RepoPathTextBox.Text
        
        Write-Host "[BROWSE] Opening folder browser dialog..." -ForegroundColor Gray
        
        $DialogResult = $FolderBrowser.ShowDialog()
        Write-Host "[BROWSE] Dialog result: $DialogResult" -ForegroundColor Gray
        
        if ($DialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
            Write-Host "[BROWSE] User selected: $($FolderBrowser.SelectedPath)" -ForegroundColor Green
            $RepoPathTextBox.Text = $FolderBrowser.SelectedPath
            
            Write-Host "[BROWSE] Calling Load-RepositoryUpdates..." -ForegroundColor Cyan
            Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter $OSFilterComboBox.SelectedItem
        } else {
            Write-Host "[BROWSE] User cancelled" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "[ERROR] Exception in Browse handler:" -ForegroundColor Red
        Write-Host "[ERROR] $_" -ForegroundColor Red
        Write-Host "[ERROR] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
        
        [System.Windows.Forms.MessageBox]::Show(
            "Error opening folder browser:`n`n$_",
            "Browse Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})
'@

if ($Content -match [regex]::Escape($OldBrowseHandler)) {
    $Content = $Content -replace [regex]::Escape($OldBrowseHandler), $NewBrowseHandler
    Write-Host "    ✓ Browse handler replaced" -ForegroundColor Green
} else {
    Write-Host "    ⚠ Could not find exact match for Browse handler" -ForegroundColor Yellow
}

# Save
Write-Host "`n[5] Saving modified file..." -ForegroundColor Yellow
$Content | Out-File -FilePath $GUIPath -Encoding UTF8 -Force
Write-Host "    ✓ File saved" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Replacement Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Event handlers now have:" -ForegroundColor Green
Write-Host "  ✓ Full error handling (try/catch)" -ForegroundColor White
Write-Host "  ✓ Debug output to console" -ForegroundColor White
Write-Host "  ✓ Null checks for controls" -ForegroundColor White
Write-Host "  ✓ MessageBox popups for errors" -ForegroundColor White
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Launch GUI from PowerShell:" -ForegroundColor White
Write-Host "   cd C:\PatchManagement\Scripts" -ForegroundColor Gray
Write-Host "   .\PatchManagement-GUI.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Go to Deploy tab -> File-Based Updates section" -ForegroundColor White
Write-Host ""
Write-Host "3. Click 'Refresh Updates' button" -ForegroundColor White
Write-Host ""
Write-Host "4. Watch console for [REFRESH] messages" -ForegroundColor White
Write-Host ""
Write-Host "5. If you see [REFRESH] messages:" -ForegroundColor White
Write-Host "   - Handlers ARE firing now!" -ForegroundColor Green
Write-Host "   - Check console for any [ERROR] messages" -ForegroundColor Yellow
Write-Host ""
Write-Host "6. If error appears, we'll know exactly what's wrong!" -ForegroundColor White
Write-Host ""

Write-Host "Backup saved to:" -ForegroundColor Cyan
Write-Host "  $BackupPath`n" -ForegroundColor Gray
