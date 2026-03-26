# Get-InstalledUpdates.ps1
# Check what updates are installed on a computer

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [string]$KB = $null
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Get Installed Updates" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Computer: $ComputerName`n" -ForegroundColor White

# Test connectivity
if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
    Write-Host "ERROR: Cannot reach $ComputerName" -ForegroundColor Red
    return $null
}

Write-Host "Retrieving installed updates..." -ForegroundColor Yellow

try {
    if ($KB) {
        # Check specific KB
        $Updates = Get-HotFix -ComputerName $ComputerName -Id $KB -ErrorAction Stop
        
        if ($Updates) {
            Write-Host "  $KB is installed" -ForegroundColor Green
            Write-Host "  Installed: $($Updates.InstalledOn)" -ForegroundColor Gray
        } else {
            Write-Host "  $KB is NOT installed" -ForegroundColor Yellow
        }
        
    } else {
        # Get all updates
        $Updates = Get-HotFix -ComputerName $ComputerName -ErrorAction Stop | 
            Sort-Object InstalledOn -Descending
        
        Write-Host "  Found $($Updates.Count) installed updates`n" -ForegroundColor Green
        
        # Group by month
        $ByMonth = $Updates | Group-Object {$_.InstalledOn.ToString("yyyy-MM")} | 
            Sort-Object Name -Descending | Select-Object -First 3
        
        foreach ($Month in $ByMonth) {
            $MonthName = if ($Month.Name -match '\d{4}-\d{2}') { 
                [datetime]::ParseExact($Month.Name, "yyyy-MM", $null).ToString("MMMM yyyy")
            } else { 
                $Month.Name 
            }
            
            Write-Host "$MonthName ($($Month.Count) updates):" -ForegroundColor White
            foreach ($Update in $Month.Group | Select-Object -First 10) {
                Write-Host "  $($Update.HotFixID) - $($Update.Description)" -ForegroundColor Gray
                Write-Host "    Installed: $($Update.InstalledOn.ToString('yyyy-MM-dd'))" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
    
    Write-Host ""
    return $Updates
    
} catch {
    Write-Host "ERROR: Failed to retrieve updates - $_" -ForegroundColor Red
    return $null
}
