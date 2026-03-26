# QB Energy Patch Management System
## Step-by-Step Installation Guide

---

## 📋 Prerequisites Checklist

Before beginning installation, ensure you have:

- [ ] Windows Server 2022 (or 2019) installed and updated
- [ ] Server joined to QB-ENERGY domain
- [ ] Administrator access to the server
- [ ] Network access to all target machines
- [ ] File share `\\QBE-DEN-FILE4\inventory` created and accessible
- [ ] Anthropic API key (get from https://console.anthropic.com)
- [ ] SMTP server details (optional, for email reports)

---

## 🔧 Installation Steps

### Step 1: Prepare the Server

```powershell
# Set PowerShell execution policy
Set-ExecutionPolicy RemoteSigned -Force

# Install required PowerShell modules
Install-Module -Name PSWindowsUpdate -Force -AllowClobber
Import-Module ActiveDirectory  # Should already be available on domain-joined server
```

### Step 2: Create Directory Structure

```powershell
# Create base directory
$BaseDir = "C:\PatchManagement"
New-Item -Path $BaseDir -ItemType Directory -Force

# Create subdirectories
$Subdirs = @(
    "Scripts",
    "MicrosoftData", 
    "Inventory",
    "Analysis",
    "Reports",
    "Logs",
    "Config"
)

foreach ($dir in $Subdirs) {
    New-Item -Path "$BaseDir\$dir" -ItemType Directory -Force
}

Write-Host "Directory structure created successfully!" -ForegroundColor Green
```

### Step 3: Copy Scripts

Copy the following files to `C:\PatchManagement\Scripts\`:

- Master-Orchestrator.ps1
- Get-MicrosoftPatches.ps1
- Get-ClientInventory.ps1
- Invoke-RiskAnalysis.ps1
- Deploy-Patches.ps1
- Setup-ScheduledTasks.ps1

```powershell
# Verify all scripts are in place
$RequiredScripts = @(
    "Master-Orchestrator.ps1",
    "Get-MicrosoftPatches.ps1",
    "Get-ClientInventory.ps1",
    "Invoke-RiskAnalysis.ps1",
    "Deploy-Patches.ps1",
    "Setup-ScheduledTasks.ps1"
)

$ScriptPath = "C:\PatchManagement\Scripts"
$MissingScripts = @()

foreach ($script in $RequiredScripts) {
    if (-not (Test-Path "$ScriptPath\$script")) {
        $MissingScripts += $script
    }
}

if ($MissingScripts.Count -eq 0) {
    Write-Host "✓ All scripts are in place" -ForegroundColor Green
} else {
    Write-Host "✗ Missing scripts:" -ForegroundColor Red
    $MissingScripts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}
```

### Step 4: Configure Anthropic API Key

**Option A: Environment Variable (Recommended)**

```powershell
# Set API key as user environment variable
[System.Environment]::SetEnvironmentVariable(
    'ANTHROPIC_API_KEY', 
    'your-api-key-here', 
    'User'
)

# Verify it was set
$env:ANTHROPIC_API_KEY
```

**Option B: Encrypted File (More Secure)**

```powershell
# Create encrypted API key file
$ApiKey = Read-Host "Enter your Anthropic API Key" -AsSecureString
$ApiKey | ConvertFrom-SecureString | Out-File "C:\PatchManagement\Config\api-key.enc"

Write-Host "API key encrypted and saved" -ForegroundColor Green
```

### Step 5: Configure File Share Permissions

On QBE-DEN-FILE4:

```powershell
# Run this on QBE-DEN-FILE4

# Find available drive
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Root -like '*:\'}

# Create share directory (adjust drive as needed)
$SharePath = "C:\Shares\inventory"  # Adjust drive letter
New-Item -Path $SharePath -ItemType Directory -Force

# Get domain name
$Domain = (Get-ADDomain).NetBIOSName

# Create SMB share
New-SmbShare -Name "inventory" `
    -Path $SharePath `
    -FullAccess "$Domain\Domain Admins" `
    -ChangeAccess "$Domain\Domain Computers" `
    -Description "QB Energy Patch Management Inventory Repository"

# Set NTFS permissions
$Acl = Get-Acl $SharePath
$Acl.SetAccessRuleProtection($true, $false)

$AdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "$Domain\Domain Admins",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)

$ComputerRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "$Domain\Domain Computers",
    "Modify",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)

$Acl.AddAccessRule($AdminRule)
$Acl.AddAccessRule($ComputerRule)
Set-Acl -Path $SharePath -AclObject $Acl

Write-Host "Share created: \\QBE-DEN-FILE4\inventory" -ForegroundColor Green
```

### Step 6: Test WinRM Connectivity

```powershell
# Test WinRM on a sample machine
$TestComputer = "QBE-DEN-TEST"  # Replace with actual computer name

# Test basic connectivity
Test-WSMan -ComputerName $TestComputer

# Test remote command execution
Invoke-Command -ComputerName $TestComputer -ScriptBlock { 
    Write-Host "WinRM is working!" 
}

# If it fails, enable WinRM on target machines:
# Run this on each client machine or via GPO:
# Enable-PSRemoting -Force
```

### Step 7: Test Individual Components

**Test 1: Microsoft Data Collection**

```powershell
cd C:\PatchManagement\Scripts

# Test Microsoft CVE collection
.\Get-MicrosoftPatches.ps1 -OutputPath "C:\PatchManagement\MicrosoftData"

# Verify output
Get-ChildItem "C:\PatchManagement\MicrosoftData"
# Should see: YYYY-MMM-Parsed.json, YYYY-MMM-CVESummary.csv, YYYY-MMM-Raw.json
```

**Test 2: Inventory Collection**

```powershell
# Test on local machine first
.\Get-ClientInventory.ps1 -CentralServer "\\QBE-DEN-FILE4\inventory" -IncludeInstalledSoftware

# Test remote execution on one machine
Invoke-Command -ComputerName "QBE-DEN-TEST" -FilePath .\Get-ClientInventory.ps1 -ArgumentList "\\QBE-DEN-FILE4\inventory"

# Verify inventory was saved
Get-ChildItem "\\QBE-DEN-FILE4\inventory"
```

**Test 3: Risk Analysis**

```powershell
# Load the function
. .\Invoke-RiskAnalysis.ps1

# Run analysis
Invoke-PatchRiskAnalysis `
    -PatchDataPath "C:\PatchManagement\MicrosoftData\2026-Jan-Parsed.json" `
    -InventoryPath "\\QBE-DEN-FILE4\inventory" `
    -OutputPath "C:\PatchManagement\Analysis"

# Check outputs
Get-ChildItem "C:\PatchManagement\Analysis"
# Should see: DeploymentPlan_*.json, RiskScores_*.json, RiskAnalysis_*.html
```

### Step 8: Full Workflow Test (Dry Run)

```powershell
cd C:\PatchManagement\Scripts

# Run complete workflow in test mode
.\Master-Orchestrator.ps1 -Phase All -DryRun

# Review the log
$LatestLog = Get-ChildItem "C:\PatchManagement\Logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $LatestLog.FullName

# Open the HTML report
$LatestReport = Get-ChildItem "C:\PatchManagement\Reports" -Filter "*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Invoke-Item $LatestReport.FullName
```

### Step 9: Set Up Scheduled Tasks

```powershell
cd C:\PatchManagement\Scripts

# Create automated tasks
.\Setup-ScheduledTasks.ps1

# Verify tasks were created
Get-ScheduledTask -TaskName "QB-PatchManagement-*"

# Test run the collection task
Start-ScheduledTask -TaskName "QB-PatchManagement-Collect"

# Monitor task progress
Get-ScheduledTask -TaskName "QB-PatchManagement-Collect" | Get-ScheduledTaskInfo
```

### Step 10: Configure Email Notifications (Optional)

Edit `Master-Orchestrator.ps1` to configure email settings:

```powershell
# Find this section in Master-Orchestrator.ps1 (around line 450)

# Email report if configured
if ($EmailRecipients) {
    try {
        Send-MailMessage `
            -To $EmailRecipients `
            -From "patchmanagement@qbenergy.com" `
            -Subject "QB Energy Patch Management Report - $(Get-Date -Format 'MMMM yyyy')" `
            -Body $ReportContent `
            -BodyAsHtml `
            -SmtpServer "smtp.qbenergy.com" `  # UPDATE THIS
            -Port 25 `                          # UPDATE THIS
            -ErrorAction Stop
        
        Write-Log "Report emailed to $EmailRecipients" "SUCCESS"
    } catch {
        Write-Log "Failed to email report: $_" "WARNING"
    }
}
```

---

## ✅ Post-Installation Checklist

After installation, verify:

- [ ] All scripts present in `C:\PatchManagement\Scripts\`
- [ ] Directory structure created successfully
- [ ] Anthropic API key configured and working
- [ ] File share `\\QBE-DEN-FILE4\inventory` accessible
- [ ] WinRM connectivity to target machines verified
- [ ] Microsoft data collection tested successfully
- [ ] Inventory collection tested on at least 2 machines
- [ ] Risk analysis completed successfully
- [ ] Full workflow dry run completed without errors
- [ ] Scheduled tasks created and visible in Task Scheduler
- [ ] Email notifications configured (optional)
- [ ] Team trained on reviewing deployment plans
- [ ] Documentation saved in accessible location

---

## 🎯 First Production Run

After successful testing:

1. **Wait for next Patch Tuesday** (2nd Tuesday of month)
2. **Wednesday morning**: Check that collection task ran
   ```powershell
   Get-ScheduledTaskInfo -TaskName "QB-PatchManagement-Collect"
   Get-ChildItem "C:\PatchManagement\MicrosoftData" | Sort-Object LastWriteTime -Descending
   ```
3. **Thursday morning**: Check that analysis task ran
   ```powershell
   Get-ScheduledTaskInfo -TaskName "QB-PatchManagement-Analyze"
   Invoke-Item "C:\PatchManagement\Analysis\RiskAnalysis_*.html"
   ```
4. **Thursday afternoon**: Review deployment plan with team
5. **Following week**: Begin phased deployment

---

## 🆘 Troubleshooting

### Issue: API key not found

```powershell
# Check if API key is set
$env:ANTHROPIC_API_KEY

# If empty, set it again
[System.Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'your-key', 'User')

# Restart PowerShell session
```

### Issue: Cannot access file share

```powershell
# Test file share access
Test-Path "\\QBE-DEN-FILE4\inventory"

# Check permissions
Get-SmbShare -Name "inventory" -CimSession QBE-DEN-FILE4
Get-SmbShareAccess -Name "inventory" -CimSession QBE-DEN-FILE4
```

### Issue: WinRM connection failures

```powershell
# On management server:
Test-WSMan -ComputerName TARGET-MACHINE

# If fails, on target machine run:
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Restart-Service WinRM
```

### Issue: Scheduled task not running

```powershell
# Check task history
Get-ScheduledTask -TaskName "QB-PatchManagement-Collect" | Get-ScheduledTaskInfo

# View task details
Export-ScheduledTask -TaskName "QB-PatchManagement-Collect"

# Check logs
Get-ChildItem "C:\PatchManagement\Logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

---

## 📞 Support Contacts

- **Internal IT Team:** it-team@qbenergy.com
- **Documentation Location:** `C:\PatchManagement\Docs\`
- **Log Location:** `C:\PatchManagement\Logs\`

---

**Installation completed by:** _______________  
**Date:** _______________  
**Verified by:** _______________  
**Date:** _______________

---

*QB Energy IT Infrastructure Team*  
*Automated Patch Management System v1.0*  
*January 2026*
