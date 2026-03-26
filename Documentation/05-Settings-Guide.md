# Settings Tab Guide
## QB Energy Patch Management System v3.0

---

## Overview

The Settings tab allows you to configure system paths, credentials, exclusions, and other options that control how the Patch Management System operates.

---

## Interface Layout

```
┌─────────────────────────────────────────────────────────────┐
│ File Paths                                                   │
│   Inventory Share: \\QBE-DEN-FILE4\inventory    [Browse]    │
│   Scripts Path: C:\PatchManagement\Scripts      [Browse]    │
│   Analysis Output: C:\PatchManagement\Analysis  [Browse]    │
│   MSU Repository: \\QBE-DEN-WINUP1\Updatefiles [Browse]    │
├─────────────────────────────────────────────────────────────┤
│ Active Directory                                             │
│   Target OUs: [OU configuration list]                       │
│   [Add OU] [Remove OU] [Test Connection]                    │
├─────────────────────────────────────────────────────────────┤
│ Machine Exclusions                                           │
│   Excluded Machines: DEN-6G11R74-LT, DEN-LINUX01, ...      │
│   [Add Exclusion] [Remove] [Import] [Export]                │
├─────────────────────────────────────────────────────────────┤
│ [Save Settings] [Reset to Defaults] [View Logs]             │
└─────────────────────────────────────────────────────────────┘
```

---

## File Paths

### Inventory Share
**Default**: `\\QBE-DEN-FILE4\inventory`

Where inventory JSON files are stored. Structure:
```
\\QBE-DEN-FILE4\inventory\
├── Denver-Servers\
│   └── SERVER01_20260202-143022.json
├── Denver-Workstations\
│   └── DEN-PC001_20260202-143145.json
├── Paris-Servers\
│   └── PAR-SRV01_20260202-143301.json
└── MSU\
    └── DefaultPhases.json
```

### Scripts Path
**Default**: `C:\PatchManagement\Scripts`

Location of PowerShell scripts:
- PatchManagement-GUI.ps1
- Invoke-RiskAnalysis.ps1
- Get-MicrosoftPatches.ps1
- PatchConfig.psm1

### Analysis Output
**Default**: `C:\PatchManagement\Analysis`

Where HTML reports and analysis data are saved:
```
C:\PatchManagement\Analysis\
├── RiskAnalysis_20260202_141522.html
├── RiskAnalysis_20260202_141522.json
└── CurrentMonth-CVEs.json
```

### MSU Repository
**Default**: `\\QBE-DEN-WINUP1\Updatefiles`

Where standalone update files (.msu, .cab, .exe) are stored.

---

## Active Directory Configuration

### Target OUs

Configure which Organizational Units to scan for computers.

**Adding an OU**:
1. Click **Add OU**
2. Enter the distinguished name:
   ```
   OU=Workstations,OU=Denver,DC=qb-energy,DC=com
   ```
3. Click **OK**

**Common OUs for QB Energy**:
- `OU=Denver-Servers,OU=Denver,DC=qb-energy,DC=com`
- `OU=Denver-Workstations,OU=Denver,DC=qb-energy,DC=com`
- `OU=Paris-Servers,OU=Paris,DC=qb-energy,DC=com`
- `OU=Parachute-Servers,OU=Parachute,DC=qb-energy,DC=com`

### Test Connection

Click **Test Connection** to verify:
- AD connectivity
- OU accessibility
- Computer count in each OU

---

## Machine Exclusions

Exclude specific machines from inventory collection.

### Why Exclude Machines?

| Reason | Example |
|--------|---------|
| Linux/Unix systems | Machines with Windows names but running Linux |
| WinRM disabled | Machines that can't be queried remotely |
| Decommissioned | Old machines still in AD |
| Special handling | High-security systems with separate process |
| Templates | VM templates that shouldn't be inventoried |

### Adding Exclusions

**Single Machine**:
1. Click **Add Exclusion**
2. Enter computer name (e.g., `DEN-6G11R74-LT`)
3. Optionally add a reason
4. Click **OK**

**Import from File**:
1. Click **Import**
2. Select text file with one machine per line
3. Machines are added to exclusion list

### Managing Exclusions

- **Remove**: Select machine, click Remove
- **Export**: Save exclusion list to file for backup
- **Clear All**: Remove all exclusions (use with caution)

### Exclusion File Location
```
C:\PatchManagement\Config\ExcludedMachines.txt
```

Format:
```
DEN-6G11R74-LT    # Linux workstation
DEN-TEMPLATE01    # VM template
PAR-DECOM01       # Decommissioned
```

---

## Credential Management

### Service Account for MSU Deployment

Used when deploying updates to servers where your account lacks permissions.

1. Navigate to **MSU Updates** tab
2. Check **☑ Use Service Account**
3. Click **Set Credentials**
4. Enter domain\username and password

**Note**: Credentials are stored for the current session only.

### Intune Connection

See [Intune Guide](04-Intune-Guide.md) for Azure AD authentication setup.

---

## Configuration File

Settings are stored in:
```
C:\PatchManagement\Config\PatchConfig.json
```

**Sample Configuration**:
```json
{
  "InventoryShare": "\\\\QBE-DEN-FILE4\\inventory",
  "ScriptsPath": "C:\\PatchManagement\\Scripts",
  "AnalysisPath": "C:\\PatchManagement\\Analysis",
  "MSUPath": "\\\\QBE-DEN-WINUP1\\Updatefiles",
  "TargetOUs": [
    "OU=Denver-Servers,OU=Denver,DC=qb-energy,DC=com",
    "OU=Denver-Workstations,OU=Denver,DC=qb-energy,DC=com"
  ],
  "ExcludedMachines": [
    "DEN-6G11R74-LT",
    "DEN-TEMPLATE01"
  ],
  "IntuneTenantId": "41643dbd-bb87-47a6-a3b9-83642bbeba77",
  "IntuneTenantName": "QB ENERGY",
  "LastCollection": "2026-02-02T14:30:00",
  "LastAnalysis": "2026-02-02T15:15:00"
}
```

---

## Log Files

### Viewing Logs

Click **View Logs** to open the Logs folder:
```
C:\PatchManagement\Logs\
```

### Log Types

| File Pattern | Content |
|--------------|---------|
| `*_Collection.log` | Inventory collection output |
| `*_Analysis.log` | Risk analysis output |
| `MSU-Deployment-*.csv` | MSU deployment results |

### Log Retention

Logs are not automatically deleted. Periodically clean old logs:
```powershell
# Delete logs older than 90 days
Get-ChildItem C:\PatchManagement\Logs -Recurse | 
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } | 
  Remove-Item
```

---

## Saving and Resetting

### Save Settings

Click **Save Settings** to:
- Write configuration to PatchConfig.json
- Apply path changes immediately
- Update exclusion list

### Reset to Defaults

Click **Reset to Defaults** to restore:
- Default file paths
- Clear custom OUs (uses auto-discovery)
- Clear exclusion list

**Warning**: This cannot be undone!

---

## Best Practices

### Paths
- Use UNC paths for shares (enables access from any machine)
- Ensure service account has read/write to shares
- Test paths before saving

### OUs
- Only include OUs with computers to scan
- Exclude OUs with non-Windows systems
- Use specific OUs rather than entire domain

### Exclusions
- Document why each machine is excluded
- Review exclusion list quarterly
- Remove decommissioned machines from AD

### Backups
- Backup PatchConfig.json periodically
- Export exclusion list before changes
- Keep copy of phase deployment settings

---

## Troubleshooting

### "Path not accessible"
1. Verify network connectivity
2. Check share permissions
3. Test with `Test-Path "\\server\share"` in PowerShell

### "OU not found"
1. Verify distinguished name is correct
2. Check AD connectivity
3. Use `Get-ADOrganizationalUnit -Identity "OU=..."` to test

### Settings not saving
1. Check write permissions to Config folder
2. Verify PatchConfig.json is not read-only
3. Run GUI as Administrator

---

## Related Documentation

- [Installation Guide](06-Installation-Guide.md) - Initial setup
- [Troubleshooting](07-Troubleshooting.md) - Additional help

---

**Document Version**: 3.0  
**Last Updated**: February 2026
