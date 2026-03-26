# Cleanup-OneOffFixes.ps1
# Removes all the temporary fix scripts that accumulated

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cleanup One-Off Fix Files" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$ScriptsPath = "C:\PatchManagement\Scripts"

# List of one-off fix files to remove
$FilesToRemove = @(
    "Add-Scan-At-Startup-Fixed.ps1",
    "Add-Scan-At-Startup.ps1",
    "Auto-Deploy-Fixed-GUI.ps1",
    "Check-Button-Objects.ps1",
    "Complete-Deploy-Tab-Replacement.ps1",
    "Enhanced-Deploy-Tab.ps1",
    "Enhanced-FileBasedUpdates-EventHandlers.ps1",
    "Enhanced-FileBasedUpdates-UI.ps1",
    "File-Based-Update-Integration.ps1",
    "Fix-Scan-Location.ps1",
    "Fixed-Handlers-Replacement.ps1",
    "Minimal-Test-GUI.ps1",
    "Quick-Button-Check.ps1",
    "Restore-GUI-From-Backup.ps1",
    "Test-FileBasedUpdates.ps1",
    "Ultra-Simple-Fix.ps1",
    "Verify-GUI-Structure.ps1"
)

Write-Host "Checking for files to remove..." -ForegroundColor Yellow
Write-Host ""

$Removed = 0
$NotFound = 0

foreach ($File in $FilesToRemove) {
    $FullPath = Join-Path $ScriptsPath $File
    
    if (Test-Path $FullPath) {
        try {
            Remove-Item $FullPath -Force
            Write-Host "  Removed: $File" -ForegroundColor Green
            $Removed++
        } catch {
            Write-Host "  Failed to remove: $File - $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Not found: $File (already removed)" -ForegroundColor Gray
        $NotFound++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Files removed: $Removed" -ForegroundColor Green
Write-Host "  Already gone: $NotFound" -ForegroundColor Gray
Write-Host "  Total checked: $($FilesToRemove.Count)" -ForegroundColor White
Write-Host ""

Write-Host "Your Scripts folder is now clean!" -ForegroundColor Green
Write-Host "Only the actual patch management scripts remain.`n" -ForegroundColor White
