# Add-MessageBox-Test.ps1
# Adds MessageBox popup to prove if handlers are firing

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Add MessageBox Test to Handlers" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$GUIPath = "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"

# Backup
Write-Host "[1] Creating backup..." -ForegroundColor Yellow
$Backup = "$GUIPath.BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $GUIPath $Backup
Write-Host "    Saved: $Backup" -ForegroundColor Green

# Read file
Write-Host "`n[2] Reading GUI file..." -ForegroundColor Yellow
$Lines = Get-Content $GUIPath

# Find the RefreshRepoButton.Add_Click line and add MessageBox right after the opening brace
Write-Host "`n[3] Adding MessageBox to RefreshRepoButton handler..." -ForegroundColor Yellow

$NewLines = @()
for ($i = 0; $i -lt $Lines.Count; $i++) {
    $NewLines += $Lines[$i]
    
    # If this is the RefreshRepoButton.Add_Click line
    if ($Lines[$i] -match '\$RefreshRepoButton\.Add_Click\(\{') {
        # Add MessageBox right after
        $NewLines += '    [System.Windows.Forms.MessageBox]::Show("REFRESH BUTTON HANDLER FIRED!", "Test", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)'
        Write-Host "    Added MessageBox at line $($i+2)" -ForegroundColor Green
    }
    
    # If this is the BrowseRepoButton.Add_Click line
    if ($Lines[$i] -match '\$BrowseRepoButton\.Add_Click\(\{') {
        # Add MessageBox right after
        $NewLines += '    [System.Windows.Forms.MessageBox]::Show("BROWSE BUTTON HANDLER FIRED!", "Test", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)'
        Write-Host "    Added MessageBox at line $($i+2)" -ForegroundColor Green
    }
}

# Save
Write-Host "`n[4] Saving modified file..." -ForegroundColor Yellow
$NewLines | Set-Content $GUIPath -Encoding UTF8
Write-Host "    File saved" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MessageBox Test Added!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Now test your GUI:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Close current GUI if open" -ForegroundColor White
Write-Host "2. Launch: .\PatchManagement-GUI.ps1" -ForegroundColor Cyan
Write-Host "3. Go to Deploy tab" -ForegroundColor White
Write-Host "4. Click 'Refresh Updates' button" -ForegroundColor White
Write-Host ""
Write-Host "Expected results:" -ForegroundColor Yellow
Write-Host "  - Popup appears: 'REFRESH BUTTON HANDLER FIRED!'" -ForegroundColor Green
Write-Host "    → Handler IS working, problem is in function code" -ForegroundColor White
Write-Host ""
Write-Host "  - No popup appears" -ForegroundColor Red
Write-Host "    → Handler NOT firing, need different fix" -ForegroundColor White
Write-Host ""
Write-Host "Backup: $Backup`n" -ForegroundColor Gray
