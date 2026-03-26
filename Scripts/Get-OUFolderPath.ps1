# OU Path Extraction Function
# Extracts a hierarchical folder path from Distinguished Name
# Combines multiple OU levels to create unique folder names

function Get-OUFolderPath {
    <#
    .SYNOPSIS
        Extracts OU hierarchy from DN to create unique folder path
    .DESCRIPTION
        Extracts the first 2 OUs from Distinguished Name and combines them
        to create unique folder paths like "Servers-Denver" or "Workstations-Denver"
    .PARAMETER DistinguishedName
        The full DN of the computer object
    .PARAMETER Depth
        Number of OU levels to extract (default: 2)
    .EXAMPLE
        Get-OUFolderPath -DistinguishedName "CN=SERVER01,OU=Servers,OU=Denver,OU=QBE,DC=domain,DC=com"
        Returns: "Servers-Denver"
    .EXAMPLE
        Get-OUFolderPath -DistinguishedName "CN=WK01,OU=Workstations,OU=Denver,OU=QBE,DC=domain,DC=com"
        Returns: "Workstations-Denver"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DistinguishedName,
        
        [Parameter(Mandatory=$false)]
        [int]$Depth = 2
    )
    
    # Extract all OUs from DN
    $OUMatches = [regex]::Matches($DistinguishedName, 'OU=([^,]+)')
    
    if ($OUMatches.Count -eq 0) {
        return "Unknown"
    }
    
    # Get the first N OUs (immediate parent and ancestors)
    $OULevels = @()
    for ($i = 0; $i -lt [Math]::Min($Depth, $OUMatches.Count); $i++) {
        $OULevels += $OUMatches[$i].Groups[1].Value
    }
    
    # Combine OUs with hyphen
    $FolderName = $OULevels -join '-'
    
    # Clean invalid characters for folder names
    $FolderName = $FolderName -replace '[\\/:*?"<>|]', '_'
    
    return $FolderName
}

# Example usage:
# DN: CN=DEN-SERVER-01,OU=Servers,OU=Denver,OU=QBE,DC=qb-energy,DC=com
# Result: "Servers-Denver"

# DN: CN=DEN-WK-01,OU=Workstations,OU=Denver,OU=QBE,DC=qb-energy,DC=com
# Result: "Workstations-Denver"

# DN: CN=PAR-SERVER-01,OU=Servers,OU=Parachute,OU=QBE,DC=qb-energy,DC=com
# Result: "Servers-Parachute"
