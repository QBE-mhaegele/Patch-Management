# Check-UpdateStatus.ps1
# Clean, user-friendly update status checker - NO CONFUSING ERRORS!

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "UPDATE STATUS CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: $ComputerName`n" -ForegroundColor Yellow

# Get credentials
$Cred = Get-Credential -Message "Enter admin credentials for $ComputerName"

# Status check script - NO ERRORS, JUST FACTS
$StatusScript = {
    $Result = @{
        Success = $true
        ServiceRunning = $false
        TotalUpdates = 0
        Downloaded = 0
        Downloading = 0
        UpdateList = @()
        Error = $null
    }
    
    try {
        # Check Windows Update service
        $Service = Get-Service wuauserv
        $Result.ServiceRunning = ($Service.Status -eq 'Running')
        
        # Get updates (simple, no complex criteria that cause errors)
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()
        
        # Just get all non-installed updates
        $Updates = $Searcher.Search("IsInstalled=0")
        $Result.TotalUpdates = $Updates.Updates.Count
        
        # Categorize each update
        foreach ($Update in $Updates.Updates) {
            $KB = "Unknown"
            if ($Update.Title -match "KB(\d+)") {
                $KB = "KB$($Matches[1])"
            }
            
            $SizeMB = [math]::Round($Update.MaxDownloadSize / 1MB, 2)
            $SizeGB = [math]::Round($Update.MaxDownloadSize / 1GB, 2)
            
            $UpdateInfo = [PSCustomObject]@{
                KB = $KB
                Title = $Update.Title
                SizeMB = $SizeMB
                SizeGB = $SizeGB
                IsDownloaded = $Update.IsDownloaded
                IsMandatory = $Update.IsMandatory
                RebootRequired = $Update.RebootRequired
            }
            
            $Result.UpdateList += $UpdateInfo
            
            if ($Update.IsDownloaded) {
                $Result.Downloaded++
            } else {
                $Result.Downloading++
            }
        }
        
    } catch {
        $Result.Success = $false
        $Result.Error = $_.Exception.Message
    }
    
    return $Result
}

Write-Host "Connecting to $ComputerName..." -ForegroundColor Yellow

try {
    $Status = Invoke-Command -ComputerName $ComputerName -ScriptBlock $StatusScript -Credential $Cred -ErrorAction Stop
    
    if (-not $Status.Success) {
        Write-Host "`n✗ ERROR" -ForegroundColor Red
        Write-Host "Could not check updates: $($Status.Error)" -ForegroundColor Red
        exit 1
    }
    
    # Display results - CLEAN, NO ERRORS
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "RESULTS" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # Service Status
    if ($Status.ServiceRunning) {
        Write-Host "Windows Update Service: " -NoNewline
        Write-Host "RUNNING ✓" -ForegroundColor Green
    } else {
        Write-Host "Windows Update Service: " -NoNewline
        Write-Host "STOPPED ✗" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Update Summary
    Write-Host "Total Updates Found: " -NoNewline
    Write-Host $Status.TotalUpdates -ForegroundColor Cyan
    
    Write-Host "  Downloaded (Ready): " -NoNewline
    if ($Status.Downloaded -gt 0) {
        Write-Host $Status.Downloaded -ForegroundColor Green
    } else {
        Write-Host $Status.Downloaded -ForegroundColor Gray
    }
    
    Write-Host "  Still Downloading: " -NoNewline
    if ($Status.Downloading -gt 0) {
        Write-Host $Status.Downloading -ForegroundColor Yellow
    } else {
        Write-Host $Status.Downloading -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Downloaded Updates (READY TO INSTALL)
    if ($Status.Downloaded -gt 0) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✓ READY TO INSTALL ($($Status.Downloaded))" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        
        foreach ($Update in $Status.UpdateList | Where-Object { $_.IsDownloaded }) {
            Write-Host ""
            Write-Host "  KB: " -NoNewline
            Write-Host $Update.KB -ForegroundColor Cyan
            
            Write-Host "  Size: " -NoNewline
            if ($Update.SizeGB -gt 1) {
                Write-Host "$($Update.SizeGB) GB" -ForegroundColor White
            } else {
                Write-Host "$($Update.SizeMB) MB" -ForegroundColor White
            }
            
            Write-Host "  Reboot Required: " -NoNewline
            if ($Update.RebootRequired) {
                Write-Host "Yes" -ForegroundColor Yellow
            } else {
                Write-Host "No" -ForegroundColor Gray
            }
            
            Write-Host "  Status: " -NoNewline
            Write-Host "READY ✓" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    # Downloading Updates (NOT READY)
    if ($Status.Downloading -gt 0) {
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "⧗ STILL DOWNLOADING ($($Status.Downloading))" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        
        foreach ($Update in $Status.UpdateList | Where-Object { -not $_.IsDownloaded }) {
            Write-Host ""
            Write-Host "  KB: " -NoNewline
            Write-Host $Update.KB -ForegroundColor Cyan
            
            Write-Host "  Size: " -NoNewline
            if ($Update.SizeGB -gt 1) {
                Write-Host "$($Update.SizeGB) GB" -ForegroundColor Yellow
            } else {
                Write-Host "$($Update.SizeMB) MB" -ForegroundColor White
            }
            
            Write-Host "  Status: " -NoNewline
            Write-Host "DOWNLOADING..." -ForegroundColor Yellow
            
            # Estimate time
            if ($Update.SizeGB -gt 20) {
                Write-Host "  Est. Time: " -NoNewline
                Write-Host "45-60 minutes" -ForegroundColor Yellow
            } elseif ($Update.SizeGB -gt 5) {
                Write-Host "  Est. Time: " -NoNewline
                Write-Host "15-30 minutes" -ForegroundColor Yellow
            } elseif ($Update.SizeMB -gt 500) {
                Write-Host "  Est. Time: " -NoNewline
                Write-Host "5-15 minutes" -ForegroundColor Yellow
            } else {
                Write-Host "  Est. Time: " -NoNewline
                Write-Host "1-5 minutes" -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }
    
    # No updates at all
    if ($Status.TotalUpdates -eq 0) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✓ NO UPDATES AVAILABLE" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "This machine is fully up to date!" -ForegroundColor Green
        Write-Host ""
    }
    
    # RECOMMENDATIONS
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RECOMMENDATIONS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Status.Downloaded -gt 0 -and $Status.Downloading -eq 0) {
        # All ready!
        Write-Host "✓ All updates are downloaded and ready!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor White
        Write-Host "  1. Go to GUI → Deployment tab" -ForegroundColor Gray
        Write-Host "  2. Enter computer name: $ComputerName" -ForegroundColor Gray
        Write-Host "  3. Click [Install Updates]" -ForegroundColor Gray
        Write-Host "  4. Done!" -ForegroundColor Gray
        
    } elseif ($Status.Downloading -gt 0 -and $Status.Downloaded -eq 0) {
        # Nothing ready yet
        Write-Host "⏳ Updates are still downloading..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor White
        Write-Host "  1. Wait for downloads to complete" -ForegroundColor Gray
        Write-Host "  2. Large updates (25GB) can take 45-60 minutes" -ForegroundColor Gray
        Write-Host "  3. Check status again in 30 minutes" -ForegroundColor Gray
        Write-Host "  4. When ready, use GUI to install" -ForegroundColor Gray
        
    } elseif ($Status.Downloading -gt 0 -and $Status.Downloaded -gt 0) {
        # Some ready, some not
        Write-Host "⚠ Mixed status: Some ready, some downloading" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor White
        Write-Host "  A) Install ready updates now ($($Status.Downloaded) updates)" -ForegroundColor Gray
        Write-Host "  B) Wait for all downloads, then install together" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Recommendation: Wait for all downloads (Option B)" -ForegroundColor Cyan
        
    } else {
        # No updates
        Write-Host "✓ No action needed" -ForegroundColor Green
        Write-Host ""
        Write-Host "Machine is fully patched!" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "`n✗ CONNECTION ERROR" -ForegroundColor Red
    Write-Host "Could not connect to $ComputerName" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
