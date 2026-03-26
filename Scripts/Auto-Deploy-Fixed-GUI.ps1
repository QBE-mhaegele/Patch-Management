# Auto-Deploy-Fixed-GUI.ps1
# Automatically finds and deploys the fixed GUI file

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Auto-Deploy Fixed GUI" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Paths to check
$DownloadPaths = @(
    "C:\Users\$env:USERNAME\Downloads\PatchManagement-GUI.ps1",
    "$env:USERPROFILE\Downloads\PatchManagement-GUI.ps1",
    "C:\PatchManagement\PatchManagement-GUI.ps1",
    ".\PatchManagement-GUI.ps1"
)

$DestPath = "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"

# Find the source file
$SourceFile = $null
foreach ($Path in $DownloadPaths) {
    if (Test-Path $Path) {
        $SourceFile = $Path
        Write-Host "✓ Found source file: $Path" -ForegroundColor Green
        break
    }
}

if (-not $SourceFile) {
    Write-Host "✗ Could not find PatchManagement-GUI.ps1" -ForegroundColor Red
    Write-Host "`nSearched in:" -ForegroundColor Yellow
    foreach ($Path in $DownloadPaths) {
        Write-Host "  - $Path" -ForegroundColor Gray
    }
    Write-Host "`nPlease download the fixed file first.`n" -ForegroundColor Yellow
    exit 1
}

# Check if destination exists
if (-not (Test-Path $DestPath)) {
    Write-Host "⚠ Destination doesn't exist: $DestPath" -ForegroundColor Yellow
    Write-Host "Creating directory...`n" -ForegroundColor Yellow
    New-Item -Path (Split-Path $DestPath) -ItemType Directory -Force | Out-Null
}

# Backup existing file
if (Test-Path $DestPath) {
    $BackupPath = "$DestPath.BACKUP_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "Backing up current version..." -ForegroundColor Yellow
    Copy-Item $DestPath -Destination $BackupPath -Force
    Write-Host "✓ Backup created: $BackupPath`n" -ForegroundColor Green
}

# Copy new file
Write-Host "Deploying fixed version..." -ForegroundColor Yellow
try {
    Copy-Item $SourceFile -Destination $DestPath -Force -ErrorAction Stop
    Write-Host "✓ File deployed successfully!`n" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to copy file: $_`n" -ForegroundColor Red
    exit 1
}

# Verify the fix
Write-Host "Verifying fix..." -ForegroundColor Yellow

$HasOldCode = Select-String -Path $DestPath -Pattern '\$Timer\.Stop' -Quiet
$HasNewCode = Select-String -Path $DestPath -Pattern '\$this\.Stop' -Quiet

if ($HasOldCode) {
    Write-Host "✗ WARNING: Old code still present!" -ForegroundColor Red
    Write-Host "  Source file may not be the fixed version" -ForegroundColor Yellow
    Write-Host "`nPlease download the latest PatchManagement-GUI.ps1`n" -ForegroundColor Yellow
    exit 1
} elseif ($HasNewCode) {
    Write-Host "✓ Fixed code verified!`n" -ForegroundColor Green
    
    # Show file info
    $File = Get-Item $DestPath
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Deployment Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "File:     $($File.Name)" -ForegroundColor White
    Write-Host "Location: $($File.DirectoryName)" -ForegroundColor White
    Write-Host "Size:     $([math]::Round($File.Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "Modified: $($File.LastWriteTime)" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    Write-Host "✓ Ready to launch!" -ForegroundColor Green
    Write-Host "Run: .\Launch-PatchManagementGUI-Hidden.ps1`n" -ForegroundColor Yellow
    
    # Offer to launch
    $Launch = Read-Host "Launch GUI now? (Y/N)"
    if ($Launch -eq 'Y' -or $Launch -eq 'y') {
        Write-Host "`nLaunching GUI...`n" -ForegroundColor Cyan
        
        $LauncherPath = "C:\PatchManagement\Scripts\Launch-PatchManagementGUI-Hidden.ps1"
        if (Test-Path $LauncherPath) {
            & $LauncherPath
        } else {
            # Launch directly
            & $DestPath
        }
    }
    
} else {
    Write-Host "⚠ Could not verify fix - manual check recommended`n" -ForegroundColor Yellow
}
