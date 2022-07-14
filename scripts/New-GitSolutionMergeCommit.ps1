[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $SolutionMergeId,
    [Parameter(Mandatory)]
    [String]
    $SolutionMergeCreator,
    [Parameter(Mandatory)]
    [String]
    $SolutionMergeCreatorEmail,
    [Parameter(Mandatory)]
    [ValidateSet("Feature", "Bug")]
    [String]
    $IssueType,
    [Parameter(Mandatory)]
    [String]
    $IssueName,
    [Parameter()]
    [String]
    $IssueWorkItemId
)

$changes = git diff --cached 
if (!$changes) {
    Write-Host "No further changes detected."
    return;
}

$commitPrefix = switch ($IssueType) {
    Feature { "feat: " }
    Bug { "fix: " }
}
$commitText = $IssueName
$commitHeader = "$commitPrefix$commitText"

$commitTrailers = @"
Solution-merge-id: $SolutionMergeId
Solution-merge-creator: $SolutionMergeCreator <$SolutionMergeCreatorEmail>
"@

if ($IssueWorkItemId) {
    git commit -m $commitHeader -m "#$IssueWorkItemId" -m $commitTrailers
}
else {
    git commit -m $commitHeader -m $commitTrailers
}
