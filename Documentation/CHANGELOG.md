# QB Energy Patch Management — Change Log

---

## v3.1 — March 25, 2026

### Bug Fixes

**SMB1 Detection False Positives**
- `Scripts\Get-ClientInventory.ps1` — Removed `SMB1Protocol` from the `$criticalFeatures` Windows Optional Feature check. Replaced with an explicit `Get-SmbServerConfiguration` call which reflects actual protocol state rather than feature install state.
- `Scripts\PatchManagement-GUI.ps1` — Applied the same fix to the embedded collection scriptblock (the GUI runs collection inline, not via `Get-ClientInventory.ps1`). This was the root cause of persistent false positives after the standalone script was fixed.

**Root cause:** `Set-SmbServerConfiguration -EnableSMB1Protocol $false` disables the SMB1 protocol but leaves the Windows Feature package installed. `Get-WindowsOptionalFeature` was returning `Installed` and the risk engine was flagging all servers. `Get-SmbServerConfiguration` correctly returns the actual enabled/disabled state.

---

### Configuration Changes

**Inventory Path Migration**
- `Config\settings.json` — `InventoryShare` updated from `\\QBE-DEN-FILE4\inventory` to `\\qbe-den-qnap\File4\Inventory`
- All 23 active scripts updated with the new path (FILE4 server migrated to QNAP)

**New: Suppressed Servers List**
- `Config\SuppressedServers.txt` — New config file. Servers listed here are excluded from risk analysis and the HTML report entirely. Use for known outages, decommissioned machines with stale inventory, or servers on separate patch processes.
- `Scripts\Invoke-RiskAnalysis.ps1` — Updated to load and apply `SuppressedServers.txt` before processing inventory files.
- Initial entries: `QBE-XTO-FILE`, `QBE-XTO-GENTEC1`, `QBE-XTO-PRINT` (XTO site power outage — remove when site returns)

---

### Scoring Changes

**Antivirus Detection Disabled**
- `Scripts\Invoke-RiskAnalysis.ps1` — AV check commented out (was +10 points, "CRITICAL: No antivirus detected"). QB Energy servers use network-level AV protection. Host-based AV is not required and was generating noise across the entire server fleet.

---

### HTML Report Enhancements

**Column Sorting**
- `Scripts\Invoke-RiskAnalysis.ps1` — Main machine table now supports clickable column sort for:
  - Computer Name (A→Z / Z→A)
  - Operating System (A→Z / Z→A)
  - Platform (A→Z / Z→A)
  - Score (high→low / low→high, defaults to high→low)
- Active sort column shows ▲/▼ indicator
- Sort persists through filter and search operations
- Row `data-score` attribute added to support JavaScript sort

---

## v3.0 — February 2026

- Initial production release
- Dashboard, KB Warnings, MSU Updates, Intune, Settings tabs
- AI-powered risk analysis via Anthropic Claude API
- Phased deployment planning (Phase 1–4)
- OU-based inventory collection
- HTML risk report with filtering and machine detail panel
