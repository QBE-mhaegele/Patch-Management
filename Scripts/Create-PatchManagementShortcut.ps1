# Create Desktop Shortcut for Patch Management GUI
# Creates shortcut using hidden PowerShell launcher
# Safe for RDS and Group Policy environments

param(
    [string]$ShortcutLocation = "$env:Public\Desktop",
    [string]$ShortcutName = "Patch Management.lnk",
    [string]$InstallPath = "C:\PatchManagement\Scripts"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Patch Management Shortcut Creator" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify launcher script exists
$LauncherScript = Join-Path $InstallPath "Launch-PatchManagementGUI-Hidden.ps1"

if (-not (Test-Path $LauncherScript)) {
    Write-Host "❌ Error: Launcher script not found" -ForegroundColor Red
    Write-Host "   Expected: $LauncherScript" -ForegroundColor Yellow
    Write-Host "`nPlease ensure Launch-PatchManagementGUI-Hidden.ps1 is in:" -ForegroundColor Yellow
    Write-Host "   $InstallPath`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found launcher script" -ForegroundColor Green
Write-Host "  Location: $LauncherScript`n" -ForegroundColor Gray

# Create shortcut
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $ShortcutPath = Join-Path $ShortcutLocation $ShortcutName
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    
    # PowerShell executable
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    
    # Arguments for hidden window
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$LauncherScript`""
    
    # Working directory
    $Shortcut.WorkingDirectory = $InstallPath
    
    # Description
    $Shortcut.Description = "QB Energy Patch Management System"
    
    # Run minimized (additional layer)
    $Shortcut.WindowStyle = 7  # 7 = Minimized
    
    # Icon (use PowerShell icon or custom if available)
    $IconPath = Join-Path $InstallPath "..\Config\icon.ico"
    if (Test-Path $IconPath) {
        $Shortcut.IconLocation = "$IconPath,0"
        Write-Host "✓ Using custom icon" -ForegroundColor Green
    } else {
        $Shortcut.IconLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,0"
        Write-Host "⚠ Custom icon not found, using PowerShell icon" -ForegroundColor Yellow
    }
    
    # Save shortcut
    $Shortcut.Save()
    
    Write-Host "`n✓ Shortcut created successfully!" -ForegroundColor Green
    Write-Host "  Location: $ShortcutPath`n" -ForegroundColor Gray
    
    # Display shortcut details
    Write-Host "Shortcut Details:" -ForegroundColor Cyan
    Write-Host "  Target:    powershell.exe" -ForegroundColor White
    Write-Host "  Arguments: -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$LauncherScript`"" -ForegroundColor White
    Write-Host "  WorkDir:   $InstallPath" -ForegroundColor White
    Write-Host "  Style:     Hidden (no console window)" -ForegroundColor White
    
    Write-Host "`n✓ Ready to use!" -ForegroundColor Green
    Write-Host "  Users can double-click the shortcut to launch" -ForegroundColor Gray
    Write-Host "  No console window will appear`n" -ForegroundColor Gray
    
} catch {
    Write-Host "`n❌ Error creating shortcut: $_" -ForegroundColor Red
    exit 1
}

# Offer to create additional shortcuts
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Additional Deployment Options" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$CreateMore = Read-Host "Create shortcut for All Users Start Menu? (Y/N)"
if ($CreateMore -eq 'Y' -or $CreateMore -eq 'y') {
    try {
        $StartMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        $StartMenuShortcut = Join-Path $StartMenuPath "Patch Management.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut2 = $WshShell.CreateShortcut($StartMenuShortcut)
        $Shortcut2.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
        $Shortcut2.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$LauncherScript`""
        $Shortcut2.WorkingDirectory = $InstallPath
        $Shortcut2.Description = "QB Energy Patch Management System"
        $Shortcut2.WindowStyle = 7
        
        if (Test-Path $IconPath) {
            $Shortcut2.IconLocation = "$IconPath,0"
        } else {
            $Shortcut2.IconLocation = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,0"
        }
        
        $Shortcut2.Save()
        
        Write-Host "`n✓ Start Menu shortcut created!" -ForegroundColor Green
        Write-Host "  Location: $StartMenuShortcut`n" -ForegroundColor Gray
        
    } catch {
        Write-Host "`n⚠ Could not create Start Menu shortcut: $_" -ForegroundColor Yellow
        Write-Host "  (May require administrator privileges)`n" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan