# Troubleshooting Guide
## QB Energy Patch Management System v3.0

---

## Quick Diagnostics

### System Health Check
```powershell
# Run this script to check system health
$Checks = @{
    "Scripts Path" = Test-Path "C:\PatchManagement\Scripts\PatchManagement-GUI.ps1"
    "Config Path" = Test-Path "C:\PatchManagement\Config"
    "Inventory Share" = Test-Path "\\qbe-den-qnap\File4\Inventory"
    "MSU Share" = Test-Path "\\QBE-DEN-WINUP1\Updatefiles"
    "ActiveDirectory Module" = Get-Module -ListAvailable ActiveDirectory
    "Graph Module" = Get-Module -ListAvailable Microsoft.Graph.Authentication
}

$Checks.GetEnumerator() | ForEach-Object {
    $Status = if ($_.Value) { "✓ OK" } else { "✗ FAIL" }
    Write-Host "$($_.Key): $Status"
}
```

---

## Common Issues by Tab

### Dashboard Tab

#### Issue: Collection Hangs on Specific Machine

**Symptoms**: Progress stops, showing same machine for minutes

**Cause**: Machine is partially responsive (responds to ping but WinRM hangs)

**Solution**:
1. Wait 2 minutes - automatic timeout will skip the machine
2. Note the machine name for investigation
3. Add to exclusion list if persistent:
   - Settings → Machine Exclusions → Add

**Prevention**:
```powershell
# Test machine before collection
Test-WSMan -ComputerName "PROBLEM-PC" -ErrorAction SilentlyContinue
```

---

#### Issue: "No inventory files found" During Analysis

**Symptoms**: Analysis completes instantly with no machines

**Causes**:
- Collection hasn't been run
- Wrong inventory path configured
- Network share inaccessible

**Solution**:
1. Verify inventory path in Settings
2. Check network share access:
   ```powershell
   Get-ChildItem "\\qbe-den-qnap\File4\Inventory" -Recurse -Filter "*.json" | Measure-Object
   ```
3. Run Collection first, then Analysis

---

#### Issue: Many Machines Show as Offline

**Symptoms**: 50%+ machines marked "Offline or unreachable"

**Causes**:
- WinRM not enabled on targets
- Firewall blocking WinRM
- Network connectivity issues
- DNS resolution problems

**Solution**:
```powershell
# Test sample of machines
$TestMachines = @("DEN-SERVER01", "DEN-PC001", "PAR-SRV01")
foreach ($PC in $TestMachines) {
    $Ping = Test-Connection $PC -Count 1 -Quiet
    $WinRM = Test-WSMan $PC -ErrorAction SilentlyContinue
    Write-Host "$PC - Ping: $Ping, WinRM: $($WinRM -ne $null)"
}
```

**Fix WinRM on targets**:
```powershell
# Run on target machine
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Restart-Service WinRM
```

---

#### Issue: Risk Scores Seem Incorrect

**Symptoms**: Machines show wrong risk level

**Causes**:
- Stale inventory data
- CVE data not updated
- Analysis using old data

**Solution**:
1. Re-run Collection for fresh data
2. Verify CVE data is current:
   ```powershell
   Get-ChildItem "C:\PatchManagement\Data\*-Parsed.json" |
       Select-Object Name, LastWriteTime
   ```
3. Re-run Analysis

---

#### Issue: SMB1 Flagged as Enabled on Servers Where It Is Disabled

**Symptoms**: Report shows "CRITICAL: SMB1 Protocol enabled" but the server has SMB1 disabled

**Cause**: The Windows Optional Feature state (`Installed`) is not the same as the protocol being enabled.
`Set-SmbServerConfiguration -EnableSMB1Protocol $false` disables the protocol but leaves the feature
package installed. The feature is only removed after running `Disable-WindowsOptionalFeature` and
rebooting. The old collection code read the feature state, not the protocol state.

**Fix applied 2026-03-25**: Both `Get-ClientInventory.ps1` and the embedded collection code in
`PatchManagement-GUI.ps1` now use `Get-SmbServerConfiguration` for the SMB1 check. If you see
this issue again, verify both scripts contain the `Get-SmbServerConfiguration` check and **restart
the GUI** before re-running Collection (the GUI loads script content at startup).

**Workaround if needed**:
```powershell
# Verify actual SMB1 protocol state on a server
Invoke-Command -ComputerName "SERVERNAME" -ScriptBlock {
    (Get-SmbServerConfiguration).EnableSMB1Protocol
}
```

---

#### Issue: Servers Showing Alerts for Known/Temporary Conditions

**Symptoms**: Servers generating false alerts (power outage, decommissioned, separate patch process)

**Solution**: Add the server to `Config\SuppressedServers.txt`. Servers listed there are excluded
from risk analysis and will not appear in the HTML report.

```
# Format: SERVERNAME   # optional comment
QBE-XTO-FILE      # XTO site offline - power outage
```

Remove the entry when the server returns to normal operation and re-run Analysis.

---

### KB Warnings Tab

#### Issue: Warnings Not Appearing in Reports

**Symptoms**: Added warnings but not in HTML report

**Cause**: Analysis ran before warnings were added

**Solution**:
1. Verify warning is saved (check KB-Warnings.json)
2. Re-run Analysis
3. View fresh report

---

### MSU Updates Tab

#### Issue: "Access Denied" When Deploying

**Symptoms**: Deployment fails with access denied

**Causes**:
- Account lacks admin rights on target
- WinRM not configured for delegation
- Firewall blocking

**Solution**:
1. Enable "Use Service Account"
2. Enter credentials with local admin rights
3. Test manually:
   ```powershell
   $Cred = Get-Credential
   Enter-PSSession -ComputerName "TARGET-SERVER" -Credential $Cred
   ```

---

#### Issue: "Update Not Applicable"

**Symptoms**: Exit code -2145124329 or 2359302

**Causes**:
- Wrong OS version for update
- Update already installed
- Prerequisites missing

**Solution**:
1. Verify update matches target OS
2. Check if already installed:
   ```powershell
   Invoke-Command -ComputerName "TARGET" -ScriptBlock {
       Get-HotFix | Where-Object { $_.HotFixID -like "*5073457*" }
   }
   ```

---

#### Issue: Phase Configuration Lost

**Symptoms**: Phases reset to empty after restart

**Cause**: Auto-save location not accessible

**Solution**:
1. Verify MSU folder exists:
   ```powershell
   Test-Path "\\qbe-den-qnap\File4\Inventory\MSU"
   ```
2. Create if missing:
   ```powershell
   New-Item "\\qbe-den-qnap\File4\Inventory\MSU" -ItemType Directory -Force
   ```
3. Click Save in Phased Deployment section

---

### Intune Tab

#### Issue: "Not connected to Intune" Despite Green Status

**Symptoms**: Functions fail even though status shows connected

**Cause**: Connection state variable not synchronized

**Solution**:
1. Click **Poll Devices** first (validates connection)
2. If still fails, click **Disconnect** then **Connect to Intune**
3. Re-authenticate when prompted

---

#### Issue: Connection Fails

**Symptoms**: Can't connect to Intune

**Diagnostic Steps**:
```powershell
# 1. Check modules installed
Get-Module -ListAvailable Microsoft.Graph*

# 2. Test manual connection
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"

# 3. Verify tenant ID
Get-MgContext
```

**Common Fixes**:
- Install missing modules
- Clear cached credentials: `Disconnect-MgGraph`
- Use correct Tenant ID (GUID format)

---

#### Issue: "No devices found"

**Symptoms**: Poll returns 0 devices

**Causes**:
- No devices enrolled in Intune
- Filter excluding all devices
- Permission issues

**Solution**:
1. Uncheck "Windows devices only" to see all
2. Verify in Azure Portal that devices exist
3. Check Graph API permissions

---

### Settings Tab

#### Issue: Settings Not Saving

**Symptoms**: Configuration resets after restart

**Causes**:
- Config folder permissions
- File locked by another process
- JSON corruption

**Solution**:
```powershell
# Check folder permissions
Get-Acl "C:\PatchManagement\Config"

# Check file isn't read-only
Get-ItemProperty "C:\PatchManagement\Config\PatchConfig.json"

# Reset if corrupted
Remove-Item "C:\PatchManagement\Config\PatchConfig.json"
# Restart GUI - will create fresh config
```

---

## Error Messages Reference

| Error | Cause | Solution |
|-------|-------|----------|
| "Cannot bind parameter 'ScriptBlock'" | PowerShell version issue | Use PowerShell 5.1+ |
| "Access is denied" | Permission issue | Use alternate credentials |
| "The WinRM client cannot process the request" | WinRM not enabled | Enable-PSRemoting on target |
| "Cannot find path" | Wrong path configured | Verify in Settings |
| "The term 'Get-MgDeviceManagementManagedDevice' is not recognized" | Missing module | Install Microsoft.Graph modules |
| "RPC server is unavailable" | Target offline or firewall | Check connectivity |
| "Type already exists" | Running twice in same session | Close and reopen PowerShell |

---

## Log File Analysis

### Finding Relevant Logs
```powershell
# Recent collection logs
Get-ChildItem "C:\PatchManagement\Logs\*Collection*.log" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5

# Search for errors
Select-String -Path "C:\PatchManagement\Logs\*.log" -Pattern "Error|Failed|Exception" |
    Select-Object -Last 20
```

### Understanding Log Entries
```
[14:30:45] Collecting from DEN-SERVER01...     ← Starting collection
[14:30:47] ✓ Success: Saved to Denver-Servers  ← Completed OK
[14:30:50] ⚠ Warning: Offline                   ← Machine unreachable
[14:31:05] ❌ Error: Access denied               ← Permission issue
[14:33:00] ⏱️ Timeout: Machine took too long    ← 2-minute timeout hit
```

---

## Performance Optimization

### Slow Collection
- Run during off-peak hours
- Increase timeout for slow networks
- Exclude problematic machines
- Use scheduled tasks for automation

### Slow Analysis
- Ensure SSD storage for local files
- Clean old inventory files (>30 days)
- Reduce number of OUs scanned

### GUI Responsiveness
- Close other applications
- Don't minimize during operations
- Monitor available memory

---

## Recovery Procedures

### Reset to Clean State
```powershell
# Backup first!
Copy-Item "C:\PatchManagement\Config\*" "C:\Backup\" -Recurse

# Clear configuration
Remove-Item "C:\PatchManagement\Config\*" -Force

# Clear logs (optional)
Remove-Item "C:\PatchManagement\Logs\*" -Force

# Restart GUI - will recreate defaults
```

### Restore from Backup
```powershell
# Copy backed up config
Copy-Item "C:\Backup\PatchConfig.json" "C:\PatchManagement\Config\"

# Restart GUI
```

---

## Getting Additional Help

### Information to Gather
Before contacting support, collect:

1. **Error message** (exact text)
2. **Log files** from the time of error
3. **Steps to reproduce**
4. **Screenshots** if GUI-related

### Log Collection Script
```powershell
# Create support bundle
$SupportDir = "C:\Temp\PatchMgmt-Support"
New-Item $SupportDir -ItemType Directory -Force

# Copy recent logs
Get-ChildItem "C:\PatchManagement\Logs\*" | 
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } |
    Copy-Item -Destination $SupportDir

# Copy config (sanitized)
Copy-Item "C:\PatchManagement\Config\PatchConfig.json" $SupportDir

# System info
Get-ComputerInfo | Out-File "$SupportDir\SystemInfo.txt"
Get-Module -ListAvailable | Out-File "$SupportDir\Modules.txt"

# Create ZIP
Compress-Archive -Path $SupportDir -DestinationPath "C:\Temp\PatchMgmt-Support.zip"
```

---

## Related Documentation

- [Dashboard Guide](01-Dashboard-Guide.md)
- [MSU Updates Guide](03-MSU-Updates-Guide.md)
- [Intune Guide](04-Intune-Guide.md)
- [Installation Guide](06-Installation-Guide.md)

---

**Document Version**: 3.1
**Last Updated**: March 2026
