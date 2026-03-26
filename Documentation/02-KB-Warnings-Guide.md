# KB Warnings Tab Guide
## QB Energy Patch Management System v3.0

---

## Overview

The KB Warnings tab helps you track problematic Windows updates that may cause issues with specific hardware or software configurations in your environment.

---

## What Are KB Warnings?

KB Warnings identify specific Windows updates (KBs) that:
- Have known issues reported by Microsoft
- May cause problems with certain hardware (Intel RST, specific TPM versions)
- Have compatibility issues with software in your environment
- Require special handling before deployment

---

## Interface Layout

```
┌─────────────────────────────────────────────────────────────┐
│ KB Warnings Database                                         │
├─────────────────────────────────────────────────────────────┤
│ [Add Warning] [Remove] [Export] [Import] [Refresh from MS]  │
├─────────────────────────────────────────────────────────────┤
│ KB Number │ Severity │ Affected │ Description │ Date Added  │
│ KB5034441 │ High     │ BitLock  │ Recovery... │ 2026-01-15 │
│ KB5021233 │ Medium   │ Intel RST│ Storage...  │ 2026-01-10 │
│ KB5020030 │ Low      │ .NET 3.5 │ Install...  │ 2025-12-20 │
├─────────────────────────────────────────────────────────────┤
│ Affected Machines: 45 machines have Intel RST controllers   │
│                    12 machines have affected TPM versions   │
└─────────────────────────────────────────────────────────────┘
```

---

## Automatic Detection

The risk analysis automatically flags machines that may be affected by KB warnings based on:

### Hardware Detection
| Hardware | Risk | Common Issues |
|----------|------|---------------|
| Intel RST VMD Controllers | Storage driver conflicts | Boot failures, BSOD |
| Specific TPM versions | Firmware updates | BitLocker recovery |
| Older BIOS versions | Compatibility | Update failures |

### Software Detection
| Software | Risk | Common Issues |
|----------|------|---------------|
| .NET Framework 3.5 | Installation conflicts | App failures |
| Older Office versions | Compatibility | Feature loss |
| VPN clients | Driver conflicts | Connectivity |

---

## Managing KB Warnings

### Adding a Warning

1. Click **Add Warning**
2. Fill in the details:
   - **KB Number**: e.g., KB5034441
   - **Severity**: Critical, High, Medium, Low
   - **Affected Component**: What hardware/software is affected
   - **Description**: What the issue is
   - **Workaround**: How to resolve (if known)
   - **Microsoft URL**: Link to KB article or known issue

3. Click **Save**

### Removing a Warning

1. Select the warning in the list
2. Click **Remove**
3. Confirm deletion

### Exporting Warnings

Click **Export** to save warnings to CSV for:
- Documentation
- Sharing with other teams
- Backup before changes

### Importing Warnings

Click **Import** to load warnings from:
- Previous export files
- Shared warning databases
- Microsoft known issues list

---

## Integration with Analysis

When you run Analysis, KB Warnings are automatically:

1. **Cross-referenced** against machine inventory
2. **Flagged** in the HTML report
3. **Added to risk score** calculation
4. **Displayed** in machine detail view

### HTML Report Display

Machines with KB warning matches show:
```
⚠️ KB WARNINGS FOR THIS MACHINE:
┌────────────────────────────────────────────────────────┐
│ KB5034441 - BitLocker Recovery Issue                   │
│ Severity: HIGH                                          │
│ This machine has BitLocker enabled and may trigger     │
│ recovery mode after installing this update.            │
│ Workaround: Suspend BitLocker before update            │
└────────────────────────────────────────────────────────┘
```

---

## Common KB Warnings

### Storage/Boot Issues
| KB | Issue | Affected |
|----|-------|----------|
| KB5034441 | WinRE update fails | BitLocker systems |
| KB5021233 | Intel RST driver conflict | Intel RAID systems |
| KB5015882 | Boot failure | Specific Dell models |

### Application Issues
| KB | Issue | Affected |
|----|-------|----------|
| KB5020030 | .NET 3.5 install fails | Legacy apps |
| KB5019275 | Print spooler crash | Print servers |
| KB5018410 | Kerberos auth issues | Domain controllers |

### Security Feature Issues
| KB | Issue | Affected |
|----|-------|----------|
| KB5012170 | Secure Boot DBX | Older UEFI systems |
| KB5016616 | TPM attestation | TPM 1.2 devices |

---

## Best Practices

### Before Patch Tuesday
1. Check Microsoft's known issues page
2. Add any new warnings to the database
3. Run Analysis to identify affected machines

### After Patch Tuesday
1. Monitor for new reported issues
2. Update warnings as Microsoft publishes fixes
3. Remove warnings when issues are resolved

### For Critical Updates
1. Always test on pilot machines first
2. Document any workarounds needed
3. Have rollback plan ready

---

## Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| **Critical** | Can cause data loss or system unbootable | Do not deploy without workaround |
| **High** | Significant functionality impact | Test thoroughly before deployment |
| **Medium** | Limited impact, workaround available | Deploy with caution |
| **Low** | Minor issues, informational | Deploy normally, monitor |

---

## Data Storage

KB Warnings are stored in:
```
C:\PatchManagement\Data\KB-Warnings.json
```

**Backup this file regularly!**

Format:
```json
{
  "Warnings": [
    {
      "KB": "KB5034441",
      "Severity": "High",
      "AffectedComponent": "BitLocker",
      "Description": "May trigger BitLocker recovery",
      "Workaround": "Suspend BitLocker before installing",
      "MicrosoftURL": "https://support.microsoft.com/...",
      "DateAdded": "2026-01-15",
      "AddedBy": "mhaegele.admin"
    }
  ]
}
```

---

## Troubleshooting

### Warnings Not Showing in Report
1. Verify warnings are saved in database
2. Re-run Analysis after adding warnings
3. Check machine inventory has relevant hardware data

### Too Many False Positives
1. Refine the affected component criteria
2. Add version-specific matching
3. Update warning with more specific conditions

### Missing Hardware Detection
1. Verify collection captured hardware details
2. Check inventory JSON has TPM/controller data
3. Some virtual machines may not report all hardware

---

## Related Documentation

- [Dashboard Guide](01-Dashboard-Guide.md) - Running analysis
- [Troubleshooting](07-Troubleshooting.md) - Additional help

---

**Document Version**: 3.0  
**Last Updated**: February 2026
