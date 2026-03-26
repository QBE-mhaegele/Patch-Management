# Collect-PendingUpdates.ps1
# Gathers updates that are downloaded but not yet installed
# Updated approach for deployment-focused workflow

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeHidden = $false
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Collecting Pending Updates from $ComputerName" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$Result = @{
    ComputerName = $ComputerName
    CollectionTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Success = $false
    DownloadedUpdates = @()
    PendingReboot = $false
    ErrorMessage = $null
}

try {
    # Test connectivity
    if ($ComputerName -ne $env:COMPUTERNAME -and $ComputerName -ne "localhost") {
        Write-Host "Testing connectivity to $ComputerName..." -ForegroundColor Yellow
        
        if (-not (Test-Connection -ComputerName $ComputerName -Count 2 -Quiet)) {
            throw "Cannot reach $ComputerName"
        }
        
        Write-Host "✓ Connection successful" -ForegroundColor Green
    }
    
    # Create scriptblock for remote execution
    $ScriptBlock = {
        param($IncludeHidden)
        
        $Updates = @()
        $PendingReboot = $false
        
        try {
            # Create Windows Update COM object
            $UpdateSession = New-Object -ComObject Microsoft.Update.Session
            $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
            
            Write-Host "Searching for downloaded updates..." -ForegroundColor Yellow
            
            # Search for updates that are downloaded but not installed
            # IsInstalled=0 AND IsDownloaded=1
            $SearchCriteria = "IsInstalled=0 AND IsDownloaded=1"
            
            if (-not $IncludeHidden) {
                $SearchCriteria += " AND IsHidden=0"
            }
            
            $SearchResult = $UpdateSearcher.Search($SearchCriteria)
            
            Write-Host "Found $($SearchResult.Updates.Count) downloaded updates pending installation" -ForegroundColor Green
            
            # Process each update
            foreach ($Update in $SearchResult.Updates) {
                $KBNumber = "Unknown"
                
                # Extract KB number from title
                if ($Update.Title -match "KB(\d+)") {
                    $KBNumber = "KB$($Matches[1])"
                }
                
                $UpdateInfo = [PSCustomObject]@{
                    Title = $Update.Title
                    KBNumber = $KBNumber
                    Description = $Update.Description
                    IsDownloaded = $Update.IsDownloaded
                    IsInstalled = $Update.IsInstalled
                    IsMandatory = $Update.IsMandatory
                    RebootRequired = $Update.RebootRequired
                    SizeInMB = [math]::Round($Update.MaxDownloadSize / 1MB, 2)
                    Categories = ($Update.Categories | Select-Object -ExpandProperty Name) -join ", "
                    Severity = if ($Update.MsrcSeverity) { $Update.MsrcSeverity } else { "Unspecified" }
                }
                
                $Updates += $UpdateInfo
                
                if ($Update.RebootRequired) {
                    $PendingReboot = $true
                }
            }
            
            # Check for pending reboot from registry
            $RebootPending = $false
            
            # Check CBS RebootPending
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
                $RebootPending = $true
            }
            
            # Check Windows Update RebootRequired
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
                $RebootPending = $true
            }
            
            # Check PendingFileRenameOperations
            $PendingFileRename = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
            if ($PendingFileRename -and $PendingFileRename.PendingFileRenameOperations) {
                $RebootPending = $true
            }
            
            if ($RebootPending) {
                $PendingReboot = $true
            }
            
        } catch {
            throw "Error checking Windows Update: $_"
        }
        
        return @{
            Updates = $Updates
            PendingReboot = $PendingReboot
        }
    }
    
    # Execute scriptblock locally or remotely
    if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq "localhost") {
        Write-Host "Collecting from local machine..." -ForegroundColor Yellow
        $CollectionResult = & $ScriptBlock -IncludeHidden $IncludeHidden
    } else {
        Write-Host "Collecting from remote machine via WinRM..." -ForegroundColor Yellow
        $CollectionResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $IncludeHidden -ErrorAction Stop
    }
    
    # Process results
    $Result.DownloadedUpdates = $CollectionResult.Updates
    $Result.PendingReboot = $CollectionResult.PendingReboot
    $Result.Success = $true
    
    # Display summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Collection Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Computer:           $ComputerName" -ForegroundColor White
    Write-Host "Downloaded Updates: $($Result.DownloadedUpdates.Count)" -ForegroundColor White
    Write-Host "Pending Reboot:     $(if ($Result.PendingReboot) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($Result.PendingReboot) { 'Yellow' } else { 'Green' })
    
    if ($Result.DownloadedUpdates.Count -gt 0) {
        Write-Host "`nDownloaded Updates Pending Installation:" -ForegroundColor Yellow
        foreach ($Update in $Result.DownloadedUpdates) {
            Write-Host "  • $($Update.KBNumber) - $($Update.Title)" -ForegroundColor White
            Write-Host "    Size: $($Update.SizeInMB) MB | Severity: $($Update.Severity)" -ForegroundColor Gray
            if ($Update.RebootRequired) {
                Write-Host "    ⚠ Requires Reboot" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "`n✓ No pending updates (all downloaded updates are installed)" -ForegroundColor Green
    }
    
    Write-Host "`n========================================`n" -ForegroundColor Cyan
    
} catch {
    $Result.Success = $false
    $Result.ErrorMessage = $_.Exception.Message
    
    Write-Host "`n✗ Collection failed: $($Result.ErrorMessage)" -ForegroundColor Red
    Write-Host "" -ForegroundColor White
}

# Return result object
return $Result
