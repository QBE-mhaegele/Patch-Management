# ============================================================
# Generate-SimpleEnhancedReport.ps1
# Simplified version with just the requested features
# ============================================================

param(
    [string]$ResultsPath = "\\qbe-den-qnap\File4\Inventory\Results",
    [string]$AnalysisPath = "C:\PatchManagement\Analysis"
)

# Load data
$CurrentMonth = Get-Date -Format "yyyy-MMM"
$RiskScoresPath = Join-Path $AnalysisPath "RiskScores_$CurrentMonth.json"

if (-not (Test-Path $RiskScoresPath)) {
    Write-Error "Risk scores not found: $RiskScoresPath"
    return
}

$RiskData = Get-Content $RiskScoresPath -Raw | ConvertFrom-Json

# Create results directory if it doesn't exist
if (-not (Test-Path $ResultsPath)) {
    New-Item -Path $ResultsPath -ItemType Directory -Force | Out-Null
}

# Build enhanced HTML report
$ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ReportFileName = "RiskAnalysis_Enhanced_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$ReportPath = Join-Path $ResultsPath $ReportFileName

# Calculate statistics
$totalMachines = $RiskData.Count
$phase1 = ($RiskData | Where-Object { $_.DeploymentPhase -eq 1 }).Count
$phase2 = ($RiskData | Where-Object { $_.DeploymentPhase -eq 2 }).Count
$phase3 = ($RiskData | Where-Object { $_.DeploymentPhase -eq 3 }).Count
$phase4 = ($RiskData | Where-Object { $_.DeploymentPhase -eq 4 }).Count
$highRisk = ($RiskData | Where-Object { $_.RiskScore -ge 7 }).Count

# Generate HTML
$HTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>QB Energy Patch Management - Enhanced Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; }
        .header { background: #2980b9; color: white; padding: 20px; border-radius: 5px; }
        .stats { display: flex; gap: 15px; margin: 20px 0; flex-wrap: wrap; }
        .stat-box { 
            padding: 15px; 
            border-radius: 5px; 
            cursor: pointer;
            min-width: 150px;
            text-align: center;
            color: white;
            font-weight: bold;
        }
        .phase1 { background: #2ecc71; }
        .phase2 { background: #f39c12; }
        .phase3 { background: #e67e22; }
        .phase4 { background: #e74c3c; }
        .controls { margin: 20px 0; }
        .search-box { padding: 10px; width: 300px; }
        .export-btn { background: #9b59b6; color: white; border: none; padding: 10px 20px; cursor: pointer; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background: #34495e; color: white; padding: 10px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; cursor: pointer; }
        .details-panel { display: none; margin-top: 20px; padding: 20px; border: 1px solid #ddd; background: #f9f9f9; }
        .json-viewer { background: #2c3e50; color: white; padding: 15px; font-family: monospace; max-height: 300px; overflow: auto; }
        .cve-list { list-style: none; padding: 0; }
        .cve-item { padding: 10px; margin: 5px 0; background: white; border-left: 4px solid #3498db; }
        .kb-link { color: #e74c3c; text-decoration: underline; cursor: pointer; }
    </style>
</head>
<body>
    <div class="header">
        <h1>QB Energy Patch Management - Risk Analysis</h1>
        <p>Report Generated: $ReportDate | User: $env:USERNAME | Machines: $totalMachines</p>
    </div>
    
    <div class="controls">
        <input type="text" class="search-box" id="searchInput" placeholder="Search...">
        <button class="export-btn" onclick="exportCSV()">Export CSV</button>
    </div>
    
    <div class="stats">
        <div class="stat-box phase1" onclick="filterPhase(1)">Phase 1: $phase1</div>
        <div class="stat-box phase2" onclick="filterPhase(2)">Phase 2: $phase2</div>
        <div class="stat-box phase3" onclick="filterPhase(3)">Phase 3: $phase3</div>
        <div class="stat-box phase4" onclick="filterPhase(4)">Phase 4: $phase4</div>
        <div class="stat-box" style="background: #e74c3c;" onclick="filterHighRisk()">High Risk: $highRisk</div>
    </div>
    
    <table id="dataTable">
        <thead>
            <tr>
                <th>Computer</th>
                <th>User</th>
                <th>OU</th>
                <th>Risk Score</th>
                <th>Phase</th>
                <th>Missing Updates</th>
                <th>Problematic KBs</th>
            </tr>
        </thead>
        <tbody id="tableBody">
"@

# Add table rows
foreach ($machine in $RiskData) {
    $user = if ($machine.LastLoggedOnUser) { $machine.LastLoggedOnUser } else { "N/A" }
    $ou = if ($machine.OrganizationalUnit) { $machine.OrganizationalUnit } else { "N/A" }
    $missingUpdates = if ($machine.Factors.MissingUpdates) { $machine.Factors.MissingUpdates.Count } else { 0 }
    $problematicKBs = if ($machine.Factors.KBCompatibility.ProblematicKBs) { $machine.Factors.KBCompatibility.ProblematicKBs.Count } else { 0 }
    
    $machineJson = $machine | ConvertTo-Json -Compress
    $machineJsonEscaped = $machineJson -replace "'", "&apos;"
    
    $HTML += @"
            <tr data-machine='$machineJsonEscaped' onclick="showDetails(this)">
                <td>$($machine.ComputerName)</td>
                <td>$user</td>
                <td>$ou</td>
                <td>$($machine.RiskScore)</td>
                <td>$($machine.DeploymentPhase)</td>
                <td>$missingUpdates</td>
                <td>$problematicKBs</td>
            </tr>
"@
}

$HTML += @"
        </tbody>
    </table>
    
    <div class="details-panel" id="detailsPanel">
        <div style="display: flex; justify-content: space-between; align-items: center;">
            <h3 id="detailsTitle">Machine Details</h3>
            <button onclick="closeDetails()">Close</button>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 20px;">
            <div>
                <h4>JSON Data</h4>
                <div class="json-viewer" id="jsonViewer"></div>
            </div>
            <div>
                <h4>Missing Updates & Vulnerabilities</h4>
                <ul class="cve-list" id="cveList"></ul>
            </div>
        </div>
    </div>
    
    <script>
        // Search functionality
        document.getElementById('searchInput').addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            const rows = document.querySelectorAll('#tableBody tr');
            
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? '' : 'none';
            });
        });
        
        // Filter by phase
        function filterPhase(phase) {
            const rows = document.querySelectorAll('#tableBody tr');
            rows.forEach(row => {
                const phaseCell = row.cells[4];
                row.style.display = (phaseCell.textContent == phase) ? '' : 'none';
            });
        }
        
        // Filter high risk
        function filterHighRisk() {
            const rows = document.querySelectorAll('#tableBody tr');
            rows.forEach(row => {
                const riskCell = row.cells[3];
                row.style.display = (parseFloat(riskCell.textContent) >= 7) ? '' : 'none';
            });
        }
        
        // Show details
        function showDetails(row) {
            const machineData = JSON.parse(row.getAttribute('data-machine').replace(/&apos;/g, "'"));
            document.getElementById('detailsTitle').textContent = 'Details: ' + machineData.ComputerName;
            document.getElementById('jsonViewer').textContent = JSON.stringify(machineData, null, 2);
            
            // Show vulnerabilities
            const cveList = document.getElementById('cveList');
            cveList.innerHTML = '';
            
            // Missing updates
            if (machineData.Factors && machineData.Factors.MissingUpdates) {
                machineData.Factors.MissingUpdates.forEach(update => {
                    const li = document.createElement('li');
                    li.className = 'cve-item';
                    li.innerHTML = '<strong>Missing:</strong> ' + update;
                    cveList.appendChild(li);
                });
            }
            
            // Problematic KBs
            if (machineData.Factors && machineData.Factors.KBCompatibility && machineData.Factors.KBCompatibility.ProblematicKBs) {
                machineData.Factors.KBCompatibility.ProblematicKBs.forEach(kb => {
                    const li = document.createElement('li');
                    li.className = 'cve-item';
                    li.innerHTML = '<strong class="kb-link" onclick="alert(\'KB ' + kb.KB + ' details\\n\\nReason: ' + kb.Reason + '\\nRecommendation: ' + kb.Recommendation + '\')">' + kb.KB + '</strong> - ' + kb.Severity + '<br>' + kb.Reason;
                    cveList.appendChild(li);
                });
            }
            
            document.getElementById('detailsPanel').style.display = 'block';
        }
        
        // Close details
        function closeDetails() {
            document.getElementById('detailsPanel').style.display = 'none';
        }
        
        // Export CSV
        function exportCSV() {
            const rows = document.querySelectorAll('#tableBody tr:not([style*="display: none"])');
            const headers = ['ComputerName', 'User', 'OU', 'RiskScore', 'Phase', 'MissingUpdates', 'ProblematicKBs'];
            let csv = headers.join(',') + '\\n';
            
            rows.forEach(row => {
                const cells = row.cells;
                const rowData = [
                    '"' + cells[0].textContent + '"',
                    '"' + cells[1].textContent + '"',
                    '"' + cells[2].textContent + '"',
                    cells[3].textContent,
                    cells[4].textContent,
                    cells[5].textContent,
                    cells[6].textContent
                ];
                csv += rowData.join(',') + '\\n';
            });
            
            const blob = new Blob([csv], { type: 'text/csv' });
            const link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            link.download = 'patch_report_' + new Date().toISOString().slice(0,10) + '.csv';
            link.click();
        }
    </script>
</body>
</html>
"@

# Save HTML report
$HTML | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "Enhanced report generated: $ReportPath" -ForegroundColor Green

# Open the report
Start-Process $ReportPath