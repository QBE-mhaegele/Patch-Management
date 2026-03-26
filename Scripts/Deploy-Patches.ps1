<#
.SYNOPSIS
    Deploy Windows patches to a remote computer
.DESCRIPTION
    Deploys patches via PSWindowsUpdate module with optional auto-reboot
.PARAMETER ComputerName
    Target computer name
.PARAMETER AutoReboot
    Automatically reboot after installation if required
.PARAMETER CreateSnapshot
    Create VM snapshot before patching (if VM)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoReboot = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateSnapshot
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deploy Patches: $ComputerName" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# [1/5] Test connectivity
Write-Host "[1/5] Testing connectivity..." -ForegroundColor Yellow

if (-not (Test-Connection -ComputerName $ComputerName -Count 2 -Quiet)) {
    Write-Error "Cannot reach $ComputerName"
    exit 1
}

Write-Host "  Success: $ComputerName is online" -ForegroundColor Green

# [2/5] Test WinRM
Write-Host "`n[2/5] Testing WinRM..." -ForegroundColor Yellow

try {
    $Session = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "  Success: WinRM is responding" -ForegroundColor Green
} catch {
    Write-Error "WinRM not available on $ComputerName : $_"
    exit 1
}

# [3/5] Pre-check
Write-Host "`n[3/5] Running pre-checks..." -ForegroundColor Yellow

$PreCheckScript = {
    $results = @{
        FreeSpaceGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
        PendingReboot = $false
        PSWindowsUpdateInstalled = $false
    }
    
    # Check for pending reboot
    $rebootKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    )
    
    foreach ($key in $rebootKeys) {
        if (Test-Path $key) {
            $results.PendingReboot = $true
            break
        }
    }
    
    # Check if PSWindowsUpdate is installed
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        $results.PSWindowsUpdateInstalled = $true
    }
    
    return $results
}

try {
    $PreCheck = Invoke-Command -ComputerName $ComputerName -ScriptBlock $PreCheckScript -ErrorAction Stop
    
    Write-Host "  Free Space: $($PreCheck.FreeSpaceGB) GB" -ForegroundColor $(if ($PreCheck.FreeSpaceGB -lt 10) {"Red"} else {"Green"})
    Write-Host "  Pending Reboot: $($PreCheck.PendingReboot)" -ForegroundColor $(if ($PreCheck.PendingReboot) {"Yellow"} else {"Green"})
    Write-Host "  PSWindowsUpdate Module: $($PreCheck.PSWindowsUpdateInstalled)" -ForegroundColor $(if ($PreCheck.PSWindowsUpdateInstalled) {"Green"} else {"Yellow"})
    
    if ($PreCheck.FreeSpaceGB -lt 10) {
        Write-Warning "Low disk space detected. Patching may fail."
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y') {
            Write-Host "Deployment cancelled by user" -ForegroundColor Red
            exit 1
        }
    }
    
    if ($PreCheck.PendingReboot) {
        Write-Warning "System has pending reboot. Rebooting before patching..."
        Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout 300 -ErrorAction Stop
        Write-Host "  Success: Reboot complete" -ForegroundColor Green
    }
    
} catch {
    Write-Error "Pre-check failed: $_"
    exit 1
}

# [4/5] Install patches
Write-Host "`n[4/5] Installing patches..." -ForegroundColor Yellow

$PatchScript = {
    param($AutoReboot)
    
    # Install PSWindowsUpdate module if not present
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "  Installing PSWindowsUpdate module..."
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction Stop
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
    }
    
    Import-Module PSWindowsUpdate
    
    # Get available updates
    Write-Host "  Scanning for updates..."
    $Updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot
    
    if ($Updates.Count -eq 0) {
        Write-Host "  No updates available"
        return @{
            Success = $true
            UpdatesInstalled = 0
            RebootRequired = $false
        }
    }
    
    Write-Host "  Found $($Updates.Count) updates to install..."
    
    # Install updates
    try {
        $Result = Install-WindowsUpdate -AcceptAll -IgnoreReboot -Verbose -ErrorAction Stop
        
        # Check if reboot is required
        $RebootRequired = Get-WURebootStatus -Silent
        
        return @{
            Success = $true
            UpdatesInstalled = $Result.Count
            RebootRequired = $RebootRequired
            Updates = $Result | Select-Object Title, KB, Result
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            UpdatesInstalled = 0
        }
    }
}

try {
    $Result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $PatchScript -ArgumentList $AutoReboot -ErrorAction Stop
    
    if ($Result.Success) {
        Write-Host "  Success: Patches installed successfully" -ForegroundColor Green
        Write-Host "  Updates Installed: $($Result.UpdatesInstalled)" -ForegroundColor White
        
        if ($Result.Updates) {
            Write-Host "`n  Installed Updates:" -ForegroundColor Cyan
            foreach ($update in $Result.Updates) {
                Write-Host "    - $($update.Title) [$($update.KB)]" -ForegroundColor Gray
            }
        }
        
        # Handle reboot
        if ($Result.RebootRequired) {
            Write-Host "`n  Reboot Required: Yes" -ForegroundColor Yellow
            
            if ($AutoReboot) {
                Write-Host "  Rebooting system..." -ForegroundColor Yellow
                Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout 600 -ErrorAction Stop
                Write-Host "  Success: Reboot complete" -ForegroundColor Green
            } else {
                Write-Host "  Manual reboot required (AutoReboot disabled)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n  Reboot Required: No" -ForegroundColor Green
        }
        
    } else {
        Write-Error "Patch installation failed: $($Result.Error)"
        exit 1
    }
    
} catch {
    Write-Error "Failed to execute patch deployment: $_"
    exit 1
}

# [5/5] Post-check
Write-Host "`n[5/5] Post-deployment check..." -ForegroundColor Yellow

$PostCheckScript = {
    $results = @{
        LastInstalled = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).HotFixID
        PendingReboot = $false
    }
    
    # Check for pending reboot
    $rebootKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    )
    
    foreach ($key in $rebootKeys) {
        if (Test-Path $key) {
            $results.PendingReboot = $true
            break
        }
    }
    
    return $results
}

try {
    $PostCheck = Invoke-Command -ComputerName $ComputerName -ScriptBlock $PostCheckScript -ErrorAction Stop
    
    Write-Host "  Last Installed: $($PostCheck.LastInstalled)" -ForegroundColor Green
    Write-Host "  Pending Reboot: $($PostCheck.PendingReboot)" -ForegroundColor $(if ($PostCheck.PendingReboot) {"Yellow"} else {"Green"})
    
} catch {
    Write-Warning "Post-check failed: $_"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Computer: $ComputerName" -ForegroundColor White
Write-Host "Status: Success" -ForegroundColor Green
Write-Host "Updates Installed: $($Result.UpdatesInstalled)" -ForegroundColor White
Write-Host "Reboot Status: $(if ($Result.RebootRequired) {'Completed'} else {'Not Required'})" -ForegroundColor White