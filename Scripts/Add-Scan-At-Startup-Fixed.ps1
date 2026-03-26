# Add-Scan-At-Startup-Fixed.ps1
# Fixed version with proper string escaping

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Add Scan at Startup (FIXED)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$GUIPath = "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"

# Backup
Write-Host "[1] Creating backup..." -ForegroundColor Yellow
$BackupPath = "$GUIPath.BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $GUIPath -Destination $BackupPath
Write-Host "    Saved: $BackupPath" -ForegroundColor Green

# Read file as lines
Write-Host "`n[2] Reading GUI file..." -ForegroundColor Yellow
$Lines = Get-Content $GUIPath

# Find Form.ShowDialog() line
Write-Host "`n[3] Finding Form.ShowDialog()..." -ForegroundColor Yellow
$ShowDialogLine = -1

for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '\$Form\.ShowDialog\(\)') {
        $ShowDialogLine = $i
        Write-Host "    Found at line $($i+1)" -ForegroundColor Green
        break
    }
}

if ($ShowDialogLine -eq -1) {
    Write-Host "    ERROR: Could not find Form.ShowDialog()" -ForegroundColor Red
    exit 1
}

# Create the scan code to insert (build it line by line to avoid escaping issues)
$ScanCodeLines = @(
    "",
    "# ============================================================",
    "# AUTO-SCAN REPOSITORY AT STARTUP",
    "# ============================================================",
    'Write-Host "" ',
    'Write-Host "[STARTUP] Scanning repository for updates..." -ForegroundColor Cyan',
    "",
    'if (Test-Path $RepoPathTextBox.Text) {',
    "    try {",
    '        Load-RepositoryUpdates -RepositoryPath $RepoPathTextBox.Text -OSFilter "All" -Silent $false',
    '        Write-Host "[STARTUP] Repository scan complete" -ForegroundColor Green',
    "    } catch {",
    '        Write-Host "[STARTUP] Error scanning repository: $_" -ForegroundColor Red',
    "    }",
    "} else {",
    '    Write-Host "[STARTUP] Repository not accessible: $($RepoPathTextBox.Text)" -ForegroundColor Yellow',
    '    Write-Host "[STARTUP] Skipping auto-scan" -ForegroundColor Gray',
    "}",
    "",
    'Write-Host "" ',
    ""
)

# Insert the scan code before ShowDialog
Write-Host "`n[4] Inserting auto-scan code..." -ForegroundColor Yellow
$NewLines = @()
$NewLines += $Lines[0..($ShowDialogLine-1)]
$NewLines += $ScanCodeLines
$NewLines += $Lines[$ShowDialogLine..($Lines.Count-1)]

Write-Host "    Inserted $($ScanCodeLines.Count) lines before ShowDialog" -ForegroundColor Green

# Save
Write-Host "`n[5] Saving modified file..." -ForegroundColor Yellow
$NewLines | Set-Content $GUIPath -Encoding UTF8
Write-Host "    File saved" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Auto-Scan at Startup Added!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "What changed:" -ForegroundColor Yellow
Write-Host "  • GUI scans repository ONCE at startup" -ForegroundColor Green
Write-Host "  • Updates ready when you open Deploy tab" -ForegroundColor Green
Write-Host "  • No button clicking needed!" -ForegroundColor Green
Write-Host ""

Write-Host "How to test:" -ForegroundColor Yellow
Write-Host "  1. Launch GUI: .\PatchManagement-GUI.ps1" -ForegroundColor White
Write-Host "  2. Watch console for:" -ForegroundColor White
Write-Host "     [STARTUP] Scanning repository..." -ForegroundColor Cyan
Write-Host "     [STARTUP] Repository scan complete" -ForegroundColor Cyan
Write-Host "  3. Go to Deploy tab" -ForegroundColor White
Write-Host "  4. Updates should be there!" -ForegroundColor Green
Write-Host ""

Write-Host "Backup: $BackupPath`n" -ForegroundColor Gray
