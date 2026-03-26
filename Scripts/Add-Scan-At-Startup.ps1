# Add-Scan-At-Startup.ps1
# Simplest solution: Scan once when GUI launches, before showing form

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Add Scan at Startup" -ForegroundColor Cyan
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

# Find $Form.ShowDialog() and add scan right before it
Write-Host "`n[3] Finding Form.ShowDialog()..." -ForegroundColor Yellow

if ($Content -match '\$Form\.ShowDialog\(\)') {
    Write-Host "    Found Form.ShowDialog()" -ForegroundColor Green
    
    # Add the scan code right before ShowDialog
    $ScanCode = @'

# ============================================================
# AUTO-SCAN REPOSITORY AT STARTUP
# ============================================================
Write-Host "`n[STARTUP] Scanning repository for updates..." -ForegroundColor Cyan

if (Test-Path $RepoPathTextBox.Text) {
    try {
        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter "All" -Silent $false
        Write-Host "[STARTUP] Repository scan complete" -ForegroundColor Green
    } catch {
        Write-Host "[STARTUP] Error scanning repository: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[STARTUP] Repository not accessible: $($RepoPathTextBox.Text)" -ForegroundColor Yellow
    Write-Host "[STARTUP] Skipping auto-scan" -ForegroundColor Gray
}

Write-Host ""

'@

    # Insert before ShowDialog
    $Content = $Content -replace '(\$Form\.ShowDialog\(\))', "$ScanCode`$1"
    
    Write-Host "    Added auto-scan before ShowDialog" -ForegroundColor Green
} else {
    Write-Host "    ERROR: Could not find Form.ShowDialog()" -ForegroundColor Red
    exit 1
}

# Save
Write-Host "`n[4] Saving modified file..." -ForegroundColor Yellow
$Content | Out-File -FilePath $GUIPath -Encoding UTF8 -Force
Write-Host "    File saved" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Auto-Scan at Startup Added!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "What changed:" -ForegroundColor Yellow
Write-Host "  • GUI scans repository ONCE at startup" -ForegroundColor Green
Write-Host "  • Updates ready when you open Deploy tab" -ForegroundColor Green
Write-Host "  • No button clicking needed!" -ForegroundColor Green
Write-Host "  • Works even if buttons are broken" -ForegroundColor Green
Write-Host ""

Write-Host "How it works:" -ForegroundColor Yellow
Write-Host "  1. Launch GUI: .\PatchManagement-GUI.ps1" -ForegroundColor White
Write-Host "  2. Console shows: [STARTUP] Scanning repository..." -ForegroundColor Cyan
Write-Host "  3. Updates load automatically" -ForegroundColor White
Write-Host "  4. Go to Deploy tab → Updates already there!" -ForegroundColor Green
Write-Host ""

Write-Host "To see new files after adding to repository:" -ForegroundColor Yellow
Write-Host "  • Close and re-launch GUI" -ForegroundColor White
Write-Host "  • Updates will load fresh each time" -ForegroundColor White
Write-Host ""

Write-Host "Benefits:" -ForegroundColor Yellow
Write-Host "  ✓ Simple - scans once at launch" -ForegroundColor Green
Write-Host "  ✓ Reliable - no button dependencies" -ForegroundColor Green
Write-Host "  ✓ Fast - happens while GUI loads" -ForegroundColor Green
Write-Host "  ✓ Visible - see [STARTUP] messages in console" -ForegroundColor Green
Write-Host ""

Write-Host "Backup: $BackupPath`n" -ForegroundColor Gray
