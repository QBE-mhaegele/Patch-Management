# Fix-Scan-Location.ps1
# Moves the scan code to the correct location (after function definition)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Fix Auto-Scan Location" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$GUIPath = "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"

# Backup
Write-Host "[1] Creating backup..." -ForegroundColor Yellow
$BackupPath = "$GUIPath.BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $GUIPath -Destination $BackupPath
Write-Host "    Saved: $BackupPath" -ForegroundColor Green

# Read file
Write-Host "`n[2] Reading GUI file..." -ForegroundColor Yellow
$Lines = Get-Content $GUIPath

# Find and REMOVE the existing (broken) startup scan code
Write-Host "`n[3] Removing broken startup scan..." -ForegroundColor Yellow
$NewLines = @()
$InStartupBlock = $false
$RemovedLines = 0

for ($i = 0; $i -lt $Lines.Count; $i++) {
    $Line = $Lines[$i]
    
    # Start of startup block
    if ($Line -match '# AUTO-SCAN REPOSITORY AT STARTUP') {
        $InStartupBlock = $true
        $RemovedLines++
        continue
    }
    
    # End of startup block (empty line after the block)
    if ($InStartupBlock -and $Line -match '^\s*$' -and $Lines[$i-1] -match '^\s*$') {
        $InStartupBlock = $false
        continue
    }
    
    # Skip lines in the block
    if ($InStartupBlock) {
        $RemovedLines++
        continue
    }
    
    $NewLines += $Line
}

Write-Host "    Removed $RemovedLines lines of broken code" -ForegroundColor Green

# Find where Form.ShowDialog is
Write-Host "`n[4] Finding Form.ShowDialog()..." -ForegroundColor Yellow
$ShowDialogLine = -1

for ($i = 0; $i -lt $NewLines.Count; $i++) {
    if ($NewLines[$i] -match '\$Form\.ShowDialog\(\)') {
        $ShowDialogLine = $i
        Write-Host "    Found at line $($i+1)" -ForegroundColor Green
        break
    }
}

if ($ShowDialogLine -eq -1) {
    Write-Host "    ERROR: Could not find Form.ShowDialog()" -ForegroundColor Red
    exit 1
}

# Insert scan code RIGHT before ShowDialog (which is after function definitions)
Write-Host "`n[5] Adding auto-scan in correct location..." -ForegroundColor Yellow

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
    '        Write-Host "[STARTUP] Error: $_" -ForegroundColor Red',
    "    }",
    "} else {",
    '    $RepoPath = $RepoPathTextBox.Text',
    '    Write-Host "[STARTUP] Repository not accessible: $RepoPath" -ForegroundColor Yellow',
    "}",
    "",
    'Write-Host "" ',
    ""
)

# Build final file
$FinalLines = @()
$FinalLines += $NewLines[0..($ShowDialogLine-1)]
$FinalLines += $ScanCodeLines
$FinalLines += $NewLines[$ShowDialogLine..($NewLines.Count-1)]

Write-Host "    Added auto-scan at line $ShowDialogLine (before ShowDialog)" -ForegroundColor Green

# Save
Write-Host "`n[6] Saving fixed file..." -ForegroundColor Yellow
$FinalLines | Set-Content $GUIPath -Encoding UTF8
Write-Host "    File saved" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Auto-Scan Fixed!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "What changed:" -ForegroundColor Yellow
Write-Host "  • Removed broken scan code from wrong location" -ForegroundColor Green
Write-Host "  • Added scan code AFTER function definitions" -ForegroundColor Green
Write-Host "  • Now Load-RepositoryUpdates will be defined when called" -ForegroundColor Green
Write-Host ""

Write-Host "Test it now:" -ForegroundColor Yellow
Write-Host "  .\PatchManagement-GUI.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "You should see:" -ForegroundColor Yellow
Write-Host "  [STARTUP] Scanning repository..." -ForegroundColor Cyan
Write-Host "  [STARTUP] Repository scan complete" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then go to Deploy tab - updates should be there!" -ForegroundColor Green
Write-Host ""

Write-Host "Backup: $BackupPath`n" -ForegroundColor Gray
