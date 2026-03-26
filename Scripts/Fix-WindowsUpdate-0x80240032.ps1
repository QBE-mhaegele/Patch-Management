# Quick Fix for 0x80240032 - Copy/Paste This!
$Computer = "QBE-DEN-TSSH2"
$Cred = Get-Credential -Message "Admin credentials for $Computer"

Invoke-Command -ComputerName $Computer -Credential $Cred -ScriptBlock {
    
    Write-Host "`n=== FIXING WINDOWS UPDATE ===" -ForegroundColor Cyan
    
    # Stop service
    Write-Host "[1/4] Stopping Windows Update..." -ForegroundColor Yellow
    Stop-Service wuauserv -Force
    Start-Sleep -Seconds 2
    Write-Host "  Done" -ForegroundColor Green
    
    # Clear cache
    Write-Host "[2/4] Clearing cache..." -ForegroundColor Yellow
    Remove-Item "C:\Windows\SoftwareDistribution\DataStore\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Done" -ForegroundColor Green
    
    # Start service
    Write-Host "[3/4] Starting Windows Update..." -ForegroundColor Yellow
    Start-Service wuauserv
    Start-Sleep -Seconds 5
    Write-Host "  Done" -ForegroundColor Green
    
    # Test
    Write-Host "[4/4] Testing..." -ForegroundColor Yellow
    try {
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()
        $Result = $Searcher.Search("IsInstalled=0 AND IsDownloaded=1")
        Write-Host "  SUCCESS! Found $($Result.Updates.Count) updates" -ForegroundColor Green
        
        if ($Result.Updates.Count -gt 0) {
            Write-Host "`n  Ready to install:" -ForegroundColor White
            foreach ($U in $Result.Updates) {
                $KB = if ($U.Title -match "KB(\d+)") { "KB$($Matches[1])" } else { "?" }
                Write-Host "    - $KB" -ForegroundColor Cyan
            }
        }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  HResult: 0x$($_.Exception.HResult.ToString('X8'))" -ForegroundColor Red
    }
    
    Write-Host "`n=== FIX COMPLETE ===" -ForegroundColor Cyan
}