[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]
    $Url,
    [Parameter(Mandatory = $true)]
    [String]
    $SolutionMergeId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Merging", "AwaitingManualMerge", "AwaitingPRMerge", "Failed")]
    [String]
    $Status
)

if (!(Get-Module -ListAvailable -Name Microsoft.Xrm.Data.Powershell)) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Scope CurrentUser -Force -AllowClobber
}

Write-Host "Authenticating as Development Hub app. Client ID: $env:DEVELOPMENTHUB_APPLICATION_CLIENTID | Tenant ID: $env:DEVELOPMENTHUB_APPLICATION_TENANTID."
$conn = Connect-CrmOnline `
    -ServerUrl $Url `
    -OAuthClientId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

if ($conn.LastCrmError) {
    throw $conn.LastCrmError
}

$statusCode = switch ($Status) {
    Merging { 353400003 }
    AwaitingManualMerge { 353400006 }
    AwaitingPRMerge { 353400007 }
    Failed { 353400002 }
    Default { throw "Status not recognised." }
}
$stateCode = 0

Write-Host "Setting solution merge status. Solution merge: $SolutionMergeId | Status: $Status."

$solutionMerge = Get-CrmRecord `
    -conn $conn `
    -EntityLogicalName devhub_solutionmerge `
    -Id $SolutionMergeId `
    -Fields statecode, statuscode

if ($solutionMerge.statuscode_Property.Value.Value -eq $statusCode) {
    Write-Host "Solution merge was already at the desired status."
    return
}

Set-CrmRecordState `
    -conn $conn `
    -EntityLogicalName devhub_solutionmerge `
    -Id $SolutionMergeId `
    -StateCode $stateCode `
    -StatusCode $statusCode

