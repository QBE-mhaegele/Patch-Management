<#
.SYNOPSIS
    Download latest Windows updates from Microsoft Update Catalog
.DESCRIPTION
    Downloads latest updates for specified Windows versions using simple, reliable search terms.
    Tracks downloads to avoid duplicates.
.PARAMETER Products
    Which products to download updates for (default: all)
.PARAMETER DownloadPath
    Where to save downloaded updates (default: D:\UpdateFiles)
.PARAMETER Month
    Which month to organize updates into (default: current month YYYY-MM)
.PARAMETER LatestOnly
    Only download the latest update for each product (default: true)
.PARAMETER ScheduledTask
    Create a scheduled task to run monthly on Patch Tuesday + 1 day
.PARAMETER SkipDownload
    Skip downloading, just show what would be downloaded
.EXAMPLE
    .\Download-WindowsUpdates.ps1 -Products Windows10,Windows11
.EXAMPLE
    .\Download-WindowsUpdates.ps1 -LatestOnly
.EXAMPLE
    .\Download-WindowsUpdates.ps1 -SkipDownload
.NOTES
    Version: 5.1
    Author: Matt Haegele
    Requires: Administrator privileges, Internet connection
    Runs on: WINUP1 or any server with repository access
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Windows10", "Windows11", "Server2019", "Server2022", "All")]
    [string[]]$Products = @("All"),
    
    [Parameter()]
    [string]$DownloadPath = "D:\UpdateFiles",
    
    [Parameter()]
    [string]$Month = (Get-Date -Format "yyyy-MM"),
    
    [Parameter()]
    [switch]$LatestOnly = $true,
    
    [Parameter()]
    [switch]$ScheduledTask,
    
    [Parameter()]
    [switch]$SkipDownload
)

#Requires -RunAsAdministrator

# ============================================================
# CONFIGURATION
# ============================================================

$Script:LogPath = Join-Path $DownloadPath "Logs\Download_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Script:CatalogBaseUrl = "https://www.catalog.update.microsoft.com"

# Simple, reliable search terms for each product
# These are actual terms that work on the Microsoft Update Catalog website
$Script:ProductSearchTerms = @{
    "Windows10" = @(
        "Windows 10 Version 22H2 x64",
        "Windows 10 Version 21H2 x64", 
        "Cumulative Update Windows 10 x64",
        "Security Update Windows 10 x64"
    )
    "Windows11" = @(
        "Windows 11 Version 23H2 x64",
        "Windows 11 Version 22H2 x64",
        "Cumulative Update Windows 11 x64",
        "Security Update Windows 11 x64"
    )
    "Server2019" = @(
        "Windows Server 2019 x64",
        "Cumulative Update Windows Server 2019",
        "Security Update Windows Server 2019"
    )
    "Server2022" = @(
        "Windows Server 2022 x64",
        "Cumulative Update Windows Server 2022",
        "Security Update Windows Server 2022"
    )
}

$Script:ProductFolders = @{
    "Windows10" = "Windows10"
    "Windows11" = "Windows11"
    "Server2019" = "Server2019"
    "Server2022" = "Server2022"
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
    Add-Content -Path $Script:LogPath -Value $LogMessage
    
    # Write to console with color
    $Color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    
    Write-Host $LogMessage -ForegroundColor $Color
}

# ============================================================
# FILE MANAGEMENT FUNCTIONS
# ============================================================

function Find-ExistingUpdates {
    <#
    .SYNOPSIS
        Find existing updates in the download repository
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Product,
        
        [Parameter(Mandatory=$true)]
        [string]$MonthFolder
    )
    
    $productFolder = $Script:ProductFolders[$Product]
    if (-not $productFolder) {
        return @()
    }
    
    $searchPath = Join-Path $DownloadPath "$productFolder\$MonthFolder"
    
    if (-not (Test-Path $searchPath)) {
        return @()
    }
    
    # Find all .msu files
    $msuFiles = Get-ChildItem -Path $searchPath -Filter "*.msu" -File
    
    $existingUpdates = @()
    
    foreach ($file in $msuFiles) {
        # Try to extract KB from filename
        $kb = ""
        if ($file.Name -match 'KB(\d+)') {
            $kb = "KB$($Matches[1])"
        }
        
        $existingUpdates += [PSCustomObject]@{
            FilePath = $file.FullName
            FileName = $file.Name
            KB = $kb
            SizeMB = [math]::Round($file.Length / 1MB, 2)
            LastWriteTime = $file.LastWriteTime
            Product = $Product
        }
    }
    
    return $existingUpdates
}

function Check-IfUpdateExists {
    <#
    .SYNOPSIS
        Check if a specific KB already exists in the repository
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$KB,
        
        [Parameter(Mandatory=$true)]
        [string]$Product,
        
        [Parameter()]
        [string]$MonthFolder = $Month
    )
    
    # Check current month folder
    $existingUpdates = Find-ExistingUpdates -Product $Product -MonthFolder $MonthFolder
    
    $matchingFile = $existingUpdates | Where-Object { $_.KB -eq $KB }
    
    if ($matchingFile) {
        Write-Log "Update $KB for $Product already exists in $MonthFolder : $($matchingFile.FileName)" -Level Success
        return $true
    }
    
    # If not found in current month, check all months for this product
    $productFolder = $Script:ProductFolders[$Product]
    if ($productFolder) {
        $productPath = Join-Path $DownloadPath $productFolder
        if (Test-Path $productPath) {
            $allMonths = Get-ChildItem -Path $productPath -Directory
            foreach ($monthDir in $allMonths) {
                $monthUpdates = Find-ExistingUpdates -Product $Product -MonthFolder $monthDir.Name
                $matchingFile = $monthUpdates | Where-Object { $_.KB -eq $KB }
                if ($matchingFile) {
                    Write-Log "Update $KB for $Product already exists in $($monthDir.Name) : $($matchingFile.FileName)" -Level Success
                    return $true
                }
            }
        }
    }
    
    return $false
}

# ============================================================
# CATALOG SEARCH FUNCTIONS
# ============================================================

function Search-MicrosoftCatalog {
    <#
    .SYNOPSIS
        Search Microsoft Update Catalog for updates
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchTerm
    )
    
    Write-Log "Searching Microsoft Catalog for: $SearchTerm" -Level Info
    
    try {
        # Encode the search term
        $encodedTerm = [System.Web.HttpUtility]::UrlEncode($SearchTerm)
        $searchUrl = "$Script:CatalogBaseUrl/Search.aspx?q=$encodedTerm"
        
        Write-Log "Search URL: $searchUrl" -Level Info
        
        # Get the search results page
        $response = Invoke-WebRequest -Uri $searchUrl -UseBasicParsing -UserAgent "Mozilla/5.0" -TimeoutSec 30
        
        # Parse update IDs from the page
        $updateIds = @()
        
        # Look for goToDetails function calls - this is how the catalog page links to updates
        $pattern = "goToDetails\('([A-Fa-f0-9\-]+)',\s*\d+\)"
        $matches = [regex]::Matches($response.Content, $pattern)
        
        foreach ($match in $matches) {
            $updateId = $match.Groups[1].Value
            if ($updateId -and -not ($updateIds -contains $updateId)) {
                $updateIds += $updateId
            }
        }
        
        Write-Log "Found $($updateIds.Count) potential updates" -Level Info
        return $updateIds
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Search failed for '$SearchTerm' : $errorMsg" -Level Error
        return @()
    }
}

function Get-UpdateDetails {
    <#
    .SYNOPSIS
        Get details for a specific update
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UpdateId
    )
    
    try {
        $detailsUrl = "$Script:CatalogBaseUrl/ScopedViewInline.aspx?updateid=$UpdateId"
        $response = Invoke-WebRequest -Uri $detailsUrl -UseBasicParsing -UserAgent "Mozilla/5.0" -TimeoutSec 30
        
        # Extract title
        $title = ""
        if ($response.Content -match '<span id="ScopedViewHandler_title"[^>]*>(.*?)</span>') {
            $title = $Matches[1].Trim()
        }
        
        # Extract KB number
        $kb = ""
        if ($title -match '\(KB(\d+)\)') {
            $kb = "KB$($Matches[1])"
        }
        
        # Only process if we have a KB number and it's for x64
        if ($kb -eq "" -or $title -notmatch "x64") {
            return $null
        }
        
        # Exclude preview and other unwanted updates
        if ($title -match "Preview|Beta|Insider|Adobe Flash|Dynamic Update|Servicing Stack") {
            Write-Log "Skipping excluded update: $title" -Level Warning
            return $null
        }
        
        # Get download URLs (MSU files only)
        $downloadUrls = @()
        $pattern = 'downloadInformation\[\d+\]\.files\[\d+\]\.url = ''(https?://[^'']+\.msu)'''
        $matches = [regex]::Matches($response.Content, $pattern)
        
        foreach ($match in $matches) {
            $downloadUrls += $match.Groups[1].Value
        }
        
        if ($downloadUrls.Count -eq 0) {
            Write-Log "No .msu download links found for $UpdateId" -Level Warning
            return $null
        }
        
        # Get release date
        $releaseDate = ""
        if ($response.Content -match 'Last Updated:.*?(\d+/\d+/\d+)') {
            $releaseDate = $Matches[1]
        }
        
        return [PSCustomObject]@{
            UpdateId = $UpdateId
            Title = $title
            KB = $kb
            DownloadUrls = $downloadUrls
            ReleaseDate = $releaseDate
        }
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Failed to get update details for $UpdateId : $errorMsg" -Level Warning
        return $null
    }
}

function Find-LatestUpdate {
    <#
    .SYNOPSIS
        Find the latest update for a product
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Product
    )
    
    $searchTerms = $Script:ProductSearchTerms[$Product]
    if (-not $searchTerms) {
        Write-Log "No search terms configured for product: $Product" -Level Error
        return $null
    }
    
    $allUpdates = @()
    
    foreach ($searchTerm in $searchTerms) {
        Write-Log "Trying search term: $searchTerm" -Level Info
        
        $updateIds = Search-MicrosoftCatalog -SearchTerm $searchTerm
        
        foreach ($updateId in $updateIds) {
            $updateInfo = Get-UpdateDetails -UpdateId $updateId
            
            if ($updateInfo) {
                # Check if we already have this update
                $alreadyExists = Check-IfUpdateExists -KB $updateInfo.KB -Product $Product
                
                if (-not $alreadyExists) {
                    $allUpdates += $updateInfo
                    Write-Log "Found new update: $($updateInfo.Title)" -Level Success
                } else {
                    Write-Log "Update $($updateInfo.KB) already exists, skipping" -Level Info
                }
            }
        }
        
        # If we found updates and LatestOnly is true, we can stop
        if ($allUpdates.Count -gt 0 -and $LatestOnly) {
            break
        }
    }
    
    if ($allUpdates.Count -eq 0) {
        Write-Log "No new updates found for $Product" -Level Warning
        return $null
    }
    
    # Return the most recent update based on release date
    $latestUpdate = $allUpdates | Sort-Object -Property { 
        if ($_.ReleaseDate) {
            try {
                [datetime]::ParseExact($_.ReleaseDate, 'M/d/yyyy', $null)
            } catch {
                [datetime]::MinValue
            }
        } else {
            [datetime]::MinValue
        }
    } -Descending | Select-Object -First 1
    
    return $latestUpdate
}

# ============================================================
# DOWNLOAD FUNCTIONS
# ============================================================

function Download-Update {
    <#
    .SYNOPSIS
        Download an update file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DownloadUrl,
        
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        
        [Parameter(Mandatory=$true)]
        [string]$Product,
        
        [Parameter(Mandatory=$true)]
        [string]$KB,
        
        [Parameter(Mandatory=$true)]
        [string]$Title
    )
    
    $fileName = Split-Path $DownloadUrl -Leaf
    $destinationFile = Join-Path $DestinationPath $fileName
    
    # Check if file already exists
    if (Test-Path $destinationFile) {
        Write-Log "File already exists: $fileName" -Level Warning
        return $destinationFile
    }
    
    # Ensure destination directory exists
    if (-not (Test-Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Log "Downloading: $fileName" -Level Info
    Write-Log "From: $DownloadUrl" -Level Info
    
    try {
        # Use WebClient for download
        $webClient = New-Object System.Net.WebClient
        
        # Show progress
        $eventHandler = {
            param($sender, $e)
            $progress = $e.ProgressPercentage
            if ($progress % 25 -eq 0) {  # Reduce verbosity
                Write-Progress -Activity "Downloading $fileName" -Status "$progress% Complete" -PercentComplete $progress
            }
        }
        
        $event = Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action $eventHandler
        
        # Download the file
        $webClient.DownloadFile($DownloadUrl, $destinationFile)
        
        # Clean up
        Unregister-Event -SubscriptionId $event.Id -ErrorAction SilentlyContinue
        Write-Progress -Activity "Downloading $fileName" -Completed
        
        # Verify download
        if (Test-Path $destinationFile) {
            $fileInfo = Get-Item $destinationFile
            $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
            
            if ($fileInfo.Length -gt 0) {
                Write-Log "Download completed: $fileName ($fileSizeMB MB)" -Level Success
                return $destinationFile
            } else {
                Write-Log "Download failed: File is empty" -Level Error
                Remove-Item $destinationFile -Force -ErrorAction SilentlyContinue
                return $null
            }
        } else {
            Write-Log "Download failed: File not created" -Level Error
            return $null
        }
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Download failed: $errorMsg" -Level Error
        
        # Clean up failed download
        if (Test-Path $destinationFile) {
            Remove-Item $destinationFile -Force -ErrorAction SilentlyContinue
        }
        
        return $null
    }
}

# ============================================================
# MAIN PROCESSING
# ============================================================

function Process-Product {
    <#
    .SYNOPSIS
        Process updates for a single product
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Product,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetPath,
        
        [Parameter(Mandatory=$true)]
        [string]$MonthFolder
    )
    
    $downloadedFiles = @()
    
    Write-Log ""
    Write-Log ("=" * 60) -Level Info
    Write-Log "PROCESSING: $Product" -Level Info
    Write-Log ("=" * 60) -Level Info
    
    # First, check what we already have
    $existingUpdates = Find-ExistingUpdates -Product $Product -MonthFolder $MonthFolder
    Write-Log "Found $($existingUpdates.Count) existing updates for $Product in $MonthFolder" -Level Info
    
    # Find the latest update
    $latestUpdate = Find-LatestUpdate -Product $Product
    
    if (-not $latestUpdate) {
        Write-Log "No new updates found for $Product" -Level Info
        return $downloadedFiles
    }
    
    Write-Log ""
    Write-Log "Latest update found:" -Level Success
    Write-Log "  Title: $($latestUpdate.Title)" -Level Info
    Write-Log "  KB: $($latestUpdate.KB)" -Level Info
    Write-Log "  Release Date: $($latestUpdate.ReleaseDate)" -Level Info
    Write-Log "  Download Files: $($latestUpdate.DownloadUrls.Count)" -Level Info
    
    # Build destination path
    $productFolder = $Script:ProductFolders[$Product]
    $destPath = Join-Path $TargetPath "$productFolder\$MonthFolder"
    
    # Process each download URL
    foreach ($downloadUrl in $latestUpdate.DownloadUrls) {
        if ($SkipDownload) {
            Write-Log "SkipDownload mode: Would download $($latestUpdate.KB)" -Level Info
            $downloadedFiles += [PSCustomObject]@{
                Product = $Product
                KB = $latestUpdate.KB
                Title = $latestUpdate.Title
                FilePath = "SkipDownload mode"
                SizeMB = "N/A"
                ReleaseDate = $latestUpdate.ReleaseDate
                DownloadDate = "Not downloaded"
            }
        } else {
            $downloadedFile = Download-Update -DownloadUrl $downloadUrl `
                -DestinationPath $destPath `
                -Product $Product `
                -KB $latestUpdate.KB `
                -Title $latestUpdate.Title
            
            if ($downloadedFile) {
                $fileInfo = Get-Item $downloadedFile
                $downloadedFiles += [PSCustomObject]@{
                    Product = $Product
                    KB = $latestUpdate.KB
                    Title = $latestUpdate.Title
                    FilePath = $downloadedFile
                    SizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                    ReleaseDate = $latestUpdate.ReleaseDate
                    DownloadDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        }
    }
    
    return $downloadedFiles
}

# ============================================================
# INVENTORY FUNCTIONS
# ============================================================

function Show-Inventory {
    <#
    .SYNOPSIS
        Show inventory of all downloaded updates
    #>
    
    Write-Log ""
    Write-Log ("=" * 60) -Level Info
    Write-Log "UPDATE INVENTORY" -Level Info
    Write-Log ("=" * 60) -Level Info
    
    $allUpdates = @()
    
    foreach ($product in $Script:ProductFolders.Keys) {
        $productFolder = $Script:ProductFolders[$product]
        $productPath = Join-Path $DownloadPath $productFolder
        
        if (Test-Path $productPath) {
            $monthFolders = Get-ChildItem -Path $productPath -Directory
            
            foreach ($monthFolder in $monthFolders) {
                $updates = Find-ExistingUpdates -Product $product -MonthFolder $monthFolder.Name
                $allUpdates += $updates
            }
        }
    }
    
    if ($allUpdates.Count -eq 0) {
        Write-Log "No updates found in repository" -Level Warning
        return
    }
    
    Write-Log "Total updates in repository: $($allUpdates.Count)" -Level Success
    Write-Log ""
    
    # Group by product
    $groupedUpdates = $allUpdates | Group-Object Product
    
    foreach ($group in $groupedUpdates) {
        Write-Log "$($group.Name): $($group.Count) updates" -Level Success
        
        # Group by month within product
        $byMonth = $group.Group | Group-Object { 
            $monthPath = Split-Path (Split-Path $_.FilePath -Parent) -Leaf
            $monthPath
        }
        
        foreach ($monthGroup in $byMonth) {
            Write-Log "  $($monthGroup.Name): $($monthGroup.Count) updates" -Level Info
            
            foreach ($update in $monthGroup.Group | Sort-Object KB) {
                Write-Log "    $($update.KB) - $($update.FileName) ($($update.SizeMB) MB)" -Level Info
            }
        }
        Write-Log ""
    }
    
    # Save inventory to CSV
    $inventoryPath = Join-Path $DownloadPath "Inventory_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $allUpdates | Select-Object Product, KB, FileName, SizeMB, LastWriteTime, FilePath | Export-Csv -Path $inventoryPath -NoTypeInformation
    Write-Log "Inventory saved to: $inventoryPath" -Level Success
}

# ============================================================
# MAIN SCRIPT EXECUTION
# ============================================================

function Start-MainProcess {
    param(
        [string[]]$ProductList,
        [string]$TargetPath,
        [string]$MonthFolder
    )
    
    Write-Host "`n" -NoNewline
    Write-Host ("*" * 70) -ForegroundColor Cyan
    Write-Host "WINDOWS UPDATE DOWNLOAD SCRIPT" -ForegroundColor Cyan
    Write-Host ("*" * 70) -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd')" -ForegroundColor Yellow
    Write-Host "Month: $MonthFolder" -ForegroundColor Yellow
    Write-Host "Products: $($ProductList -join ', ')" -ForegroundColor Yellow
    Write-Host "Mode: $(if ($SkipDownload) {'Simulation'} else {'Download'})" -ForegroundColor Yellow
    Write-Host "Latest Only: $LatestOnly" -ForegroundColor Yellow
    Write-Host ("*" * 70) -ForegroundColor Cyan
    Write-Host "`n"
    
    # Show current inventory first
    Show-Inventory
    
    # Expand "All" to all products
    if ($ProductList -contains "All") {
        $ProductList = @("Windows10", "Windows11", "Server2019", "Server2022")
    }
    
    $allDownloadedFiles = @()
    $startTime = Get-Date
    
    foreach ($product in $ProductList) {
        if ($Script:ProductSearchTerms.ContainsKey($product)) {
            $files = Process-Product -Product $product `
                -TargetPath $TargetPath `
                -MonthFolder $MonthFolder
            $allDownloadedFiles += $files
        } else {
            Write-Log "Unknown product: $product" -Level Error
        }
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # Generate summary report
    Write-Log ""
    Write-Log ("=" * 60) -Level Info
    Write-Log "DOWNLOAD SUMMARY" -Level Info
    Write-Log ("=" * 60) -Level Info
    Write-Log "Script duration: $($duration.ToString('hh\:mm\:ss'))" -Level Info
    Write-Log "Total products processed: $($ProductList.Count)" -Level Info
    
    $newDownloads = $allDownloadedFiles | Where-Object { $_.FilePath -notmatch "SkipDownload mode" }
    
    if ($newDownloads.Count -gt 0) {
        Write-Log "New downloads: $($newDownloads.Count)" -Level Success
        Write-Log ""
        
        foreach ($download in $newDownloads) {
            Write-Log "  $($download.Product) - $($download.KB) - $($download.SizeMB) MB" -Level Success
        }
        
        # Save download report
        $reportPath = Join-Path $TargetPath "DownloadReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $allDownloadedFiles | Export-Csv -Path $reportPath -NoTypeInformation
        Write-Log ""
        Write-Log "Download report saved to: $reportPath" -Level Success
    } else {
        Write-Log "No new downloads" -Level Info
    }
    
    Write-Log ""
    Write-Log "Log file: $Script:LogPath" -Level Info
    
    return $allDownloadedFiles
}

# ============================================================
# SCHEDULED TASK CREATION
# ============================================================

function New-ScheduledDownloadTask {
    <#
    .SYNOPSIS
        Create a scheduled task for automatic downloads
    #>
    
    Write-Log "Creating scheduled task for automatic downloads..." -Level Info
    
    $taskName = "QB Energy - Windows Update Downloads"
    $taskDescription = "Automatically download latest Windows updates from Microsoft Update Catalog"
    
    $scriptPath = $PSCommandPath
    $powerShellPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    
    # Task action
    $action = New-ScheduledTaskAction -Execute $powerShellPath `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Products All -LatestOnly"
    
    # Task trigger - Run weekly on Wednesday at 2 AM (Patch Tuesday + 1 day)
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At 2am
    
    # Task principal (run as SYSTEM)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -WakeToRun `
        -MultipleInstances IgnoreNew
    
    try {
        # Check if task exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($existingTask) {
            Write-Log "Updating existing scheduled task..." -Level Warning
            Set-ScheduledTask -TaskName $taskName `
                -Action $action `
                -Trigger $trigger `
                -Principal $principal `
                -Settings $settings `
                -Description $taskDescription | Out-Null
        } else {
            Write-Log "Creating new scheduled task..." -Level Info
            Register-ScheduledTask -TaskName $taskName `
                -Description $taskDescription `
                -Action $action `
                -Trigger $trigger `
                -Principal $principal `
                -Settings $settings | Out-Null
        }
        
        Write-Log "Scheduled task configured successfully!" -Level Success
        Write-Log "Task Name: $taskName" -Level Info
        Write-Log "Schedule: Every Wednesday at 2:00 AM" -Level Info
        Write-Log "Task will download latest updates for all Windows products" -Level Info
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Failed to configure scheduled task: $errorMsg" -Level Error
    }
}

# ============================================================
# SCRIPT ENTRY POINT
# ============================================================

# Add required .NET assembly
Add-Type -AssemblyName System.Web

# Create main download directory
if (-not (Test-Path $DownloadPath)) {
    New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null
}

# Create scheduled task if requested
if ($ScheduledTask) {
    New-ScheduledDownloadTask
    exit 0
}

# Start the main process
$results = Start-MainProcess -ProductList $Products `
    -TargetPath $DownloadPath `
    -MonthFolder $Month

# Return results
return $results