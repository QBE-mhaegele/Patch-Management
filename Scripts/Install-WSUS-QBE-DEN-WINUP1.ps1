# Install-WSUS-QBE-DEN-WINUP1.ps1
# Complete WSUS installation and initial configuration for QBE-DEN-WINUP1

#Requires -RunAsAdministrator

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "WSUS Installation - QBE-DEN-WINUP1" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Configuration
$WSUSContentPath = "D:\WSUS"
$ServerName = $env:COMPUTERNAME

Write-Host "Server: $ServerName" -ForegroundColor White
Write-Host "Content Path: $WSUSContentPath`n" -ForegroundColor White

# Step 1: Verify D:\ drive exists
Write-Host "[1/8] Verifying storage..." -ForegroundColor Yellow

if (-not (Test-Path "D:\")) {
    Write-Host "  ERROR: D:\ drive not found!" -ForegroundColor Red
    Write-Host "  Please verify storage is mounted`n" -ForegroundColor Yellow
    exit 1
}

$Drive = Get-PSDrive D
$FreeGB = [math]::Round($Drive.Free / 1GB, 2)
$TotalGB = [math]::Round(($Drive.Used + $Drive.Free) / 1GB, 2)

Write-Host "  Drive D:\ found" -ForegroundColor Green
Write-Host "  Total: $TotalGB GB" -ForegroundColor Gray
Write-Host "  Free:  $FreeGB GB" -ForegroundColor Gray

if ($FreeGB -lt 100) {
    Write-Host "  WARNING: Less than 100 GB free space!" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Create WSUS content directory
Write-Host "[2/8] Creating WSUS content directory..." -ForegroundColor Yellow

if (-not (Test-Path $WSUSContentPath)) {
    try {
        New-Item -Path $WSUSContentPath -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $WSUSContentPath" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to create directory - $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  Already exists: $WSUSContentPath" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Install WSUS role
Write-Host "[3/8] Installing WSUS Windows Feature..." -ForegroundColor Yellow
Write-Host "  This may take 5-10 minutes..." -ForegroundColor Gray

$WSUSFeature = Get-WindowsFeature -Name UpdateServices

if ($WSUSFeature.Installed) {
    Write-Host "  WSUS already installed" -ForegroundColor Gray
} else {
    try {
        Install-WindowsFeature -Name UpdateServices -IncludeManagementTools | Out-Null
        Write-Host "  WSUS role installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to install WSUS - $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 4: Install WSUS Services (WID database)
Write-Host "[4/8] Installing WSUS Services with WID..." -ForegroundColor Yellow
Write-Host "  This may take 10-15 minutes..." -ForegroundColor Gray

# Check if already configured
$WSUSServer = $null
try {
    $WSUSServer = Get-WsusServer -ErrorAction SilentlyContinue
} catch {
    # Not configured yet
}

if ($WSUSServer) {
    Write-Host "  WSUS already configured" -ForegroundColor Gray
    Write-Host "  Server: $($WSUSServer.Name)" -ForegroundColor Gray
    Write-Host "  Port: $($WSUSServer.PortNumber)" -ForegroundColor Gray
} else {
    Write-Host "  Running WSUS post-installation..." -ForegroundColor White
    
    $PostInstallLog = "C:\Windows\Temp\WSUS_PostInstall.log"
    
    # Run post-install configuration
    $PostInstallCmd = "C:\Program Files\Update Services\Tools\wsusutil.exe"
    $PostInstallArgs = "postinstall", "CONTENT_DIR=$WSUSContentPath"
    
    try {
        & $PostInstallCmd $PostInstallArgs 2>&1 | Tee-Object -FilePath $PostInstallLog
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  WSUS post-installation completed" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Post-install returned code $LASTEXITCODE" -ForegroundColor Yellow
            Write-Host "  Check log: $PostInstallLog" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ERROR: Post-installation failed - $_" -ForegroundColor Red
        Write-Host "  Check log: $PostInstallLog" -ForegroundColor Gray
        exit 1
    }
}

Write-Host ""

# Step 5: Verify WSUS server is accessible
Write-Host "[5/8] Verifying WSUS server..." -ForegroundColor Yellow

Start-Sleep -Seconds 5  # Give WSUS services time to start

try {
    $WSUSServer = Get-WsusServer -ErrorAction Stop
    Write-Host "  WSUS Server: $($WSUSServer.Name)" -ForegroundColor Green
    Write-Host "  Port: $($WSUSServer.PortNumber)" -ForegroundColor Gray
    Write-Host "  Content Path: $($WSUSServer.GetConfiguration().LocalContentCachePath)" -ForegroundColor Gray
} catch {
    Write-Host "  ERROR: Cannot connect to WSUS server - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Configure WSUS settings
Write-Host "[6/8] Configuring WSUS settings..." -ForegroundColor Yellow

try {
    $WSUSConfig = $WSUSServer.GetConfiguration()
    
    # Set update source to Microsoft Update
    Write-Host "  Setting update source to Microsoft Update..." -ForegroundColor White
    $WSUSConfig.SyncFromMicrosoftUpdate = $true
    
    # Configure update languages (English only)
    Write-Host "  Configuring update languages (English only)..." -ForegroundColor White
    $WSUSConfig.AllUpdateLanguagesEnabled = $false
    $WSUSConfig.SetEnabledUpdateLanguages("en")
    
    # Save configuration
    $WSUSConfig.Save()
    Write-Host "  Configuration saved" -ForegroundColor Green
    
} catch {
    Write-Host "  ERROR: Failed to configure WSUS - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Configure products and classifications
Write-Host "[7/8] Configuring products and classifications..." -ForegroundColor Yellow
Write-Host "  This sets what updates WSUS will download" -ForegroundColor Gray

try {
    $WSUSSubscription = $WSUSServer.GetSubscription()
    
    # Get all products
    Write-Host "  Loading product catalog..." -ForegroundColor White
    $AllProducts = Get-WsusProduct
    
    # Products to enable
    $ProductsToEnable = @(
        "Windows 10",
        "Windows 11",
        "Windows Server 2019",
        "Windows Server 2022"
    )
    
    Write-Host "  Configuring products:" -ForegroundColor White
    foreach ($ProductName in $ProductsToEnable) {
        $Product = $AllProducts | Where-Object { $_.Product.Title -like "*$ProductName*" }
        if ($Product) {
            $Product | Set-WsusProduct
            Write-Host "    Enabled: $ProductName" -ForegroundColor Green
        } else {
            Write-Host "    Not found: $ProductName" -ForegroundColor Yellow
        }
    }
    
    # Classifications to enable
    Write-Host "  Configuring classifications:" -ForegroundColor White
    $ClassificationsToEnable = @(
        "Critical Updates",
        "Definition Updates",
        "Security Updates",
        "Update Rollups",
        "Updates"
    )
    
    $AllClassifications = Get-WsusClassification
    
    foreach ($ClassName in $ClassificationsToEnable) {
        $Classification = $AllClassifications | Where-Object { $_.Classification.Title -eq $ClassName }
        if ($Classification) {
            $Classification | Set-WsusClassification
            Write-Host "    Enabled: $ClassName" -ForegroundColor Green
        } else {
            Write-Host "    Not found: $ClassName" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "  ERROR: Failed to configure products/classifications - $_" -ForegroundColor Red
    Write-Host "  You can configure these later in WSUS console" -ForegroundColor Yellow
}

Write-Host ""

# Step 8: Configure synchronization schedule
Write-Host "[8/8] Configuring synchronization schedule..." -ForegroundColor Yellow

try {
    $WSUSSubscription = $WSUSServer.GetSubscription()
    
    # Set synchronization schedule (daily at 2 AM)
    Write-Host "  Setting schedule: Daily at 2:00 AM" -ForegroundColor White
    $WSUSSubscription.SynchronizeAutomatically = $true
    $WSUSSubscription.SynchronizeAutomaticallyTimeOfDay = (New-TimeSpan -Hours 2)
    $WSUSSubscription.NumberOfSynchronizationsPerDay = 1
    
    $WSUSSubscription.Save()
    Write-Host "  Synchronization schedule configured" -ForegroundColor Green
    
} catch {
    Write-Host "  ERROR: Failed to configure sync schedule - $_" -ForegroundColor Red
    Write-Host "  You can configure this later in WSUS console" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "WSUS Server Details:" -ForegroundColor White
Write-Host "  Server Name: $ServerName" -ForegroundColor Gray
Write-Host "  Server URL: http://${ServerName}:8530" -ForegroundColor Gray
Write-Host "  Content Path: $WSUSContentPath" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Perform initial synchronization" -ForegroundColor Gray
Write-Host "     Run: .\Sync-WSUS-Initial.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Configure automatic approval rules" -ForegroundColor Gray
Write-Host "     Run WSUS console or use script" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Configure client Group Policy" -ForegroundColor Gray
Write-Host "     Point clients to http://${ServerName}:8530" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4. Integrate with Patch Management GUI" -ForegroundColor Gray
Write-Host "     Run: .\Integrate-WSUS-PatchManagement.ps1" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Log" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Save installation details to log
$InstallLog = "C:\PatchManagement\Logs\WSUS_Installation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$LogDir = Split-Path $InstallLog -Parent

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$LogContent = @"
WSUS Installation Log
=====================
Server: $ServerName
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Content Path: $WSUSContentPath
WSUS Port: 8530
Installation Status: Complete

Products Configured:
$(($ProductsToEnable | ForEach-Object { "  - $_" }) -join "`n")

Classifications Configured:
$(($ClassificationsToEnable | ForEach-Object { "  - $_" }) -join "`n")

Sync Schedule: Daily at 2:00 AM
"@

$LogContent | Out-File -FilePath $InstallLog -Encoding UTF8

Write-Host "Log saved to: $InstallLog`n" -ForegroundColor Gray

Write-Host "To open WSUS console: updateservices.msc`n" -ForegroundColor Yellow
