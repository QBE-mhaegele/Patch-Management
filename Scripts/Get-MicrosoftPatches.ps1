<#
.SYNOPSIS
    Collects Microsoft Security Updates and CVE data for analysis
.DESCRIPTION
    Pulls patch Tuesday data from Microsoft Security Response Center API
    Saves structured data for comparison against environment inventory
.NOTES
    Run this monthly after Patch Tuesday on a management server
    Requires internet access to api.msrc.microsoft.com
    Author: QB Energy IT Infrastructure Team
    Version: 1.0
    Date: January 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\PatchManagement\MicrosoftData",
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,12)]
    [int]$Month = (Get-Date).Month,
    
    [Parameter(Mandatory=$false)]
    [int]$Year = (Get-Date).Year,
    
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = $null  # Optional - increases rate limits
)

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Format month for API (e.g., "2025-Jan")
$monthName = (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($Month)
$updateId = "$Year-$monthName"

Write-Host "Collecting Microsoft Security Updates for $updateId..." -ForegroundColor Cyan

# Function to call MSRC API
function Get-MSRCUpdate {
    param(
        [string]$UpdateId,
        [string]$ApiKey
    )
    
    $baseUri = "https://api.msrc.microsoft.com/cvrf/v2.0/cvrf/$UpdateId"
    
    $headers = @{
        'Accept' = 'application/json'
    }
    
    if ($ApiKey) {
        $headers['api-key'] = $ApiKey
    }
    
    try {
        $response = Invoke-RestMethod -Uri $baseUri -Headers $headers -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        Write-Warning "Failed to retrieve data from MSRC API: $_"
        return $null
    }
}

# Get the security update data
$securityData = Get-MSRCUpdate -UpdateId $updateId -ApiKey $ApiKey

if ($securityData) {
    # Save raw JSON
    $jsonPath = Join-Path $OutputPath "$updateId-Raw.json"
    $securityData | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
    Write-Host "Saved raw data to: $jsonPath" -ForegroundColor Green
    
    # Parse and structure the data
    $parsedData = @{
        CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        UpdateId = $updateId
        Title = $securityData.DocumentTitle
        CVEs = @()
        KBArticles = @()
        AffectedProducts = @()
        KnownIssues = @()
    }
    
    # Extract CVE information
    if ($securityData.Vulnerability) {
        foreach ($vuln in $securityData.Vulnerability) {
            $cveInfo = @{
                CVE = $vuln.CVE
                Title = $vuln.Title.Value
                Severity = $vuln.CVSSScoreSets[0].BaseScore
                Vector = $vuln.CVSSScoreSets[0].Vector
                ProductIDs = $vuln.ProductStatuses | Where-Object {$_.Type -eq 'Known Affected'} | 
                            Select-Object -ExpandProperty ProductID
                Remediations = @()
            }
            
            # Extract KB articles for this CVE
            if ($vuln.Remediations) {
                foreach ($remediation in $vuln.Remediations) {
                    if ($remediation.Type -eq 'Vendor Fix' -and $remediation.Description) {
                        $kbMatch = [regex]::Match($remediation.Description.Value, 'KB\d+')
                        if ($kbMatch.Success) {
                            $cveInfo.Remediations += $kbMatch.Value
                        }
                    }
                }
            }
            
            $parsedData.CVEs += $cveInfo
        }
    }
    
    # Extract product information
    if ($securityData.ProductTree.FullProductName) {
        $parsedData.AffectedProducts = $securityData.ProductTree.FullProductName | 
            Select-Object -Property ProductID, Value
    }
    
    # Save parsed data
    $parsedPath = Join-Path $OutputPath "$updateId-Parsed.json"
    $parsedData | ConvertTo-Json -Depth 10 | Out-File $parsedPath -Encoding UTF8
    Write-Host "Saved parsed data to: $parsedPath" -ForegroundColor Green
    
    # Create CSV summary for easy viewing
    $csvData = $parsedData.CVEs | ForEach-Object {
        [PSCustomObject]@{
            CVE = $_.CVE
            Title = $_.Title
            Severity = $_.Severity
            KBArticles = ($_.Remediations -join '; ')
            AffectedProductCount = $_.ProductIDs.Count
        }
    }
    
    $csvPath = Join-Path $OutputPath "$updateId-CVESummary.csv"
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Saved CSV summary to: $csvPath" -ForegroundColor Green
    
    # Summary statistics
    Write-Host "`nCollection Summary:" -ForegroundColor Yellow
    Write-Host "  Total CVEs: $($parsedData.CVEs.Count)" -ForegroundColor White
    Write-Host "  Affected Products: $($parsedData.AffectedProducts.Count)" -ForegroundColor White
    Write-Host "  Unique KB Articles: $(($parsedData.CVEs.Remediations | Select-Object -Unique).Count)" -ForegroundColor White
    
} else {
    Write-Error "Failed to collect security data for $updateId"
}

Write-Host "`nMicrosoft data collection complete!" -ForegroundColor Green
Write-Host "Data saved to: $OutputPath" -ForegroundColor Cyan
