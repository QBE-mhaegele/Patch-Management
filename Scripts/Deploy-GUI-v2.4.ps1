# Deploy-GUI-v2.4.ps1
# Deploy PSExec-integrated GUI

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deploy Patch Management GUI v2.4" -ForegroundColor Cyan
Write-Host "PSExec Integration Update" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$InstallPath = "C:\PatchManagement\Scripts"
$DownloadPath = "C:\Users\$env:USERNAME\Downloads"
$GUIFile = "PatchManagement-GUI.ps1"

# Check install path
if (-not (Test-Path $InstallPath)) {
    Write-Host "✗ Install path not found: $InstallPath" -ForegroundColor Red
    Write-Host "  Please create C:\PatchManagement\Scripts first`n" -ForegroundColor Yellow
    exit 1
}

# Check for source file
$SourceFile = Join-Path $DownloadPath $GUIFile
if (-not (Test-Path $SourceFile)) {
    Write-Host "✗ Source file not found: $SourceFile" -ForegroundColor Red
    Write-Host "  Please download $GUIFile first`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found source file" -ForegroundColor Green
Write-Host "  Location: $SourceFile`n" -ForegroundColor Gray

# Backup existing
$DestFile = Join-Path $InstallPath $GUIFile
if (Test-Path $DestFile) {
    $BackupDate = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupFile = "$DestFile.BACKUP_v2.4_$BackupDate"
    
    Write-Host "Backing up current version..." -ForegroundColor Yellow
    try {
        Copy-Item $DestFile -Destination $BackupFile -Force
        Write-Host "✓ Backup created" -ForegroundColor Green
        Write-Host "  Location: $BackupFile`n" -ForegroundColor Gray
    } catch {
        Write-Host "⚠ Backup failed: $_" -ForegroundColor Yellow
        Write-Host "  Continuing anyway...`n" -ForegroundColor Gray
    }
}

# Deploy new version
Write-Host "Deploying GUI v2.4..." -ForegroundColor Yellow
try {
    Copy-Item $SourceFile -Destination $DestFile -Force
    Write-Host "✓ Deployment successful!`n" -ForegroundColor Green
} catch {
    Write-Host "✗ Deployment failed: $_`n" -ForegroundColor Red
    exit 1
}

# Verify
$DeployedFile = Get-Item $DestFile
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Deployed File:" -ForegroundColor White
Write-Host "  Name:     $($DeployedFile.Name)" -ForegroundColor Gray
Write-Host "  Location: $($DeployedFile.DirectoryName)" -ForegroundColor Gray
Write-Host "  Size:     $([math]::Round($DeployedFile.Length / 1KB, 2)) KB" -ForegroundColor Gray
Write-Host "  Modified: $($DeployedFile.LastWriteTime)`n" -ForegroundColor Gray

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "What's New in v2.4" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "✓ PSExec Integration" -ForegroundColor Green
Write-Host "  • Auto-downloads PSExec on first use" -ForegroundColor White
Write-Host "  • Runs installations as SYSTEM" -ForegroundColor White
Write-Host "  • No more Access Denied errors!`n" -ForegroundColor White

Write-Host "✓ Credential Prompt" -ForegroundColor Green
Write-Host "  • Clean GUI dialog" -ForegroundColor White
Write-Host "  • Secure password entry" -ForegroundColor White
Write-Host "  • Per-deployment credentials`n" -ForegroundColor White

Write-Host "✓ Enhanced Progress Tracking" -ForegroundColor Green
Write-Host "  • 6-step deployment process" -ForegroundColor White
Write-Host "  • Better elapsed time display" -ForegroundColor White
Write-Host "  • Extended timeout for large updates`n" -ForegroundColor White

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Launch GUI:" -ForegroundColor White
Write-Host "   .\Launch-PatchManagementGUI-Hidden.ps1`n" -ForegroundColor Gray

Write-Host "2. Go to Deployment tab`n" -ForegroundColor White

Write-Host "3. Test deployment:" -ForegroundColor White
Write-Host "   • Enter computer name" -ForegroundColor Gray
Write-Host "   • Click [Diagnose] (optional)" -ForegroundColor Gray
Write-Host "   • Click [Install Downloaded Updates]" -ForegroundColor Gray
Write-Host "   • Enter admin credentials when prompted" -ForegroundColor Gray
Write-Host "   • Watch it succeed!`n" -ForegroundColor Gray

Write-Host "4. First deployment will:" -ForegroundColor White
Write-Host "   • Auto-download PSExec" -ForegroundColor Gray
Write-Host "   • Save to C:\PatchManagement\Tools\" -ForegroundColor Gray
Write-Host "   • Reuse for future deployments`n" -ForegroundColor Gray

Write-Host "========================================`n" -ForegroundColor Cyan

# Offer to launch
$Launch = Read-Host "Launch GUI now? (Y/N)"
if ($Launch -eq 'Y' -or $Launch -eq 'y') {
    Write-Host "`nLaunching GUI...`n" -ForegroundColor Cyan
    
    $LauncherPath = Join-Path $InstallPath "Launch-PatchManagementGUI-Hidden.ps1"
    
    if (Test-Path $LauncherPath) {
        & $LauncherPath
    } elseif (Test-Path $DestFile) {
        & $DestFile
    } else {
        Write-Host "⚠ Please launch manually from:`n  $DestFile`n" -ForegroundColor Yellow
    }
} else {
    Write-Host "`nYou can launch the GUI anytime with:" -ForegroundColor White
    Write-Host "  .\Launch-PatchManagementGUI-Hidden.ps1`n" -ForegroundColor Gray
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete! Ready to Use!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
