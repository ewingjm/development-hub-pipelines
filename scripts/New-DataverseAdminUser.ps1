
[CmdletBinding()] 
param(
    [string]
    [Parameter(Mandatory)]
    $EnvironmentUrl,
    [string]
    [Parameter(Mandatory)]
    $PrincipalObjectId
)

if (!(Get-Module -ListAvailable -Name Microsoft.PowerApps.Administration.PowerShell)) {
    Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force -AllowClobber
}

if (!(Get-Module -ListAvailable -Name Microsoft.Xrm.Data.Powershell)) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Scope CurrentUser -Force -AllowClobber
}

Write-Host "Authenticating as Development Hub app. Client ID: $env:DEVELOPMENTHUB_APPLICATION_CLIENTID | Tenant ID: $env:DEVELOPMENTHUB_APPLICATION_TENANTID."
Add-PowerAppsAccount `
    -TenantID $env:DEVELOPMENTHUB_APPLICATION_TENANTID `
    -ApplicationId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

Write-Host "Getting environment name for $EnvironmentUrl environment."
$environmentName = Get-AdminPowerAppEnvironment | 
Where-Object { $_.Internal.properties.linkedEnvironmentMetadata.instanceUrl -eq $EnvironmentUrl } |
Select-Object -ExpandProperty EnvironmentName

Write-Host "Syncing user with object ID $PrincipalObjectId to environment $environmentName."
Add-AdminPowerAppsSyncUser -EnvironmentName $environmentName -PrincipalObjectId $PrincipalObjectId | Out-Null

Write-Host "Assigning system administrator role."
$conn = Connect-CrmOnline `
    -ServerUrl $EnvironmentUrl `
    -OAuthClientId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

if ($conn.LastCrmError) {
    throw $conn.LastCrmError
}

$systemUser = (Get-CrmRecords -conn $conn -EntityLogicalName systemuser -FilterAttribute azureactivedirectoryobjectid -FilterOperator eq -FilterValue $PrincipalObjectId -TopCount 1).CrmRecords[0]
$systemAdmin = (Get-CrmRecords -conn $conn -EntityLogicalName role -FilterAttribute roletemplateid -FilterOperator eq -FilterValue "627090ff-40a3-4053-8790-584edc5be201" -TopCount 1).CrmRecords[0]

try {
Add-CrmSecurityRoleToUser -conn $conn -UserRecord $systemUser -SecurityRoleRecord $systemAdmin
}
catch {
    if ($_.Exception.Message -notlike "*duplicate key*") {
        throw
    }
}