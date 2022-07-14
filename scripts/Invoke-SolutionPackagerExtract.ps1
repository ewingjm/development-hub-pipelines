[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $Solution,
    [Parameter(Mandatory)]
    [String]
    $TargetFolder,
    [Parameter(Mandatory)]
    [ValidateSet("Both", "Umanaged", "Managed")]
    [String]
    $Type,
    [Parameter()]
    [String]
    $MappingFileRoot
)

Write-Host "Installing Solution Packager."

$coreToolsPath = nuget install  Microsoft.CrmSdk.CoreTools -o (Join-Path $env:TEMP -ChildPath packages) | Where-Object { $_ -like "*Installing package *'Microsoft.CrmSdk.CoreTools' to '*'." } | Select-String -Pattern "to '(.*)'" | ForEach-Object { $_.Matches[0].Groups[1].Value } 
$solutionPackager = Get-ChildItem -Filter "SolutionPackager.exe" -Path $coreToolsPath -Recurse

Write-Host "Extracting $Solution as $($Type.ToLower()) with the Solution Packager to $TargetFolder."

if ($MappingFileRoot) {
    Write-Host "Searching for mapping file in $MappingFileRoot."
    $mappingFile = Get-ChildItem -Path $MappingFileRoot -Filter ExtractMappingFile.xml
    if (!$mappingFile) {
        $mappingFile = Get-ChildItem -Path $MappingFileRoot -Filter MappingFile.xml
    }
}

$solutionPackagerPath = $solutionPackager.FullName

if ($mappingFile) {
    Write-Host "Extracting with mapping file at $($mappingFile.FullName)."
    & $solutionPackagerPath /action:Extract /zipfile:$Solution /folder:$TargetFolder /map:$($mappingfile.FullName) /packagetype:$Type /allowWrite:Yes /allowDelete:Yes
}
else {
    Write-Host "Extracting without mapping file."
    & $solutionPackagerPath /action:Extract /zipfile:$Solution /folder:$TargetFolder /packagetype:$Type /allowWrite:Yes /allowDelete:Yes
}