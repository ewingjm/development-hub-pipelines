[CmdletBinding()] 
param(
    [string]
    [Parameter(Mandatory = $true)]
    $DisplayName,
    [string]
    [Parameter(Mandatory = $true)]
    $DomainName,
    [string]
    [Parameter(Mandatory = $true)]
    $LocationName,
    [string]
    [Parameter(Mandatory = $true)]
    $CurrencyName,
    [int]
    [Parameter(Mandatory = $true)]
    $LanguageName,
    [string[]]
    [Parameter(Mandatory = $false)]
    $Templates,
    [string]
    [Parameter(Mandatory = $false)]
    $SecurityGroupId
)

if (!(Get-Module -ListAvailable -Name Microsoft.PowerApps.Administration.PowerShell)) {
    Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser -Force -AllowClobber
}

Write-Host "Authenticating as Development Hub app. Client ID: $env:DEVELOPMENTHUB_APPLICATION_CLIENTID | Tenant ID: $env:DEVELOPMENTHUB_APPLICATION_TENANTID."
Add-PowerAppsAccount `
    -TenantID $env:DEVELOPMENTHUB_APPLICATION_TENANTID `
    -ApplicationId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

Write-Host "Creating $DisplayName environment."

$Templates = if ($Templates) { $Templates } else { $null }
$SecurityGroupId = if ($SecurityGroupId) { $SecurityGroupId } else { $null }

$result = New-AdminPowerAppEnvironment `
    -DisplayName $DisplayName `
    -LocationName $LocationName `
    -EnvironmentSku Sandbox `
    -CurrencyName $CurrencyName `
    -LanguageName $LanguageName `
    -Templates $Templates `
    -DomainName $DomainName `
    -SecurityGroupId $SecurityGroupId `
    -ProvisionDatabase `
    -WaitUntilFinished $true

if ($result.Error) {
    throw $result.Error.message
}

$url = $result.Internal.properties.linkedEnvironmentMetadata.instanceUrl
Write-Host "Environment created at $url."

$environmentName = $result.EnvironmentName
Write-Host "##vso[task.setvariable variable=DevelopmentHub.ExtractEnvironment.Url;isoutput=true]$url"
Write-Host "##vso[task.setvariable variable=DevelopmentHub.ExtractEnvironment.Name;isoutput=true]$environmentName"

