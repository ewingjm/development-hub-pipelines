[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]
    $Url,
    [Parameter(Mandatory = $true)]
    [String]
    $Source,
    [Parameter(Mandatory = $true)]
    [String]
    $Target,
    [Parameter(Mandatory = $true)]
    [String]
    $TargetDisplayName,
    [Parameter(Mandatory = $false)]
    [String]
    $TargetDescription
)

if (!(Get-Module -ListAvailable -Name Microsoft.Xrm.Data.Powershell)) {
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Scope CurrentUser -Force -AllowClobber
}

Write-Host "Authenticating as Development Hub app. Client ID: $env:DEVELOPMENTHUB_APPLICATION_CLIENTID."
$conn = Connect-CrmOnline `
    -ServerUrl $Url `
    -OAuthClientId $env:DEVELOPMENTHUB_APPLICATION_CLIENTID `
    -ClientSecret $env:DEVELOPMENTHUB_APPLICATION_CLIENTSECRET

if ($conn.LastCrmError) {
    throw $conn.LastCrmError
}

Write-Host "Getting source solution components from $Source"
$sourceSolutionResponse = Get-CrmRecords `
    -conn $conn `
    -EntityLogicalName solution `
    -Fields solutionid, publisherid `
    -FilterAttribute uniquename `
    -FilterOperator eq `
    -FilterValue $Source
$sourceSolution = $sourceSolutionResponse.CrmRecords[0]
$sourceSolutionComponents = Get-CrmRecords `
    -conn $conn `
    -EntityLogicalName solutioncomponent `
    -Fields objectid, componenttype, rootcomponentbehavior `
    -FilterAttribute solutionid `
    -FilterOperator eq `
    -FilterValue $sourceSolution.solutionid

Write-Host "Getting target solution components from $Target"
$targetSolutionResponse = Get-CrmRecords `
    -conn $conn `
    -EntityLogicalName solution `
    -Fields solutionid `
    -FilterAttribute uniquename `
    -FilterOperator eq `
    -FilterValue $Target
$targetSolution = $targetSolutionResponse.CrmRecords[0]

if (!$targetSolution) {
    Write-Host "Target solution $Target not found. Creating target solution."
    $solution = @{
        uniquename   = $Target
        friendlyname = $TargetDisplayName
        description  = $TargetDescription
        version      = "0.1.0"
        publisherid  = (New-CrmEntityReference -EntityLogicalName publisher -Id $sourceSolution.publisherid_Property.Value.Id)
    }
    $targetSolution = @{
        solutionid = (New-CrmRecord `
                -conn $conn `
                -EntityLogicalName solution `
                -Fields $solution
        ).Guid
    }
}

$targetSolutionComponents = Get-CrmRecords `
    -conn $conn `
    -EntityLogicalName solutioncomponent `
    -Fields objectid `
    -FilterAttribute solutionid `
    -FilterOperator eq `
    -FilterValue $targetSolution.solutionid

Write-Host "Determining new solution components"
$componentsToAdd = $sourceSolutionComponents.CrmRecords | Where-Object {
    $targetSolutionComponents.CrmRecords.objectid -notcontains $_.objectid 
}

$componentsToAdd | ForEach-Object {
    Write-Host "Adding solution component. Object ID: $($_.objectid) | Component type: $($_.componenttype)."
    $parameters = @{
        ComponentId                     = $_.objectid
        ComponentType                   = $_.original.componenttype_Property.Value.Value
        SolutionUniqueName              = $Target
        AddRequiredComponents           = $false
        DoNotIncludeSubcomponents       = $_.rootcomponentbehavior_Property.Value.Value -ne 0
        IncludedComponentSettingsValues = $(if ($_.rootcomponentbehavior_Property.Value.Value -eq 2) { @() } else { $null })
    }
    Invoke-CrmAction `
        -conn $conn `
        -Name AddSolutionComponent `
        -Parameters $parameters | Out-Null
}