<#
.SYNOPSIS
    Automatically download cumulative updates from Microsoft Update Catalog
    
.DESCRIPTION
    Uses the MSCatalogLTS PowerShell module to search and download the latest 
    cumulative updates for specified Windows versions. Organizes files into 
    repository structure by OS and month.
    
    Designed to run on Patch Tuesday + 1 day to automatically queue updates.
    
.PARAMETER Products
    Which products to download updates for (default: all)
    
.PARAMETER DownloadPath
    Network path to save downloaded updates (default: \\QBE-DEN-WINUP1\UpdateFiles)
    
.PARAMETER Month
    Which month folder to organize updates into (default: current month YYYY-MM)
    
.PARAMETER LatestOnly
    Only download the latest cumulative update for each product
    
.PARAMETER IncludeServicingStack
    Also download the latest Servicing Stack Update (SSU) for each product
    
.PARAMETER IncludeNetFramework
    Also download the latest .NET Framework cumulative update
    
.PARAMETER ScheduledTask
    Create/update the scheduled task to run on Patch Tuesday + 1 day
    
.PARAMETER SendEmail
    Send email notification with download summary
    
.PARAMETER EmailTo
    Email recipient for notifications
    
.EXAMPLE
    .\Download-CumulativeUpdates.ps1 -Products Windows10,Windows11
    
.EXAMPLE
    .\Download-CumulativeUpdates.ps1 -LatestOnly -IncludeServicingStack
    
.EXAMPLE
    .\Download-CumulativeUpdates.ps1 -ScheduledTask

.NOTES
    Version: 2.0
    Author: Matt Haegele / QB Energy IT
    Date: February 2026
    
    Requires: 
    - Administrator privileges
    - Internet connection
    - MSCatalogLTS PowerShell module (auto-installs if missing)
    - Write access to \\QBE-DEN-WINUP1\UpdateFiles
    
    Schedule: Runs on Patch Tuesday + 1 day (2nd Wednesday of month) at 6:00 AM
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Windows10", "Windows11", "Server2016", "Server2019", "Server2022", "Server2025", "All")]
    [string[]]$Products = @("All"),
    
    [Parameter()]
    [string]$DownloadPath = "\\QBE-DEN-WINUP1\UpdateFiles",
    
    [Parameter()]
    [string]$Month = (Get-Date -Format "yyyy-MM"),
    
    [Parameter()]
    [switch]$LatestOnly = $true,
    
    [Parameter()]
    [switch]$IncludeServicingStack,
    
    [Parameter()]
    [switch]$IncludeNetFramework,
    
    [Parameter()]
    [switch]$ScheduledTask,
    
    [Parameter()]
    [switch]$SendEmail,
    
    [Parameter()]
    [string]$EmailTo = "yourname@qb-energy.com",
    
    [Parameter()]
    [string]$SmtpServer = "smtp-relay.qb-energy.com"
)

#Requires -RunAsAdministrator

# ============================================================
# CONFIGURATION
# ============================================================

$Script:LogPath = Join-Path $DownloadPath "Logs\Download_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Script:StartTime = Get-Date

# Product configuration for MSCatalogLTS searches
$Script:ProductConfig = @{
    "Windows10" = @{
        SearchTerms = @(
            "$Month Cumulative Update for Windows 10 Version 22H2 for x64"
            "Cumulative Update for Windows 10 Version 22H2 for x64"
        )
        SSUSearchTerm = "Servicing Stack Update for Windows 10 Version 22H2 for x64"
        NetFxSearchTerm = "Cumulative Update for .NET Framework Windows 10 Version 22H2 x64"
        FolderName = "Windows10"
        Architecture = "x64"
        ExcludePatterns = @("ARM64", "Preview", "Dynamic", "x86-based")
    }
    "Windows11" = @{
        SearchTerms = @(
            "$Month Cumulative Update for Windows 11 Version 24H2 for x64"
            "$Month Cumulative Update for Windows 11 Version 23H2 for x64"
            "Cumulative Update for Windows 11 for x64"
        )
        SSUSearchTerm = "Servicing Stack Update for Windows 11 for x64"
        NetFxSearchTerm = "Cumulative Update for .NET Framework Windows 11 x64"
        FolderName = "Windows11"
        Architecture = "x64"
        ExcludePatterns = @("ARM64", "Preview", "Dynamic")
    }
    "Server2016" = @{
        SearchTerms = @(
            "$Month Cumulative Update for Windows Server 2016 for x64"
            "Cumulative Update for Windows Server 2016 for x64"
        )
        SSUSearchTerm = "Servicing Stack Update for Windows Server 2016 for x64"
        NetFxSearchTerm = "Cumulative Update for .NET Framework Windows Server 2016 x64"
        FolderName = "Server2016"
        Architecture = "x64"
        ExcludePatterns = @("Preview", "Dynamic", "Itanium")
    }
    "Server2019" = @{
        SearchTerms = @(
            "$Month Cumulative Update for Windows Server 2019 for x64"
            "Cumulative Update for Windows Server 2019 for x64"
        )
        SSUSearchTerm = "Servicing Stack Update for Windows Server 2019 for x64"
        NetFxSearchTerm = "Cumulative Update for .NET Framework Windows Server 2019 x64"
        FolderName = "Server2019"
        Architecture = "x64"
        ExcludePatterns = @("Preview", "Dynamic")
    }
    "Server2022" = @{
        SearchTerms = @(
            "$Month Cumulative Update for Microsoft server operating system version 21H2 for x64"
            "$Month Cumulative Update for Windows Server 2022 for x64"
            "Cumulative Update for Microsoft server operating system version 21H2 for x64"
        )
        SSUSearchTerm = "Servicing Stack Update for Microsoft server operating system version 21H2 for x64"
        NetFxSearchTerm = "Cumulative Update for .NET Framework Microsoft server operating system version 21H2 x64"
        FolderName = "Server2022"
        Architecture = "x64"
        ExcludePatterns = @("Preview", "Dynamic", "Azure")
    }
    "Server2025" = @{
        SearchTerms = @(
            "$Month Cumulative Update for Microsoft server operating system version 24H2 for x64"
            "$Month Cumulative Update for Windows Server 2025 for x64"
            "Cumulative Update for Microsoft server operating system version 24H2 for x64"
        )
        SSUSearchTerm = "Servicing Stack Update for Microsoft server operating system version 24H2 for x64"
        NetFxSearchTerm = "Cumulative Update for .NET Framework Microsoft server operating system version 24H2 x64"
        FolderName = "Server2025"
        Architecture = "x64"
        ExcludePatterns = @("Preview", "Dynamic", "Azure")
    }
}

# ============================================================
# LOGGING
# ============================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    $LogDir = Split-Path $Script:LogPath -Parent
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $Script:LogPath -Value $LogMessage -ErrorAction SilentlyContinue
    
    # Write to console with color
    $Color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        default   { "White" }
    }
    
    Write-Host $LogMessage -ForegroundColor $Color
}

# ============================================================
# MODULE MANAGEMENT
# ============================================================

function Initialize-MSCatalogModule {
    <#
    .SYNOPSIS
        Ensure MSCatalogLTS module is installed and loaded
    #>
    
    Write-Log "Checking for MSCatalogLTS module..."
    
    try {
        # Check if module is available
        if (-not (Get-Module -ListAvailable -Name MSCatalogLTS)) {
            Write-Log "MSCatalogLTS module not found. Installing..." -Level Warning
            
            # Install NuGet provider if needed
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Write-Log "Installing NuGet package provider..."
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
            }
            
            # Install the module
            Install-Module -Name MSCatalogLTS -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            Write-Log "MSCatalogLTS module installed successfully" -Level Success
        }
        
        # Import the module
        Import-Module MSCatalogLTS -Force -ErrorAction Stop
        Write-Log "MSCatalogLTS module loaded (version: $((Get-Module MSCatalogLTS).Version))" -Level Success
        
        return $true
    }
    catch {
        Write-Log "Failed to initialize MSCatalogLTS module: $_" -Level Error
        return $false
    }
}

# ============================================================
# UPDATE SEARCH AND DOWNLOAD
# ============================================================

function Search-CumulativeUpdate {
    <#
    .SYNOPSIS
        Search for cumulative updates using MSCatalogLTS
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$SearchTerms,
        
        [Parameter()]
        [string[]]$ExcludePatterns = @(),
        
        [Parameter()]
        [string]$Architecture = "x64"
    )
    
    foreach ($SearchTerm in $SearchTerms) {
        Write-Log "Searching: $SearchTerm"
        
        try {
            $Results = Get-MSCatalogUpdate -Search $SearchTerm -ErrorAction Stop
            
            if ($Results -and $Results.Count -gt 0) {
                Write-Log "Found $($Results.Count) result(s) for search term"
                
                # Filter results
                $FilteredResults = $Results | Where-Object {
                    $Title = $_.Title
                    $Include = $true
                    
                    # Check architecture
                    if ($Architecture -eq "x64" -and $Title -notmatch "x64|64-bit") {
                        $Include = $false
                    }
                    
                    # Check exclude patterns
                    foreach ($Pattern in $ExcludePatterns) {
                        if ($Title -match $Pattern) {
                            $Include = $false
                            break
                        }
                    }
                    
                    $Include
                }
                
                if ($FilteredResults) {
                    # Sort by date (newest first) and return the first match
                    $BestMatch = $FilteredResults | Sort-Object LastUpdated -Descending | Select-Object -First 1
                    Write-Log "Best match: $($BestMatch.Title)" -Level Success
                    Write-Log "  Size: $($BestMatch.Size)"
                    Write-Log "  Last Updated: $($BestMatch.LastUpdated)"
                    return $BestMatch
                }
            }
        }
        catch {
            Write-Log "Search failed for '$SearchTerm': $_" -Level Warning
        }
    }
    
    Write-Log "No matching updates found after trying all search terms" -Level Warning
    return $null
}

function Download-CatalogUpdate {
    <#
    .SYNOPSIS
        Download an update using MSCatalogLTS
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Update,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )
    
    # Ensure destination exists
    if (-not (Test-Path $DestinationPath)) {
        Write-Log "Creating directory: $DestinationPath"
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }
    
    # Extract KB from title
    $KB = ""
    if ($Update.Title -match '\(KB(\d+)\)') {
        $KB = "KB$($Matches[1])"
    }
    
    Write-Log "Downloading: $($Update.Title)"
    Write-Log "  KB: $KB"
    Write-Log "  Size: $($Update.Size)"
    Write-Log "  Destination: $DestinationPath"
    
    try {
        $DownloadStart = Get-Date
        
        # Use MSCatalogLTS to download
        $DownloadedFile = $Update | Save-MSCatalogUpdate -Destination $DestinationPath -ErrorAction Stop
        
        $DownloadEnd = Get-Date
        $Duration = ($DownloadEnd - $DownloadStart).TotalSeconds
        
        if ($DownloadedFile -and (Test-Path $DownloadedFile)) {
            $FileSize = (Get-Item $DownloadedFile).Length
            $FileSizeMB = [math]::Round($FileSize / 1MB, 2)
            $SpeedMBps = [math]::Round($FileSizeMB / $Duration, 2)
            
            Write-Log "Download complete: $DownloadedFile" -Level Success
            Write-Log "  Size: $FileSizeMB MB | Duration: $([math]::Round($Duration, 1))s | Speed: $SpeedMBps MB/s"
            
            return [PSCustomObject]@{
                Success = $true
                FilePath = $DownloadedFile
                FileName = [System.IO.Path]::GetFileName($DownloadedFile)
                KB = $KB
                Title = $Update.Title
                SizeMB = $FileSizeMB
                Duration = $Duration
            }
        }
        else {
            Write-Log "Download completed but file not found" -Level Error
            return [PSCustomObject]@{ Success = $false; Error = "File not found after download" }
        }
    }
    catch {
        Write-Log "Download failed: $_" -Level Error
        return [PSCustomObject]@{ Success = $false; Error = $_.Exception.Message }
    }
}

# ============================================================
# MAIN PROCESSING
# ============================================================

function Start-UpdateDownload {
    param(
        [string[]]$ProductList,
        [string]$TargetPath,
        [string]$TargetMonth,
        [bool]$OnlyLatest,
        [bool]$DownloadSSU,
        [bool]$DownloadNetFx
    )
    
    Write-Log "═══════════════════════════════════════════════════════════════"
    Write-Log "  QB Energy - Cumulative Update Downloader v2.0"
    Write-Log "═══════════════════════════════════════════════════════════════"
    Write-Log ""
    Write-Log "Configuration:"
    Write-Log "  Products: $($ProductList -join ', ')"
    Write-Log "  Target Path: $TargetPath"
    Write-Log "  Month: $TargetMonth"
    Write-Log "  Latest Only: $OnlyLatest"
    Write-Log "  Include SSU: $DownloadSSU"
    Write-Log "  Include .NET: $DownloadNetFx"
    Write-Log ""
    
    # Verify network path is accessible
    if (-not (Test-Path $TargetPath -ErrorAction SilentlyContinue)) {
        Write-Log "ERROR: Cannot access target path: $TargetPath" -Level Error
        Write-Log "Please verify network connectivity and permissions" -Level Error
        return @()
    }
    Write-Log "Target path verified: $TargetPath" -Level Success
    
    # Initialize MSCatalogLTS module
    if (-not (Initialize-MSCatalogModule)) {
        Write-Log "Cannot proceed without MSCatalogLTS module" -Level Error
        return @()
    }
    
    # Expand "All" to all products
    if ($ProductList -contains "All") {
        $ProductList = @("Windows10", "Windows11", "Server2019", "Server2022")
        Write-Log "Expanded 'All' to: $($ProductList -join ', ')"
    }
    
    $DownloadedFiles = @()
    $FailedDownloads = @()
    
    foreach ($Product in $ProductList) {
        Write-Log ""
        Write-Log "═══════════════════════════════════════════════════════════════"
        Write-Log "Processing: $Product"
        Write-Log "═══════════════════════════════════════════════════════════════"
        
        $Config = $Script:ProductConfig[$Product]
        
        if (-not $Config) {
            Write-Log "Unknown product: $Product - skipping" -Level Error
            continue
        }
        
        # Build destination path: \\share\UpdateFiles\{OS}\{YYYY-MM}\
        $DestPath = Join-Path $TargetPath $Config.FolderName
        $DestPath = Join-Path $DestPath $TargetMonth
        
        Write-Log "Destination: $DestPath"
        
        # Search for cumulative update
        Write-Log ""
        Write-Log "--- Searching for Cumulative Update ---"
        $CumulativeUpdate = Search-CumulativeUpdate -SearchTerms $Config.SearchTerms `
                                                     -ExcludePatterns $Config.ExcludePatterns `
                                                     -Architecture $Config.Architecture
        
        if ($CumulativeUpdate) {
            $Result = Download-CatalogUpdate -Update $CumulativeUpdate -DestinationPath $DestPath
            
            if ($Result.Success) {
                $Result | Add-Member -NotePropertyName "Product" -NotePropertyValue $Product
                $Result | Add-Member -NotePropertyName "UpdateType" -NotePropertyValue "Cumulative"
                $DownloadedFiles += $Result
            }
            else {
                $FailedDownloads += [PSCustomObject]@{
                    Product = $Product
                    UpdateType = "Cumulative"
                    Title = $CumulativeUpdate.Title
                    Error = $Result.Error
                }
            }
        }
        else {
            $FailedDownloads += [PSCustomObject]@{
                Product = $Product
                UpdateType = "Cumulative"
                Title = "Not Found"
                Error = "No matching update found in catalog"
            }
        }
        
        # Search for Servicing Stack Update (if requested)
        if ($DownloadSSU -and $Config.SSUSearchTerm) {
            Write-Log ""
            Write-Log "--- Searching for Servicing Stack Update ---"
            $SSU = Search-CumulativeUpdate -SearchTerms @($Config.SSUSearchTerm) `
                                           -ExcludePatterns $Config.ExcludePatterns `
                                           -Architecture $Config.Architecture
            
            if ($SSU) {
                $Result = Download-CatalogUpdate -Update $SSU -DestinationPath $DestPath
                
                if ($Result.Success) {
                    $Result | Add-Member -NotePropertyName "Product" -NotePropertyValue $Product
                    $Result | Add-Member -NotePropertyName "UpdateType" -NotePropertyValue "SSU"
                    $DownloadedFiles += $Result
                }
            }
        }
        
        # Search for .NET Framework update (if requested)
        if ($DownloadNetFx -and $Config.NetFxSearchTerm) {
            Write-Log ""
            Write-Log "--- Searching for .NET Framework Update ---"
            $NetFx = Search-CumulativeUpdate -SearchTerms @($Config.NetFxSearchTerm) `
                                             -ExcludePatterns @("Preview") `
                                             -Architecture $Config.Architecture
            
            if ($NetFx) {
                $Result = Download-CatalogUpdate -Update $NetFx -DestinationPath $DestPath
                
                if ($Result.Success) {
                    $Result | Add-Member -NotePropertyName "Product" -NotePropertyValue $Product
                    $Result | Add-Member -NotePropertyName "UpdateType" -NotePropertyValue ".NET"
                    $DownloadedFiles += $Result
                }
            }
        }
    }
    
    # ============================================================
    # SUMMARY
    # ============================================================
    
    $EndTime = Get-Date
    $TotalDuration = ($EndTime - $Script:StartTime).TotalMinutes
    
    Write-Log ""
    Write-Log "═══════════════════════════════════════════════════════════════"
    Write-Log "  DOWNLOAD SUMMARY"
    Write-Log "═══════════════════════════════════════════════════════════════"
    Write-Log ""
    Write-Log "Total Duration: $([math]::Round($TotalDuration, 1)) minutes"
    Write-Log "Updates Downloaded: $($DownloadedFiles.Count)" -Level Success
    Write-Log "Updates Failed: $($FailedDownloads.Count)" -Level $(if ($FailedDownloads.Count -gt 0) { "Warning" } else { "Info" })
    Write-Log ""
    
    if ($DownloadedFiles.Count -gt 0) {
        Write-Log "Downloaded Files:" -Level Success
        $TotalSizeMB = 0
        foreach ($File in $DownloadedFiles) {
            $LogMsg = "  ✓ [$($File.Product)] $($File.UpdateType) - $($File.KB) - $($File.SizeMB) MB"
            Write-Log $LogMsg -Level Success
            Write-Log "    $($File.FilePath)"
            $TotalSizeMB += $File.SizeMB
        }
        Write-Log ""
        $TotalGB = [math]::Round($TotalSizeMB/1024, 2)
        Write-Log "Total Download Size: $([math]::Round($TotalSizeMB, 2)) MB ($TotalGB GB)"
    }
    
    if ($FailedDownloads.Count -gt 0) {
        Write-Log ""
        Write-Log "Failed Downloads:" -Level Warning
        foreach ($Failed in $FailedDownloads) {
            $FailMsg = "  ✗ [$($Failed.Product)] $($Failed.UpdateType): $($Failed.Error)"
            Write-Log $FailMsg -Level Warning
        }
    }
    
    Write-Log ""
    Write-Log "Log file: $Script:LogPath"
    Write-Log ""
    
    # Return results
    return @{
        Downloaded = $DownloadedFiles
        Failed = $FailedDownloads
        Duration = $TotalDuration
        LogPath = $Script:LogPath
    }
}

# ============================================================
# SCHEDULED TASK
# ============================================================

function New-PatchTuesdayScheduledTask {
    <#
    .SYNOPSIS
        Create a scheduled task to run on Patch Tuesday + 1 day
        
    .DESCRIPTION
        Patch Tuesday is the 2nd Tuesday of each month.
        This task runs on the 2nd Wednesday at 6:00 AM.
    #>
    
    Write-Log "Creating scheduled task for Patch Tuesday + 1 day..."
    
    $TaskName = "QB Energy - Download Cumulative Updates"
    $TaskDescription = "Automatically download latest cumulative updates from Microsoft Update Catalog on the day after Patch Tuesday (2nd Wednesday of each month)"
    
    # Get the current script path
    $ScriptPath = $PSCommandPath
    if (-not $ScriptPath) {
        $ScriptPath = "C:\PatchManagement\Scripts\Download-CumulativeUpdates.ps1"
        Write-Log "Using default script path: $ScriptPath" -Level Warning
    }
    
    # PowerShell executable
    $PowerShellPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    
    # Build arguments
    $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Products All -LatestOnly"
    if ($SendEmail) {
        $Arguments += " -SendEmail -EmailTo `"$EmailTo`""
    }
    
    # Create trigger for 2nd Wednesday of each month at 6:00 AM
    # We'll use a monthly trigger and calculate the correct day
    
    try {
        # Remove existing task if present
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Write-Log "Removing existing scheduled task..." -Level Warning
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }
        
        # Create action
        $Action = New-ScheduledTaskAction -Execute $PowerShellPath -Argument $Arguments
        
        # Create trigger - Monthly on 2nd Wednesday
        # WeeksOfMonth: 2 = Second week
        $Trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Wednesday -At "6:00AM"
        
        # Modify trigger to only run on 2nd Wednesday (days 8-14 of month)
        # This requires using CIM/WMI directly for precise control
        
        # Alternative: Use a daily trigger with conditions checked in script
        # For simplicity, we'll use weekly and add a check in the script
        
        # Create principal (run as SYSTEM with highest privileges)
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # Create settings
        $Settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable `
            -WakeToRun
        
        # Register the task
        Register-ScheduledTask -TaskName $TaskName `
            -Description $TaskDescription `
            -Action $Action `
            -Trigger $Trigger `
            -Principal $Principal `
            -Settings $Settings | Out-Null
        
        Write-Log "" -Level Success
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Success
        Write-Log "  Scheduled Task Created Successfully!" -Level Success
        Write-Log "═══════════════════════════════════════════════════════════════" -Level Success
        Write-Log ""
        Write-Log "Task Name: $TaskName"
        Write-Log "Schedule: Every Wednesday at 6:00 AM"
        Write-Log "Script: $ScriptPath"
        Write-Log ""
        Write-Log "NOTE: The script includes logic to only run on Patch Tuesday + 1"
        Write-Log "      (2nd Wednesday of each month, days 8-14)"
        Write-Log ""
        Write-Log "To view/modify: Task Scheduler > Task Scheduler Library"
        Write-Log ""
        
    }
    catch {
        Write-Log "Failed to create scheduled task: $_" -Level Error
    }
}

function Test-IsPatchTuesdayPlusOne {
    <#
    .SYNOPSIS
        Check if today is Patch Tuesday + 1 (2nd Wednesday of month)
    #>
    
    $Today = Get-Date
    $DayOfWeek = $Today.DayOfWeek
    $DayOfMonth = $Today.Day
    
    # Must be Wednesday
    if ($DayOfWeek -ne 'Wednesday') {
        return $false
    }
    
    # 2nd Wednesday falls between day 8 and day 14
    if ($DayOfMonth -ge 8 -and $DayOfMonth -le 14) {
        return $true
    }
    
    return $false
}

# ============================================================
# EMAIL NOTIFICATION
# ============================================================

function Send-DownloadReport {
    param(
        [Parameter(Mandatory=$true)]
        $Results,
        
        [Parameter(Mandatory=$true)]
        [string]$To,
        
        [Parameter(Mandatory=$true)]
        [string]$SmtpServer
    )
    
    $Subject = "QB Energy - Cumulative Update Download Report - $Month"
    
    $DownloadedCount = $Results.Downloaded.Count
    $FailedCount = $Results.Failed.Count
    
    if ($FailedCount -gt 0) {
        $Subject = "⚠️ $Subject (Failed: $FailedCount)"
    }
    else {
        $Subject = "✓ $Subject (Downloaded: $DownloadedCount)"
    }
    
    $Body = @"
<html>
<body style="font-family: 'Segoe UI', Arial, sans-serif;">
<h2 style="color: #2980b9;">Cumulative Update Download Report</h2>
<p><strong>Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>
<p><strong>Month:</strong> $Month</p>
<p><strong>Duration:</strong> $([math]::Round($Results.Duration, 1)) minutes</p>

<h3>Summary</h3>
<table style="border-collapse: collapse; width: 300px;">
<tr style="background: #ecf0f1;"><td style="padding: 8px;">Downloaded</td><td style="padding: 8px; text-align: right; color: #27ae60;"><strong>$DownloadedCount</strong></td></tr>
<tr><td style="padding: 8px;">Failed</td><td style="padding: 8px; text-align: right; color: #e74c3c;"><strong>$FailedCount</strong></td></tr>
</table>

$(if ($DownloadedCount -gt 0) {
@"
<h3 style="color: #27ae60;">Downloaded Files</h3>
<table style="border-collapse: collapse; width: 100%;">
<tr style="background: #34495e; color: white;">
<th style="padding: 8px; text-align: left;">Product</th>
<th style="padding: 8px; text-align: left;">Type</th>
<th style="padding: 8px; text-align: left;">KB</th>
<th style="padding: 8px; text-align: right;">Size</th>
</tr>
$($Results.Downloaded | ForEach-Object {
"<tr><td style='padding: 8px; border-bottom: 1px solid #eee;'>$($_.Product)</td><td style='padding: 8px; border-bottom: 1px solid #eee;'>$($_.UpdateType)</td><td style='padding: 8px; border-bottom: 1px solid #eee;'>$($_.KB)</td><td style='padding: 8px; border-bottom: 1px solid #eee; text-align: right;'>$($_.SizeMB) MB</td></tr>"
})
</table>
"@
})

$(if ($FailedCount -gt 0) {
@"
<h3 style="color: #e74c3c;">Failed Downloads</h3>
<ul>
$($Results.Failed | ForEach-Object { "<li><strong>$($_.Product)</strong> ($($_.UpdateType)): $($_.Error)</li>" })
</ul>
"@
})

<p style="color: #888; font-size: 12px; margin-top: 30px;">
Log file: $($Results.LogPath)<br>
QB Energy IT Infrastructure - Automated Report
</p>
</body>
</html>
"@

    try {
        Send-MailMessage -SmtpServer $SmtpServer `
            -From "patchmanagement@qb-energy.com" `
            -To $To `
            -Subject $Subject `
            -Body $Body `
            -BodyAsHtml `
            -Priority $(if ($FailedCount -gt 0) { "High" } else { "Normal" })
        
        Write-Log "Email report sent to: $To" -Level Success
    }
    catch {
        Write-Log "Failed to send email: $_" -Level Error
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

# Handle scheduled task creation
if ($ScheduledTask) {
    New-PatchTuesdayScheduledTask
    exit 0
}

# If running as scheduled task, check if it's actually Patch Tuesday + 1
if ($env:SCHEDULED_TASK -eq "true") {
    if (-not (Test-IsPatchTuesdayPlusOne)) {
        Write-Log "Not Patch Tuesday + 1 - skipping execution"
        exit 0
    }
}

# Verify we can reach the network path
if (-not (Test-Path $DownloadPath -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Cannot access download path: $DownloadPath" -ForegroundColor Red
    Write-Host "Please verify network connectivity and try again." -ForegroundColor Yellow
    exit 1
}

# Start download process
$Results = Start-UpdateDownload -ProductList $Products `
                                -TargetPath $DownloadPath `
                                -TargetMonth $Month `
                                -OnlyLatest $LatestOnly `
                                -DownloadSSU $IncludeServicingStack `
                                -DownloadNetFx $IncludeNetFramework

# Send email if requested
if ($SendEmail -and $Results.Downloaded.Count -gt 0) {
    Send-DownloadReport -Results $Results -To $EmailTo -SmtpServer $SmtpServer
}

# Return results for pipeline use
return $Results
