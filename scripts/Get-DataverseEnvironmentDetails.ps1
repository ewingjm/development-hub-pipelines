param (
    [Parameter(Mandatory = $true)]
    [String]
    $EnvironmentName
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

Write-Host "Getting environment details. Environment name: $EnvironmentName."
$environment = Get-AdminPowerAppEnvironment $EnvironmentName

Write-Host "##vso[task.setvariable variable=DevelopmentHub.DevelopmentEnvironment.Location;]$($environment.Location)"
Write-Host "##vso[task.setvariable variable=DevelopmentHub.DevelopmentEnvironment.Language;]$($environment.Internal.properties.linkedEnvironmentMetadata.baseLanguage)"
Write-Host "##vso[task.setvariable variable=DevelopmentHub.DevelopmentEnvironment.SecurityGroupId;]$($environment.Internal.properties.linkedEnvironmentMetadata.securityGroupId)"

$conn = Connect-CrmOnline `
    -ServerUrl $environment.Internal.properties.linkedEnvironmentMetadata.instanceUrl `
    -OAuthClientId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

if ($conn.LastCrmError) {
    throw $conn.LastCrmError
}

$systemSettings = Get-CrmSystemSettings -conn $conn
$currencies = Get-CrmRecords -conn $conn `
    -EntityLogicalName transactioncurrency `
    -FilterAttribute currencyname `
    -FilterOperator eq `
    -FilterValue $systemSettings.BaseCurrencyId `
    -Fields isocurrencycode
$currency = $currencies.CrmRecords[0].isocurrencycode

Write-Host "##vso[task.setvariable variable=DevelopmentHub.DevelopmentEnvironment.Currency;]$currency"
