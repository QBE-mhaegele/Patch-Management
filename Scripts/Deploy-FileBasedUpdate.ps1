# Deploy-FileBasedUpdate.ps1
# Deploy Windows updates using WUSA from file repository

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$true)]
    [string]$KB,
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryPath = "\\QBE-DEN-WINUP1\Updates$",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoReboot = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$RebootDelayMinutes = 5,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deploy File-Based Update" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Computer: $ComputerName" -ForegroundColor White
Write-Host "KB:       $KB" -ForegroundColor White
Write-Host "Repo:     $RepositoryPath`n" -ForegroundColor White

# Step 1: Test connectivity
Write-Host "[1/7] Testing connectivity..." -ForegroundColor Yellow

if (-not (Test-Connection -ComputerName $ComputerName -Count 2 -Quiet)) {
    Write-Host "  ERROR: Cannot reach $ComputerName" -ForegroundColor Red
    exit 1
}

Write-Host "  Connection successful" -ForegroundColor Green
Write-Host ""

# Step 2: Test WinRM
Write-Host "[2/7] Testing WinRM..." -ForegroundColor Yellow

try {
    $Session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
    Write-Host "  WinRM accessible" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: WinRM not accessible - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Find update file
Write-Host "[3/7] Locating update file..." -ForegroundColor Yellow

# Search for .msu file in repository
$SearchPaths = @(
    "$RepositoryPath\Windows10\x64\*\$KB.msu",
    "$RepositoryPath\Windows11\x64\*\$KB.msu",
    "$RepositoryPath\Server2019\*\$KB.msu",
    "$RepositoryPath\Server2022\*\$KB.msu"
)

$UpdateFile = $null

foreach ($Pattern in $SearchPaths) {
    $Found = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Found) {
        $UpdateFile = $Found.FullName
        break
    }
}

if (-not $UpdateFile) {
    Write-Host "  ERROR: Update file not found: $KB.msu" -ForegroundColor Red
    Write-Host "  Searched in: $RepositoryPath" -ForegroundColor Gray
    exit 1
}

Write-Host "  Found: $UpdateFile" -ForegroundColor Green

$FileSize = [math]::Round((Get-Item $UpdateFile).Length / 1MB, 2)
Write-Host "  Size:  $FileSize MB" -ForegroundColor Gray

Write-Host ""

# Step 4: Check if already installed
Write-Host "[4/7] Checking installation status..." -ForegroundColor Yellow

$CheckScript = {
    param($KBNumber)
    $KBNumber = $KBNumber.Replace("KB", "")
    $Installed = Get-HotFix | Where-Object { $_.HotFixID -eq "KB$KBNumber" }
    return $Installed
}

$AlreadyInstalled = Invoke-Command -Session $Session -ScriptBlock $CheckScript -ArgumentList $KB

if ($AlreadyInstalled -and -not $Force) {
    Write-Host "  Update already installed!" -ForegroundColor Yellow
    Write-Host "  Installed: $($AlreadyInstalled.InstalledOn)" -ForegroundColor Gray
    Write-Host "  Use -Force to reinstall`n" -ForegroundColor Gray
    
    Remove-PSSession $Session
    exit 0
}

if ($AlreadyInstalled) {
    Write-Host "  Update installed, but -Force specified" -ForegroundColor Yellow
} else {
    Write-Host "  Update not installed" -ForegroundColor Green
}

Write-Host ""

# Step 5: Copy update file to target
Write-Host "[5/7] Copying update to target..." -ForegroundColor Yellow

$RemoteTempPath = "C:\Windows\Temp\PatchManagement"
$RemoteUpdatePath = "$RemoteTempPath\$KB.msu"

try {
    # Create temp directory on remote
    Invoke-Command -Session $Session -ScriptBlock {
        param($Path)
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }
    } -ArgumentList $RemoteTempPath
    
    # Copy file
    Copy-Item -Path $UpdateFile -Destination $RemoteUpdatePath -ToSession $Session -Force
    
    Write-Host "  File copied successfully" -ForegroundColor Green
    
} catch {
    Write-Host "  ERROR: Failed to copy file - $_" -ForegroundColor Red
    Remove-PSSession $Session
    exit 1
}

Write-Host ""

# Step 6: Install update using WUSA
Write-Host "[6/7] Installing update..." -ForegroundColor Yellow
Write-Host "  This may take several minutes..." -ForegroundColor Gray

$InstallScript = {
    param($UpdatePath, $KB)
    
    $Result = @{
        Success = $false
        ExitCode = -1
        Output = ""
        Error = ""
        RebootRequired = $false
    }
    
    try {
        # Create log file path
        $LogPath = "C:\Windows\Temp\PatchManagement\$KB.log"
        
        # Build WUSA command
        $WUSA = "C:\Windows\System32\wusa.exe"
        $Arguments = "`"$UpdatePath`" /quiet /norestart /log:`"$LogPath`""
        
        Write-Host "    Command: wusa.exe $KB.msu /quiet /norestart" -ForegroundColor Gray
        
        # Start installation
        $Process = Start-Process -FilePath $WUSA -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        
        $Result.ExitCode = $Process.ExitCode
        
        # Check exit code
        # 0 = Success
        # 3010 = Success, reboot required
        # 2359302 = Already installed
        # Other = Error
        
        if ($Process.ExitCode -eq 0) {
            $Result.Success = $true
            $Result.Output = "Installation completed successfully"
        } elseif ($Process.ExitCode -eq 3010) {
            $Result.Success = $true
            $Result.RebootRequired = $true
            $Result.Output = "Installation completed successfully, reboot required"
        } elseif ($Process.ExitCode -eq 2359302) {
            $Result.Success = $true
            $Result.Output = "Update is already installed"
        } else {
            $Result.Success = $false
            $Result.Error = "Installation failed with exit code: $($Process.ExitCode)"
        }
        
        # Read log file if it exists
        if (Test-Path $LogPath) {
            $LogContent = Get-Content $LogPath -Tail 20 | Out-String
            $Result.Output += "`n`nLast 20 lines of log:`n$LogContent"
        }
        
    } catch {
        $Result.Success = $false
        $Result.Error = $_.Exception.Message
    }
    
    return $Result
}

try {
    $InstallResult = Invoke-Command -Session $Session -ScriptBlock $InstallScript -ArgumentList $RemoteUpdatePath, $KB
    
    Write-Host ""
    
    if ($InstallResult.Success) {
        Write-Host "  Installation successful!" -ForegroundColor Green
        Write-Host "  Exit Code: $($InstallResult.ExitCode)" -ForegroundColor Gray
        
        if ($InstallResult.RebootRequired) {
            Write-Host "  Reboot Required: YES" -ForegroundColor Yellow
        } else {
            Write-Host "  Reboot Required: NO" -ForegroundColor Green
        }
    } else {
        Write-Host "  Installation failed!" -ForegroundColor Red
        Write-Host "  Exit Code: $($InstallResult.ExitCode)" -ForegroundColor Gray
        Write-Host "  Error: $($InstallResult.Error)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "  ERROR: Installation failed - $_" -ForegroundColor Red
    Remove-PSSession $Session
    exit 1
}

Write-Host ""

# Step 7: Handle reboot
Write-Host "[7/7] Post-installation..." -ForegroundColor Yellow

if ($InstallResult.RebootRequired) {
    if ($AutoReboot) {
        Write-Host "  Scheduling reboot in $RebootDelayMinutes minutes..." -ForegroundColor Yellow
        
        Invoke-Command -Session $Session -ScriptBlock {
            param($Minutes)
            $Seconds = $Minutes * 60
            shutdown /r /t $Seconds /c "Reboot required after update installation"
        } -ArgumentList $RebootDelayMinutes
        
        Write-Host "  Reboot scheduled" -ForegroundColor Green
    } else {
        Write-Host "  Reboot required but not scheduled (use -AutoReboot)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No reboot required" -ForegroundColor Green
}

# Cleanup remote temp file
try {
    Invoke-Command -Session $Session -ScriptBlock {
        param($Path)
        if (Test-Path $Path) {
            Remove-Item $Path -Force -ErrorAction SilentlyContinue
        }
    } -ArgumentList $RemoteUpdatePath
    
    Write-Host "  Cleaned up temp files" -ForegroundColor Green
} catch {
    # Silent fail on cleanup
}

Write-Host ""

# Close session
Remove-PSSession $Session

# Log deployment
$LogEntry = [PSCustomObject]@{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName = $ComputerName
    KB = $KB
    Success = $InstallResult.Success
    ExitCode = $InstallResult.ExitCode
    RebootRequired = $InstallResult.RebootRequired
    AutoReboot = $AutoReboot
    DeployedBy = $env:USERNAME
}

$LogPath = "C:\PatchManagement\Logs\Deployment-$(Get-Date -Format 'yyyyMM').csv"
$LogDir = Split-Path $LogPath -Parent

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$LogEntry | Export-Csv -Path $LogPath -Append -NoTypeInformation

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Computer:        $ComputerName" -ForegroundColor White
Write-Host "Update:          $KB" -ForegroundColor White
Write-Host "Status:          $(if ($InstallResult.Success) { 'Success' } else { 'Failed' })" -ForegroundColor $(if ($InstallResult.Success) { "Green" } else { "Red" })
Write-Host "Exit Code:       $($InstallResult.ExitCode)" -ForegroundColor Gray
Write-Host "Reboot Required: $(if ($InstallResult.RebootRequired) { 'Yes' } else { 'No' })" -ForegroundColor $(if ($InstallResult.RebootRequired) { "Yellow" } else { "Green" })

if ($AutoReboot -and $InstallResult.RebootRequired) {
    Write-Host "Reboot Scheduled: Yes (in $RebootDelayMinutes minutes)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Log saved to: $LogPath" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================`n" -ForegroundColor Cyan

# Return result object
return $InstallResult
