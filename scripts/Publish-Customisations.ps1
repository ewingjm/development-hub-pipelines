[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]
    $Url
)

if (!(Get-Module -ListAvailable -Name Microsoft.Xrm.Data.Powershell)) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Scope CurrentUser -Force -AllowClobber
}

Import-Module Microsoft.Xrm.Data.Powershell

# Publish request generally completes several minutes before the default ten minute timeout but only times out at ten minutes.
[Microsoft.Xrm.Tooling.Connector.CrmServiceClient]::MaxConnectionTimeout = [TimeSpan]::FromMinutes(2)

Write-Host "Authenticating as Development Hub app. Client ID: $env:DEVELOPMENTHUB_APPLICATION_CLIENTID."
$conn = Connect-CrmOnline `
    -ServerUrl $Url `
    -OAuthClientId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

if ($conn.LastCrmError) {
    throw $conn.LastCrmError
}

$publishRequest = [Microsoft.Crm.Sdk.Messages.PublishAllXmlRequest]::new()
try {
    Write-Host "Publishing"
    $conn.Execute($publishRequest) | Out-Null
}
catch {
    Write-Host "Publish request timed out. Polling for completion."
    # Timeouts are expected with PublishAllXml
    $res = Get-CrmRecords `
        -conn $conn `
        -EntityLogicalName msdyn_solutionhistory `
        -FilterAttribute msdyn_endtime -FilterOperator null `
        -TopCount 1

    if ($res.CrmRecords.Count -eq 0) {
        throw "Failed to publish."
    }

    $publish = $res.CrmRecords[0]

    do {
        Write-Host "Pausing for 30 seconds."
        Start-Sleep -Seconds 30
        Write-Host "Polling solution history. ID: $($publish.msdyn_solutionhistoryid)."
        $publish = Get-CrmRecord -conn $conn `
            -EntityLogicalName msdyn_solutionhistory `
            -Id $publish.msdyn_solutionhistoryid `
            -Fields msdyn_status, msdyn_exceptionmessage, msdyn_result
        $complete = $publish.msdyn_status_Property.Value.Value -eq 1
    } while ($complete -eq $false)

    if ($publish.msdyn_result_Property.Value -eq $false) {
        throw $publish.msdyn_exceptionmessage
    }

    Write-Host "Publish succeeded."
}