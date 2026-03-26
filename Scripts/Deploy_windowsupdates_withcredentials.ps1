# Deploy-WindowsUpdates-WithCredentials.ps1
# Enhanced version with proper credential handling for remote installation

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoReboot = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceReboot = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 60,
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Windows Updates (With Credentials)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target:      $ComputerName" -ForegroundColor White

$RebootText = if ($AutoReboot) { "YES" } else { "NO" }
Write-Host "Auto-Reboot: $RebootText" -ForegroundColor White
Write-Host "Timeout:     $TimeoutMinutes minutes" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get credentials if not provided
if (-not $Credential) {
    Write-Host "Remote Windows Update installation requires admin credentials`n" -ForegroundColor Yellow
    $Credential = Get-Credential -Message "Enter admin credentials for $ComputerName"
    
    if (-not $Credential) {
        Write-Host "Error: Credentials required for remote installation" -ForegroundColor Red
        return @{ Success = $false; Error = "No credentials provided" }
    }
}

# Test connectivity
Write-Host "[1/6] Testing connectivity..." -ForegroundColor Yellow
$PingResult = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet
if (-not $PingResult) {
    Write-Host "Error: Cannot reach $ComputerName" -ForegroundColor Red
    return @{ Success = $false; Error = "Cannot reach target machine" }
}
Write-Host "Success: Connection successful" -ForegroundColor Green
Write-Host ""

# Test WinRM
Write-Host "[2/6] Testing WinRM..." -ForegroundColor Yellow
try {
    $WinRMTest = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "Success: WinRM accessible" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Error: WinRM not accessible - $_" -ForegroundColor Red
    return @{ Success = $false; Error = "WinRM not accessible on target" }
}

# Check for updates
Write-Host "[3/6] Checking for available updates..." -ForegroundColor Yellow

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

$AvailableUpdates = Invoke-Command -ComputerName $ComputerName -ScriptBlock $CheckScript -Credential $Credential

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

Write-Host ""

if ($AvailableUpdates.Downloaded.Count -eq 0) {
    Write-Host "⚠ No downloaded updates found" -ForegroundColor Yellow
    return @{ Success = $false; Error = "No updates ready to install" }
}

# Create scheduled task on remote machine to install updates
Write-Host "[4/6] Creating scheduled task on remote machine..." -ForegroundColor Yellow
Write-Host "  (This allows installation with proper privileges)" -ForegroundColor Gray

$TaskScript = {
    param($UseAutoReboot, $UseForceReboot)
    
    # Create script content for scheduled task
    $InstallScript = @'
$Results = @{
    Success = $false
    InstalledCount = 0
    FailedCount = 0
    RebootRequired = $false
    Details = @()
    Error = $null
}

$LogFile = "C:\Windows\Temp\WindowsUpdate_Install.log"

try {
    "Starting Windows Update installation: $(Get-Date)" | Out-File $LogFile
    
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    
    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 AND IsDownloaded=1")
    
    "Found $($SearchResult.Updates.Count) updates to install" | Out-File $LogFile -Append
    
    if ($SearchResult.Updates.Count -eq 0) {
        $Results.Error = "No updates to install"
        $Results | ConvertTo-Json | Out-File "C:\Windows\Temp\WindowsUpdate_Result.json"
        exit 0
    }
    
    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($Update in $SearchResult.Updates) {
        $UpdatesToInstall.Add($Update) | Out-Null
    }
    
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    
    "Installing $($UpdatesToInstall.Count) update(s)..." | Out-File $LogFile -Append
    
    $InstallationResult = $Installer.Install()
    
    for ($i = 0; $i -lt $UpdatesToInstall.Count; $i++) {
        $Update = $UpdatesToInstall.Item($i)
        $Result = $InstallationResult.GetUpdateResult($i)
        
        $KB = "Unknown"
        if ($Update.Title -match "KB(\d+)") { $KB = "KB$($Matches[1])" }
        
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
            "$KB installed successfully" | Out-File $LogFile -Append
            
            if ($Result.RebootRequired) {
                $Results.RebootRequired = $true
            }
        } else {
            $Results.FailedCount++
            "$KB failed with code: $($Result.ResultCode)" | Out-File $LogFile -Append
        }
    }
    
    $Results.Success = ($Results.InstalledCount -gt 0)
    
    "Installation complete: $($Results.InstalledCount) installed, $($Results.FailedCount) failed" | Out-File $LogFile -Append
    
    # Handle reboot
    if ($Results.RebootRequired) {
        "Reboot required" | Out-File $LogFile -Append
        
        if ('%FORCEREBOOT%' -eq 'True') {
            "Force rebooting in 60 seconds" | Out-File $LogFile -Append
            shutdown /r /t 60 /c "Windows Updates installed - reboot required" /f
        } elseif ('%AUTOREBOOT%' -eq 'True') {
            "Auto-reboot scheduled in 5 minutes" | Out-File $LogFile -Append
            shutdown /r /t 300 /c "Windows Updates - auto-reboot in 5 minutes"
        }
    }
    
} catch {
    $Results.Error = $_.Exception.Message
    "Error: $($Results.Error)" | Out-File $LogFile -Append
}

$Results | ConvertTo-Json | Out-File "C:\Windows\Temp\WindowsUpdate_Result.json"
"Complete: $(Get-Date)" | Out-File $LogFile -Append
'@

    # Replace placeholders
    $InstallScript = $InstallScript -replace '%AUTOREBOOT%', $UseAutoReboot.ToString()
    $InstallScript = $InstallScript -replace '%FORCEREBOOT%', $UseForceReboot.ToString()
    
    # Save script
    $InstallScript | Out-File "C:\Windows\Temp\InstallUpdates.ps1" -Force
    
    # Create scheduled task
    $TaskName = "WindowsUpdate_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Windows\Temp\InstallUpdates.ps1"
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    $Task = New-ScheduledTask -Action $Action -Principal $Principal -Settings $Settings
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task | Out-Null
    
    # Run task immediately
    Start-ScheduledTask -TaskName $TaskName
    
    # Return task name for monitoring
    return $TaskName
}

$TaskName = Invoke-Command -ComputerName $ComputerName -ScriptBlock $TaskScript -ArgumentList $AutoReboot, $ForceReboot -Credential $Credential

Write-Host "Success: Scheduled task created: $TaskName" -ForegroundColor Green
Write-Host ""

# Monitor installation progress
Write-Host "[5/6] Monitoring installation (this may take several minutes)..." -ForegroundColor Yellow

$MonitorScript = {
    param($TaskName)
    
    $MaxWait = 1800  # 30 minutes
    $Elapsed = 0
    
    while ($Elapsed -lt $MaxWait) {
        # Check if result file exists
        if (Test-Path "C:\Windows\Temp\WindowsUpdate_Result.json") {
            Start-Sleep -Seconds 2  # Wait a bit more to ensure file is complete
            $Result = Get-Content "C:\Windows\Temp\WindowsUpdate_Result.json" | ConvertFrom-Json
            return $Result
        }
        
        # Check task status
        $Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($Task -and $Task.State -eq 'Ready') {
            # Task finished but no result file yet, wait a bit
            Start-Sleep -Seconds 5
            if (Test-Path "C:\Windows\Temp\WindowsUpdate_Result.json") {
                $Result = Get-Content "C:\Windows\Temp\WindowsUpdate_Result.json" | ConvertFrom-Json
                return $Result
            }
        }
        
        Start-Sleep -Seconds 10
        $Elapsed += 10
        
        if ($Elapsed % 30 -eq 0) {
            Write-Host "  Still installing... ($Elapsed seconds elapsed)" -ForegroundColor Gray
        }
    }
    
    return @{ Success = $false; Error = "Installation timeout (30 minutes)" }
}

$InstallResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock $MonitorScript -ArgumentList $TaskName -Credential $Credential

# Display results
Write-Host ""
Write-Host "[6/6] Installation Results:" -ForegroundColor Yellow
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

# Cleanup
Write-Host "Cleaning up scheduled task..." -ForegroundColor Gray
Invoke-Command -ComputerName $ComputerName -ScriptBlock {
    param($TaskName)
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
} -ArgumentList $TaskName -Credential $Credential

return @{
    Success = $InstallResult.Success
    ComputerName = $ComputerName
    InstalledCount = $InstallResult.InstalledCount
    FailedCount = $InstallResult.FailedCount
    RebootRequired = $InstallResult.RebootRequired
    Details = $InstallResult.Details
    Error = $InstallResult.Error
}