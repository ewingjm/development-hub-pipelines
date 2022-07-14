[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]
    $Url,
    [Parameter(Mandatory = $true)]
    [String]
    $EnvironmentId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Provisioning", "FailedToProvision", "Ready", "Deleted")]
    [String]
    $Status,
    [Parameter(Mandatory = $false)]
    [String]
    $EnvironmentCommitHash,
    [Parameter(Mandatory = $false)]
    [String]
    $EnvironmentUrl
)

if ($Status -eq "Ready" -and !$EnvironmentCommitHash -and !$EnvironmentUrl) {
    throw "You must provide a value for the EnvironmentCommitHash and EnvironmentUrl parameters to update environment status to ready."
}

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
    Provisioning { 353400001 }
    FailedToProvision { 353400002 }
    Ready { 1 }
    Deleted { 2 }
    Default { throw "Status not recognised." }
}
$stateCode = switch ($statusCode) {
    353400001 { 0 }
    353400002 { 0 }
    1 { 0 }
    2 { 1 }
}

if ($Status -eq "Ready") {
    Invoke-CrmAction `
        -conn $conn `
        -Name devhub_MarkAsPrepared `
        -Target (New-CrmEntityReference -EntityLogicalName devhub_environment -Id $EnvironmentId) `
        -Parameters @{ CommitHash = $EnvironmentCommitHash; Url = $EnvironmentUrl }
}
else {
    Write-Host "Setting environment status. Environment: $EnvironmentId | Status: $Status."

    $environment = Get-CrmRecord `
        -conn $conn `
        -EntityLogicalName devhub_environment `
        -Id $EnvironmentId `
        -Fields statecode, statuscode

    if ($environment.statuscode_Property.Value.Value -eq $statusCode -and $Status -ne "Ready") {
        Write-Host "Environment was already at the desired status."
        return
    }

    Set-CrmRecordState `
        -conn $conn `
        -EntityLogicalName devhub_environment `
        -Id $EnvironmentId `
        -StateCode $stateCode `
        -StatusCode $statusCode
}
