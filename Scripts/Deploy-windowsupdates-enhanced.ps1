# Deploy-WindowsUpdates-Enhanced.ps1
# Enhanced version that handles "Pending install" updates better

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoReboot = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceReboot = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 60
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Windows Updates (Enhanced)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target:      $ComputerName" -ForegroundColor White

$RebootText = if ($AutoReboot) { "YES" } else { "NO" }
Write-Host "Auto-Reboot: $RebootText" -ForegroundColor White
Write-Host "Timeout:     $TimeoutMinutes minutes" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test connectivity
Write-Host "[1/5] Testing connectivity..." -ForegroundColor Yellow
$PingResult = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet
if (-not $PingResult) {
    Write-Host "Error: Cannot reach $ComputerName" -ForegroundColor Red
    return @{ Success = $false; Error = "Cannot reach target machine" }
}
Write-Host "Success: Connection successful" -ForegroundColor Green
Write-Host ""

# Test WinRM
Write-Host "[2/5] Testing WinRM..." -ForegroundColor Yellow
try {
    $WinRMTest = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "Success: WinRM accessible" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Error: WinRM not accessible - $_" -ForegroundColor Red
    return @{ Success = $false; Error = "WinRM not accessible on target" }
}

# Check for updates with multiple search criteria
Write-Host "[3/5] Checking for available updates..." -ForegroundColor Yellow

$CheckScript = {
    $UpdateResults = @{
        Downloaded = @()
        NotDownloaded = @()
        AllAvailable = @()
        TotalCount = 0
    }
    
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        # Search for ALL non-installed updates (broader search)
        Write-Host "  Searching for all available updates..." -ForegroundColor Gray
        $AllUpdates = $UpdateSearcher.Search("IsInstalled=0")
        
        $UpdateResults.TotalCount = $AllUpdates.Updates.Count
        
        foreach ($Update in $AllUpdates.Updates) {
            $KB = "Unknown"
            if ($Update.Title -match "KB(\d+)") {
                $KB = "KB$($Matches[1])"
            }
            
            $UpdateInfo = [PSCustomObject]@{
                Title = $Update.Title
                KB = $KB
                SizeMB = [math]::Round($Update.MaxDownloadSize / 1MB, 2)
                IsDownloaded = $Update.IsDownloaded
                IsHidden = $Update.IsHidden
                IsMandatory = $Update.IsMandatory
            }
            
            $UpdateResults.AllAvailable += $UpdateInfo
            
            # Categorize by download status
            if ($Update.IsDownloaded) {
                $UpdateResults.Downloaded += $UpdateInfo
            } else {
                $UpdateResults.NotDownloaded += $UpdateInfo
            }
        }
        
    } catch {
        return @{ Error = $_.Exception.Message }
    }
    
    return $UpdateResults
}

$AvailableUpdates = Invoke-Command -ComputerName $ComputerName -ScriptBlock $CheckScript

if ($AvailableUpdates.Error) {
    Write-Host "Error: Failed to check updates - $($AvailableUpdates.Error)" -ForegroundColor Red
    return @{ Success = $false; Error = $AvailableUpdates.Error }
}

Write-Host "Success: Found $($AvailableUpdates.TotalCount) total update(s)" -ForegroundColor Green

if ($AvailableUpdates.Downloaded.Count -gt 0) {
    Write-Host "  Downloaded (Ready): $($AvailableUpdates.Downloaded.Count)" -ForegroundColor Green
    foreach ($Update in $AvailableUpdates.Downloaded) {
        Write-Host "    • $($Update.KB) - $($Update.Title)" -ForegroundColor White
        Write-Host "      Size: $($Update.SizeMB) MB" -ForegroundColor Gray
    }
}

if ($AvailableUpdates.NotDownloaded.Count -gt 0) {
    Write-Host "  Not Downloaded: $($AvailableUpdates.NotDownloaded.Count)" -ForegroundColor Yellow
    foreach ($Update in $AvailableUpdates.NotDownloaded) {
        Write-Host "    • $($Update.KB) - $($Update.Title)" -ForegroundColor Yellow
        Write-Host "      Size: $($Update.SizeMB) MB (needs download)" -ForegroundColor Gray
    }
}

Write-Host ""

# Check if we have any updates to install
if ($AvailableUpdates.Downloaded.Count -eq 0) {
    if ($AvailableUpdates.NotDownloaded.Count -gt 0) {
        Write-Host "⚠ Updates are available but NOT downloaded yet" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor White
        Write-Host "  1. Wait for automatic download to complete" -ForegroundColor Gray
        Write-Host "  2. Manually download in Windows Update GUI" -ForegroundColor Gray
        Write-Host "  3. Use 'Download and Install' option (if available)" -ForegroundColor Gray
        Write-Host ""
        
        # Offer to download
        $DownloadFirst = Read-Host "Attempt to download updates now? (Y/N)"
        if ($DownloadFirst -eq 'Y' -or $DownloadFirst -eq 'y') {
            Write-Host ""
            Write-Host "[3b/5] Downloading updates first..." -ForegroundColor Yellow
            
            $DownloadScript = {
                try {
                    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
                    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
                    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 AND IsDownloaded=0")
                    
                    if ($SearchResult.Updates.Count -eq 0) {
                        return @{ Success = $false; Error = "No updates to download" }
                    }
                    
                    # Create collection
                    $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
                    foreach ($Update in $SearchResult.Updates) {
                        $UpdatesToDownload.Add($Update) | Out-Null
                    }
                    
                    # Download
                    $Downloader = $UpdateSession.CreateUpdateDownloader()
                    $Downloader.Updates = $UpdatesToDownload
                    
                    Write-Host "  Downloading $($UpdatesToDownload.Count) update(s)..."
                    $DownloadResult = $Downloader.Download()
                    
                    return @{ 
                        Success = ($DownloadResult.ResultCode -eq 2)
                        Count = $UpdatesToDownload.Count
                    }
                } catch {
                    return @{ Success = $false; Error = $_.Exception.Message }
                }
            }
            
            $DownloadResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock $DownloadScript
            
            if ($DownloadResult.Success) {
                Write-Host "Success: Downloaded $($DownloadResult.Count) update(s)" -ForegroundColor Green
                Write-Host "  Now proceeding to installation..." -ForegroundColor White
                Write-Host ""
            } else {
                Write-Host "Error: Download failed - $($DownloadResult.Error)" -ForegroundColor Red
                return @{ Success = $false; Error = "Download failed" }
            }
        } else {
            Write-Host "Deployment cancelled. Download updates first." -ForegroundColor Yellow
            return @{ Success = $false; Error = "Updates not downloaded" }
        }
    } else {
        Write-Host "ℹ No updates available to install" -ForegroundColor Blue
        return @{ Success = $true; Message = "No updates needed" }
    }
}

# Install updates
Write-Host "[4/5] Installing updates on $ComputerName..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray
Write-Host ""

$InstallScript = {
    param($UseAutoReboot, $UseForceReboot)
    
    $Results = @{
        Success = $false
        InstalledCount = 0
        FailedCount = 0
        RebootRequired = $false
        Details = @()
        Error = $null
    }
    
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        
        # Search for updates to install
        # Try downloaded first, then all available
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0")
        
        if ($SearchResult.Updates.Count -eq 0) {
            $Results.Error = "No updates found to install"
            return $Results
        }
        
        # Create collection - prioritize downloaded updates
        $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        $DownloadedCount = 0
        
        foreach ($Update in $SearchResult.Updates) {
            if ($Update.IsDownloaded) {
                $UpdatesToInstall.Add($Update) | Out-Null
                $DownloadedCount++
            }
        }
        
        if ($UpdatesToInstall.Count -eq 0) {
            $Results.Error = "No downloaded updates available"
            return $Results
        }
        
        Write-Host "  Installing $($UpdatesToInstall.Count) update(s)..."
        
        # Install
        $Installer = $UpdateSession.CreateUpdateInstaller()
        $Installer.Updates = $UpdatesToInstall
        $InstallationResult = $Installer.Install()
        
        # Process results
        for ($i = 0; $i -lt $UpdatesToInstall.Count; $i++) {
            $Update = $UpdatesToInstall.Item($i)
            $Result = $InstallationResult.GetUpdateResult($i)
            
            $KB = "Unknown"
            if ($Update.Title -match "KB(\d+)") {
                $KB = "KB$($Matches[1])"
            }
            
            $UpdateResult = [PSCustomObject]@{
                KB = $KB
                Title = $Update.Title
                ResultCode = $Result.ResultCode
                Success = ($Result.ResultCode -eq 2)
                RebootRequired = $Result.RebootRequired
            }
            
            $Results.Details += $UpdateResult
            
            if ($UpdateResult.Success) {
                $Results.InstalledCount++
                Write-Host "  [OK] $KB - Installed" -ForegroundColor Green
                
                if ($Result.RebootRequired) {
                    $Results.RebootRequired = $true
                }
            } else {
                $Results.FailedCount++
                Write-Host "  [FAIL] $KB - Failed (Code: $($Result.ResultCode))" -ForegroundColor Red
            }
        }
        
        $Results.Success = ($Results.InstalledCount -gt 0)
        
        # Handle reboot
        if ($Results.RebootRequired) {
            Write-Host ""
            Write-Host "  ⚠ Reboot required to complete installation" -ForegroundColor Yellow
            
            if ($UseForceReboot) {
                Write-Host "  Force reboot in 60 seconds..." -ForegroundColor Yellow
                shutdown /r /t 60 /c "Windows Updates installed - reboot required" /f
            } elseif ($UseAutoReboot) {
                Write-Host "  Auto-reboot in 5 minutes..." -ForegroundColor Yellow
                shutdown /r /t 300 /c "Windows Updates - auto-reboot in 5 minutes"
            } else {
                Write-Host "  Manual reboot required" -ForegroundColor Yellow
            }
        }
        
    } catch {
        $Results.Error = $_.Exception.Message
        Write-Host "  Error: $($Results.Error)" -ForegroundColor Red
    }
    
    return $Results
}

try {
    $InstallResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock $InstallScript -ArgumentList $AutoReboot, $ForceReboot -ErrorAction Stop
    
    # Display results
    Write-Host ""
    Write-Host "[5/5] Installation Results:" -ForegroundColor Yellow
    Write-Host "  Installed:       $($InstallResult.InstalledCount)" -ForegroundColor Green
    
    if ($InstallResult.FailedCount -gt 0) {
        Write-Host "  Failed:          $($InstallResult.FailedCount)" -ForegroundColor Red
    }
    
    $RebootText2 = if ($InstallResult.RebootRequired) { "YES" } else { "NO" }
    $RebootColor = if ($InstallResult.RebootRequired) { "Yellow" } else { "Green" }
    Write-Host "  Reboot Required: $RebootText2" -ForegroundColor $RebootColor
    
    if ($InstallResult.Details.Count -gt 0) {
        Write-Host ""
        Write-Host "Detailed Results:" -ForegroundColor White
        foreach ($Detail in $InstallResult.Details) {
            $Icon = if ($Detail.Success) { "[OK]" } else { "[FAIL]" }
            $Color = if ($Detail.Success) { "Green" } else { "Red" }
            Write-Host "  $Icon $($Detail.KB)" -ForegroundColor $Color
            
            if ($Detail.RebootRequired) {
                Write-Host "      Reboot required" -ForegroundColor Yellow
            }
        }
    }
    
    if ($InstallResult.Error) {
        Write-Host ""
        Write-Host "Error: $($InstallResult.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($InstallResult.Success) {
        Write-Host "Success: Deployment completed!" -ForegroundColor Green
    } else {
        Write-Host "Warning: Deployment completed with errors" -ForegroundColor Yellow
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    return @{
        Success = $InstallResult.Success
        ComputerName = $ComputerName
        InstalledCount = $InstallResult.InstalledCount
        FailedCount = $InstallResult.FailedCount
        RebootRequired = $InstallResult.RebootRequired
        Details = $InstallResult.Details
        Error = $InstallResult.Error
    }
    
} catch {
    Write-Host ""
    Write-Host "Error: Deployment failed - $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    return @{
        Success = $false
        Error = $_.Exception.Message
    }
}