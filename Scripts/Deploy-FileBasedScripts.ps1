# Deploy-FileBasedScripts.ps1
# Master deployment script - Installs all file-based update management scripts
# Run this once to add file-based deployment to your Patch Management system

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$false)]
    [string]$PatchManagementPath = "C:\PatchManagement",
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = $PSScriptRoot,
    
    [Parameter(Mandatory=$false)]
    [switch]$UpdateGUI = $true
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deploy File-Based Update Scripts" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Patch Management: $PatchManagementPath" -ForegroundColor White
Write-Host "Source Files: $SourcePath`n" -ForegroundColor White

# Verify Patch Management installation
if (-not (Test-Path $PatchManagementPath)) {
    Write-Host "ERROR: Patch Management not found at $PatchManagementPath" -ForegroundColor Red
    Write-Host "Please specify correct path with -PatchManagementPath parameter`n" -ForegroundColor Yellow
    exit 1
}

$ScriptsPath = Join-Path $PatchManagementPath "Scripts"
if (-not (Test-Path $ScriptsPath)) {
    Write-Host "ERROR: Scripts folder not found: $ScriptsPath" -ForegroundColor Red
    exit 1
}

Write-Host "Found Patch Management installation" -ForegroundColor Green
Write-Host ""

# Create required folders
Write-Host "[1/6] Creating required folders..." -ForegroundColor Yellow

$Folders = @(
    (Join-Path $PatchManagementPath "Logs"),
    (Join-Path $PatchManagementPath "USBPackages"),
    (Join-Path $PatchManagementPath "Backup")
)

foreach ($Folder in $Folders) {
    if (-not (Test-Path $Folder)) {
        New-Item -Path $Folder -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $Folder" -ForegroundColor Green
    } else {
        Write-Host "  Exists: $Folder" -ForegroundColor Gray
    }
}

Write-Host ""

# Backup existing files
Write-Host "[2/6] Backing up existing files..." -ForegroundColor Yellow

$BackupDate = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupPath = Join-Path $PatchManagementPath "Backup\Pre-FileBased-$BackupDate"

if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
}

$FilesToBackup = @(
    "PatchManagement-GUI.ps1",
    "Deploy-WindowsUpdates.ps1",
    "PatchConfig.psm1"
)

foreach ($File in $FilesToBackup) {
    $SourceFile = Join-Path $ScriptsPath $File
    if (Test-Path $SourceFile) {
        Copy-Item -Path $SourceFile -Destination $BackupPath -Force
        Write-Host "  Backed up: $File" -ForegroundColor Green
    }
}

Write-Host "  Backup location: $BackupPath" -ForegroundColor Gray
Write-Host ""

# Copy new scripts
Write-Host "[3/6] Copying new scripts..." -ForegroundColor Yellow

$NewScripts = @{
    "Deploy-FileBasedUpdate.ps1" = "Deploy single update via WUSA"
    "Deploy-UpdateBatch.ps1" = "Deploy to multiple computers"
    "Get-AvailableUpdates.ps1" = "List updates in repository"
    "Create-USBPackage.ps1" = "Create USB deployment packages"
    "Test-ComputerConnectivity.ps1" = "Test computer connectivity"
    "Get-InstalledUpdates.ps1" = "Check installed updates"
}

$CopiedCount = 0

foreach ($Script in $NewScripts.Keys) {
    $SourceFile = Join-Path $SourcePath $Script
    $DestFile = Join-Path $ScriptsPath $Script
    
    if (Test-Path $SourceFile) {
        Copy-Item -Path $SourceFile -Destination $DestFile -Force
        Write-Host "  Copied: $Script" -ForegroundColor Green
        Write-Host "    $($NewScripts[$Script])" -ForegroundColor Gray
        $CopiedCount++
    } else {
        Write-Host "  Missing: $Script" -ForegroundColor Yellow
        Write-Host "    $($NewScripts[$Script])" -ForegroundColor Gray
    }
}

Write-Host "  $CopiedCount script(s) copied" -ForegroundColor Green
Write-Host ""

# Update PatchConfig.psm1
Write-Host "[4/6] Updating configuration..." -ForegroundColor Yellow

$ConfigPath = Join-Path $ScriptsPath "PatchConfig.psm1"

if (Test-Path $ConfigPath) {
    $ConfigContent = Get-Content $ConfigPath -Raw
    
    # Check if repository path already exists
    if ($ConfigContent -notmatch 'RepositoryPath') {
        # Add repository configuration
        $NewConfig = @"

# File-Based Update Repository
`$Config.RepositoryPath = "\\QBE-DEN-WINUP1\UpdateFiles"
`$Config.USBPackagePath = "C:\PatchManagement\USBPackages"

"@
        $ConfigContent += $NewConfig
        $ConfigContent | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
        Write-Host "  Updated PatchConfig.psm1 with repository paths" -ForegroundColor Green
    } else {
        Write-Host "  Repository paths already configured" -ForegroundColor Gray
    }
} else {
    Write-Host "  WARNING: PatchConfig.psm1 not found" -ForegroundColor Yellow
    Write-Host "  Creating basic configuration..." -ForegroundColor White
    
    $BasicConfig = @'
# PatchConfig.psm1
# Patch Management Configuration

function Get-PatchConfig {
    $Config = @{
        BaseDirectory = "C:\PatchManagement"
        InventoryShare = "\\qbe-den-qnap\File4\Inventory"
        RepositoryPath = "\\QBE-DEN-WINUP1\UpdateFiles"
        USBPackagePath = "C:\PatchManagement\USBPackages"
        LogPath = "C:\PatchManagement\Logs"
        OUs = @(
            "OU=Test OU for GPO Testing,OU=Denver,OU=Workstations,OU=QBE,DC=qb-energy,DC=com"
        )
    }
    
    return [PSCustomObject]$Config
}

Export-ModuleMember -Function Get-PatchConfig
'@
    
    $BasicConfig | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
    Write-Host "  Created basic PatchConfig.psm1" -ForegroundColor Green
}

Write-Host ""

# Update GUI (if requested)
if ($UpdateGUI) {
    Write-Host "[5/6] Updating GUI..." -ForegroundColor Yellow
    
    $GUIPath = Join-Path $ScriptsPath "PatchManagement-GUI.ps1"
    
    if (-not (Test-Path $GUIPath)) {
        Write-Host "  ERROR: GUI not found at $GUIPath" -ForegroundColor Red
    } else {
        Write-Host "  GUI file found" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  IMPORTANT: Manual GUI Update Required" -ForegroundColor Yellow
        Write-Host "  ─────────────────────────────────────" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To integrate file-based updates into GUI:" -ForegroundColor White
        Write-Host ""
        Write-Host "  1. Open: $GUIPath" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Find the Deploy tab section (search for '# TAB: Deploy')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  3. Replace entire Deploy tab with contents from:" -ForegroundColor Gray
        Write-Host "     Enhanced-Deploy-Tab.ps1" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  4. Save and test the GUI" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  The Enhanced-Deploy-Tab.ps1 file contains the complete" -ForegroundColor White
        Write-Host "  updated Deploy tab with file-based deployment support." -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Host "[5/6] Skipping GUI update (-UpdateGUI = false)" -ForegroundColor Gray
}

Write-Host ""

# Create helper scripts
Write-Host "[6/6] Creating helper scripts..." -ForegroundColor Yellow

# Script to test installation
$TestScript = @'
# Test-FileBasedInstallation.ps1
# Verify file-based update scripts are installed correctly

Write-Host "`nTesting File-Based Update Installation...`n" -ForegroundColor Cyan

$RequiredScripts = @(
    "Deploy-FileBasedUpdate.ps1",
    "Deploy-UpdateBatch.ps1",
    "Get-AvailableUpdates.ps1",
    "Create-USBPackage.ps1",
    "Test-ComputerConnectivity.ps1",
    "Get-InstalledUpdates.ps1",
    "PatchConfig.psm1"
)

$AllPresent = $true

foreach ($Script in $RequiredScripts) {
    $Path = Join-Path $PSScriptRoot $Script
    if (Test-Path $Path) {
        Write-Host "✓ $Script" -ForegroundColor Green
    } else {
        Write-Host "✗ $Script - MISSING" -ForegroundColor Red
        $AllPresent = $false
    }
}

Write-Host ""

if ($AllPresent) {
    Write-Host "All required scripts present!`n" -ForegroundColor Green
    
    # Test repository access
    Import-Module .\PatchConfig.psm1 -Force
    $Config = Get-PatchConfig
    
    Write-Host "Testing repository access..." -ForegroundColor Yellow
    if (Test-Path $Config.RepositoryPath) {
        Write-Host "✓ Repository accessible: $($Config.RepositoryPath)" -ForegroundColor Green
    } else {
        Write-Host "✗ Repository not accessible: $($Config.RepositoryPath)" -ForegroundColor Yellow
        Write-Host "  Setup repository on WINUP1 first`n" -ForegroundColor Gray
    }
} else {
    Write-Host "Some scripts missing - run Deploy-FileBasedScripts.ps1`n" -ForegroundColor Red
}
'@

$TestScriptPath = Join-Path $ScriptsPath "Test-FileBasedInstallation.ps1"
$TestScript | Out-File -FilePath $TestScriptPath -Encoding UTF8 -Force
Write-Host "  Created: Test-FileBasedInstallation.ps1" -ForegroundColor Green

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Scripts Deployed:" -ForegroundColor White
Write-Host "  ✓ Deploy-FileBasedUpdate.ps1" -ForegroundColor Gray
Write-Host "  ✓ Deploy-UpdateBatch.ps1" -ForegroundColor Gray
Write-Host "  ✓ Get-AvailableUpdates.ps1" -ForegroundColor Gray
Write-Host "  ✓ Create-USBPackage.ps1" -ForegroundColor Gray
Write-Host "  ✓ Test-ComputerConnectivity.ps1" -ForegroundColor Gray
Write-Host "  ✓ Get-InstalledUpdates.ps1" -ForegroundColor Gray
Write-Host "  ✓ PatchConfig.psm1 (updated)" -ForegroundColor Gray
Write-Host ""

Write-Host "Folders Created:" -ForegroundColor White
Write-Host "  ✓ C:\PatchManagement\Logs\" -ForegroundColor Gray
Write-Host "  ✓ C:\PatchManagement\USBPackages\" -ForegroundColor Gray
Write-Host ""

Write-Host "Backup Location:" -ForegroundColor White
Write-Host "  $BackupPath" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Update GUI with Enhanced Deploy Tab:" -ForegroundColor Yellow
Write-Host "   - Open: $GUIPath" -ForegroundColor Gray
Write-Host "   - Replace Deploy tab section with Enhanced-Deploy-Tab.ps1 contents" -ForegroundColor Gray
Write-Host "   - Save file" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Setup Repository on WINUP1:" -ForegroundColor Yellow
Write-Host "   - Run: Setup-FileBasedRepository.ps1 on QBE-DEN-WINUP1" -ForegroundColor Gray
Write-Host "   - Creates D:\UpdateFiles\ and network share" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Download First Updates:" -ForegroundColor Yellow
Write-Host "   - Visit: https://www.catalog.update.microsoft.com" -ForegroundColor Gray
Write-Host "   - Download .msu files to repository" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Test Installation:" -ForegroundColor Yellow
Write-Host "   cd $ScriptsPath" -ForegroundColor Gray
Write-Host "   .\Test-FileBasedInstallation.ps1" -ForegroundColor Cyan
Write-Host ""

Write-Host "5. Launch GUI:" -ForegroundColor Yellow
Write-Host "   .\PatchManagement-GUI.ps1" -ForegroundColor Cyan
Write-Host "   - Go to Deploy tab" -ForegroundColor Gray
Write-Host "   - Click 'Refresh Updates'" -ForegroundColor Gray
Write-Host "   - Test deployment to QBE-DEN-TSGW1" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Run these commands to verify:" -ForegroundColor White
Write-Host "  cd $ScriptsPath" -ForegroundColor Cyan
Write-Host "  .\Test-FileBasedInstallation.ps1`n" -ForegroundColor Cyan

Write-Host "========================================`n" -ForegroundColor Cyan

# Offer to run test
$RunTest = Read-Host "Run installation test now? (Y/N)"
if ($RunTest -eq "Y" -or $RunTest -eq "y") {
    Write-Host ""
    & "$ScriptsPath\Test-FileBasedInstallation.ps1"
}
