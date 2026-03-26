<#
.SYNOPSIS
    Deploy MSU (Microsoft Update Standalone) packages to remote servers using WUSA
.DESCRIPTION
    Scans a specified directory for .msu files and deploys them to remote Windows servers
    using the Windows Update Standalone Installer (WUSA.exe)
.NOTES
    Author: QB Energy IT Infrastructure Team
    Version: 1.0
    Requires: Administrative privileges, WinRM access to target servers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$MSUPath = "D:\Updates",
    
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerNames,
    
    [Parameter(Mandatory=$false)]
    [string]$ComputerListFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoRestart,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quiet,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\PatchManagement\Logs"
)

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
        "INFO"    { Write-Host $LogMessage -ForegroundColor White }
        default   { Write-Host $LogMessage }
    }
    
    # File logging
    if ($Script:LogFile) {
        Add-Content -Path $Script:LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    }
}

function Get-MSUInfo {
    param([string]$MSUFile)
    
    $Info = @{
        FileName = Split-Path $MSUFile -Leaf
        FullPath = $MSUFile
        Size = (Get-Item $MSUFile).Length
        SizeFormatted = "{0:N2} MB" -f ((Get-Item $MSUFile).Length / 1MB)
        KBNumber = ""
        Description = ""
    }
    
    # Extract KB number from filename (common patterns)
    if ($Info.FileName -match 'KB(\d+)') {
        $Info.KBNumber = "KB$($Matches[1])"
    } elseif ($Info.FileName -match 'windows.*-(\d{7,})') {
        $Info.KBNumber = "KB$($Matches[1])"
    }
    
    return $Info
}

function Test-ServerConnectivity {
    param([string]$ComputerName)
    
    # Test basic connectivity
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        return @{ Success = $false; Error = "Ping failed - server unreachable" }
    }
    
    # Test WinRM
    try {
        $Result = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
        return @{ Success = $true; Error = $null }
    } catch {
        return @{ Success = $false; Error = "WinRM not available: $_" }
    }
}

function Copy-MSUToServer {
    param(
        [string]$MSUFile,
        [string]$ComputerName
    )
    
    $RemotePath = "\\$ComputerName\C$\Windows\Temp"
    $FileName = Split-Path $MSUFile -Leaf
    $Destination = Join-Path $RemotePath $FileName
    
    try {
        if (-not (Test-Path $RemotePath)) {
            throw "Cannot access $RemotePath"
        }
        
        Copy-Item -Path $MSUFile -Destination $Destination -Force -ErrorAction Stop
        return @{ Success = $true; RemotePath = "C:\Windows\Temp\$FileName"; Error = $null }
    } catch {
        return @{ Success = $false; RemotePath = $null; Error = $_.Exception.Message }
    }
}

function Install-MSUOnServer {
    param(
        [string]$ComputerName,
        [string]$RemoteMSUPath,
        [bool]$NoRestart,
        [bool]$Quiet,
        [int]$TimeoutMinutes
    )
    
    $WUSAArgs = @("/update `"$RemoteMSUPath`"")
    
    if ($NoRestart) {
        $WUSAArgs += "/norestart"
    }
    
    if ($Quiet) {
        $WUSAArgs += "/quiet"
    }
    
    $ScriptBlock = {
        param($MSUPath, $Arguments, $Timeout)
        
        $WUSAPath = "wusa.exe"
        $ArgString = $Arguments -join " "
        
        try {
            $Process = Start-Process -FilePath $WUSAPath -ArgumentList $ArgString -Wait -PassThru -NoNewWindow
            
            # WUSA exit codes
            $ExitCodeMeanings = @{
                0 = "Success"
                1 = "Success - Restart required"
                2 = "Success - Already installed"
                1058 = "Windows Update service not running"
                1603 = "Fatal error during installation"
                1618 = "Another installation is in progress"
                2359302 = "Update already installed"
                2359303 = "Update not applicable"
                3010 = "Success - Restart required"
                87 = "Invalid parameter"
            }
            
            $Meaning = if ($ExitCodeMeanings.ContainsKey($Process.ExitCode)) {
                $ExitCodeMeanings[$Process.ExitCode]
            } else {
                "Unknown exit code"
            }
            
            return @{
                ExitCode = $Process.ExitCode
                Meaning = $Meaning
                Success = $Process.ExitCode -in @(0, 1, 2, 2359302, 3010)
            }
        } catch {
            return @{
                ExitCode = -1
                Meaning = $_.Exception.Message
                Success = $false
            }
        }
    }
    
    try {
        $Result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock `
            -ArgumentList $RemoteMSUPath, $WUSAArgs, $TimeoutMinutes `
            -ErrorAction Stop
        
        return $Result
    } catch {
        return @{
            ExitCode = -1
            Meaning = "Remote execution failed: $_"
            Success = $false
        }
    }
}

function Remove-RemoteMSU {
    param(
        [string]$ComputerName,
        [string]$RemotePath
    )
    
    try {
        $UNCPath = "\\$ComputerName\C$\Windows\Temp\$(Split-Path $RemotePath -Leaf)"
        Remove-Item -Path $UNCPath -Force -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup errors
    }
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MSU Update Deployment Tool" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Initialize logging
$LogFileName = "MSUDeployment_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Script:LogFile = Join-Path $LogPath $LogFileName

if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

Write-Log "MSU Deployment started"
Write-Log "MSU Source Path: $MSUPath"

# Validate MSU path
if (-not (Test-Path $MSUPath)) {
    Write-Log "MSU path not found: $MSUPath" "ERROR"
    exit 1
}

# Scan for MSU files
Write-Log "Scanning for MSU files..."
$MSUFiles = Get-ChildItem -Path $MSUPath -Filter "*.msu" -Recurse -ErrorAction SilentlyContinue

if ($MSUFiles.Count -eq 0) {
    Write-Log "No MSU files found in $MSUPath" "WARNING"
    exit 0
}

Write-Log "Found $($MSUFiles.Count) MSU file(s):" "SUCCESS"
foreach ($MSU in $MSUFiles) {
    $Info = Get-MSUInfo -MSUFile $MSU.FullName
    Write-Log "  - $($Info.FileName) ($($Info.SizeFormatted)) $($Info.KBNumber)"
}

# Get target computers
$TargetComputers = @()

if ($ComputerNames) {
    $TargetComputers = $ComputerNames
} elseif ($ComputerListFile -and (Test-Path $ComputerListFile)) {
    $TargetComputers = Get-Content $ComputerListFile | Where-Object { $_ -and $_ -notmatch '^\s*#' }
} else {
    Write-Log "No target computers specified. Use -ComputerNames or -ComputerListFile" "ERROR"
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  .\Deploy-MSUUpdates.ps1 -ComputerNames 'Server1','Server2'" -ForegroundColor White
    Write-Host "  .\Deploy-MSUUpdates.ps1 -ComputerListFile 'C:\servers.txt'" -ForegroundColor White
    exit 1
}

Write-Log "Target computers: $($TargetComputers.Count)"

if ($WhatIf) {
    Write-Log "=== WHATIF MODE - No changes will be made ===" "WARNING"
}

# Deploy MSU files to each server
$Results = @()
$TotalDeployments = $MSUFiles.Count * $TargetComputers.Count
$CurrentDeployment = 0

foreach ($Computer in $TargetComputers) {
    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    Write-Log "Processing server: $Computer"
    
    # Test connectivity
    $ConnTest = Test-ServerConnectivity -ComputerName $Computer
    if (-not $ConnTest.Success) {
        Write-Log "  Cannot connect: $($ConnTest.Error)" "ERROR"
        foreach ($MSU in $MSUFiles) {
            $Results += [PSCustomObject]@{
                Computer = $Computer
                MSUFile = $MSU.Name
                Status = "Failed"
                Message = $ConnTest.Error
            }
        }
        continue
    }
    
    Write-Log "  Server accessible" "SUCCESS"
    
    foreach ($MSU in $MSUFiles) {
        $CurrentDeployment++
        $MSUInfo = Get-MSUInfo -MSUFile $MSU.FullName
        
        Write-Log "  Deploying: $($MSUInfo.FileName) ($CurrentDeployment/$TotalDeployments)"
        
        if ($WhatIf) {
            Write-Log "    [WHATIF] Would copy and install $($MSUInfo.FileName)" "WARNING"
            $Results += [PSCustomObject]@{
                Computer = $Computer
                MSUFile = $MSU.Name
                KBNumber = $MSUInfo.KBNumber
                Status = "WhatIf"
                Message = "Would be deployed"
            }
            continue
        }
        
        # Copy MSU to server
        Write-Log "    Copying to server..."
        $CopyResult = Copy-MSUToServer -MSUFile $MSU.FullName -ComputerName $Computer
        
        if (-not $CopyResult.Success) {
            Write-Log "    Copy failed: $($CopyResult.Error)" "ERROR"
            $Results += [PSCustomObject]@{
                Computer = $Computer
                MSUFile = $MSU.Name
                KBNumber = $MSUInfo.KBNumber
                Status = "Failed"
                Message = "Copy failed: $($CopyResult.Error)"
            }
            continue
        }
        
        # Install MSU
        Write-Log "    Installing via WUSA..."
        $InstallResult = Install-MSUOnServer -ComputerName $Computer `
            -RemoteMSUPath $CopyResult.RemotePath `
            -NoRestart $NoRestart `
            -Quiet $Quiet `
            -TimeoutMinutes $TimeoutMinutes
        
        if ($InstallResult.Success) {
            Write-Log "    Installation successful: $($InstallResult.Meaning)" "SUCCESS"
            $Status = "Success"
        } else {
            Write-Log "    Installation failed: $($InstallResult.Meaning) (Exit: $($InstallResult.ExitCode))" "ERROR"
            $Status = "Failed"
        }
        
        $Results += [PSCustomObject]@{
            Computer = $Computer
            MSUFile = $MSU.Name
            KBNumber = $MSUInfo.KBNumber
            Status = $Status
            ExitCode = $InstallResult.ExitCode
            Message = $InstallResult.Meaning
        }
        
        # Cleanup
        Remove-RemoteMSU -ComputerName $Computer -RemotePath $CopyResult.RemotePath
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$SuccessCount = ($Results | Where-Object { $_.Status -eq "Success" }).Count
$FailedCount = ($Results | Where-Object { $_.Status -eq "Failed" }).Count
$WhatIfCount = ($Results | Where-Object { $_.Status -eq "WhatIf" }).Count

Write-Log "Total deployments: $($Results.Count)"
Write-Log "Successful: $SuccessCount" "SUCCESS"
Write-Log "Failed: $FailedCount" $(if ($FailedCount -gt 0) { "ERROR" } else { "INFO" })

if ($WhatIfCount -gt 0) {
    Write-Log "WhatIf: $WhatIfCount" "WARNING"
}

# Show failures
$Failures = $Results | Where-Object { $_.Status -eq "Failed" }
if ($Failures.Count -gt 0) {
    Write-Host "`nFailed deployments:" -ForegroundColor Red
    $Failures | Format-Table Computer, MSUFile, Message -AutoSize
}

# Export results
$ResultsFile = Join-Path $LogPath "MSUDeployment_Results_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$Results | ConvertTo-Json -Depth 5 | Out-File $ResultsFile -Encoding UTF8
Write-Log "Results saved to: $ResultsFile"

Write-Host "`n========================================`n" -ForegroundColor Cyan

# Return results for GUI integration
return $Results

#endregion
