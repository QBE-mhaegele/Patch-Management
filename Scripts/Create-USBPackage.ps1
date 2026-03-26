# Create-USBPackage.ps1
# Package updates for USB deployment to field machines

param(
    [Parameter(Mandatory=$true)]
    [string[]]$UpdatePaths,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\PatchManagement\USBPackages",
    
    [Parameter(Mandatory=$false)]
    [string]$PackageName = $null
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Create USB Deployment Package" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create package name if not provided
if ([string]::IsNullOrEmpty($PackageName)) {
    $PackageName = "UpdatePackage-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

$PackagePath = Join-Path $OutputPath $PackageName

Write-Host "Package: $PackageName" -ForegroundColor White
Write-Host "Output:  $PackagePath`n" -ForegroundColor White

# Create package folder
if (-not (Test-Path $PackagePath)) {
    New-Item -Path $PackagePath -ItemType Directory -Force | Out-Null
    Write-Host "Created package folder" -ForegroundColor Green
}

Write-Host ""

# Copy update files
Write-Host "Copying update files..." -ForegroundColor Yellow

$TotalSize = 0
$CopiedFiles = @()

foreach ($UpdatePath in $UpdatePaths) {
    if (-not (Test-Path $UpdatePath)) {
        Write-Host "  ✗ Not found: $UpdatePath" -ForegroundColor Red
        continue
    }
    
    $UpdateFile = Get-Item $UpdatePath
    $DestPath = Join-Path $PackagePath $UpdateFile.Name
    
    Copy-Item -Path $UpdatePath -Destination $DestPath -Force
    
    $SizeMB = [math]::Round($UpdateFile.Length / 1MB, 2)
    $TotalSize += $SizeMB
    
    Write-Host "  ✓ $($UpdateFile.Name) ($SizeMB MB)" -ForegroundColor Green
    
    $CopiedFiles += $UpdateFile.Name
}

Write-Host ""

if ($CopiedFiles.Count -eq 0) {
    Write-Host "ERROR: No files copied to package`n" -ForegroundColor Red
    exit 1
}

# Create installation batch file
Write-Host "Creating INSTALL.bat..." -ForegroundColor Yellow

$InstallBat = @"
@echo off
echo ========================================
echo Windows Update USB Installation
echo ========================================
echo.
echo Package: $PackageName
echo Files: $($CopiedFiles.Count) update(s)
echo.
echo ========================================
echo.

"@

foreach ($File in $CopiedFiles) {
    $InstallBat += @"
echo Installing: $File
wusa.exe "$File" /quiet /norestart
if errorlevel 3010 (
    echo   SUCCESS - Reboot required
) else if errorlevel 2359302 (
    echo   Already installed
) else if errorlevel 1 (
    echo   FAILED - Check Windows Update log
) else (
    echo   SUCCESS
)
echo.

"@
}

$InstallBat += @"
echo ========================================
echo Installation Complete
echo ========================================
echo.
echo Please reboot this computer to complete installation.
echo.
pause
"@

$InstallBatPath = Join-Path $PackagePath "INSTALL.bat"
$InstallBat | Out-File -FilePath $InstallBatPath -Encoding ASCII

Write-Host "  Created: INSTALL.bat" -ForegroundColor Green
Write-Host ""

# Create README
Write-Host "Creating README.txt..." -ForegroundColor Yellow

$ReadMe = @"
USB Update Package
==================
Package: $PackageName
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Files: $($CopiedFiles.Count) update(s)
Total Size: $TotalSize MB

Contents:
---------
"@

foreach ($File in $CopiedFiles) {
    $ReadMe += "`n- $File"
}

$ReadMe += @"


Installation Instructions:
==========================

1. Copy this entire folder to the target computer
   (or run directly from USB drive)

2. Right-click INSTALL.bat and select "Run as administrator"

3. Wait for all updates to install
   (may take 5-20 minutes depending on update size)

4. Reboot the computer when prompted

Exit Codes:
-----------
0     = Success
3010  = Success, reboot required
2359302 = Already installed
Other = Error (check Windows Update log)

Troubleshooting:
----------------
If installation fails:
- Ensure you're running as administrator
- Check Windows Update service is running
- Verify correct OS version
- Check disk space

Support:
--------
QB Energy IT Infrastructure
Patch Management System
"@

$ReadMePath = Join-Path $PackagePath "README.txt"
$ReadMe | Out-File -FilePath $ReadMePath -Encoding UTF8

Write-Host "  Created: README.txt" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Package Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Package Details:" -ForegroundColor White
Write-Host "  Name:   $PackageName" -ForegroundColor Gray
Write-Host "  Files:  $($CopiedFiles.Count) update(s)" -ForegroundColor Gray
Write-Host "  Size:   $TotalSize MB" -ForegroundColor Gray
Write-Host "  Location: $PackagePath" -ForegroundColor Gray
Write-Host ""

Write-Host "Package Contents:" -ForegroundColor White
foreach ($File in $CopiedFiles) {
    Write-Host "  - $File" -ForegroundColor Gray
}
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Copy folder to USB drive" -ForegroundColor Gray
Write-Host "  2. Take USB to field machine" -ForegroundColor Gray
Write-Host "  3. Run INSTALL.bat as administrator" -ForegroundColor Gray
Write-Host "  4. Reboot when complete" -ForegroundColor Gray
Write-Host ""

Write-Host "Opening package folder..." -ForegroundColor Gray
Start-Process "explorer.exe" -ArgumentList $PackagePath

Write-Host ""
Write-Host "Package ready for USB deployment!`n" -ForegroundColor Green

return [PSCustomObject]@{
    PackageName = $PackageName
    PackagePath = $PackagePath
    FileCount = $CopiedFiles.Count
    TotalSizeMB = $TotalSize
    Files = $CopiedFiles
}
