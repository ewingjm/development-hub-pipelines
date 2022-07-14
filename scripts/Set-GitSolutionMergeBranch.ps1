[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet("Feature", "Bug")]
    [String]
    $IssueType,
    [Parameter(Mandatory)]
    [String]
    $IssueName,
    [Parameter(Mandatory)]
    [String]
    $SourceFolder,
    [Parameter()]
    [String]
    $CommitHash,
    [Parameter()]
    [String]
    $TargetBranch
)

Write-Host "Calculating branch name."
$path = switch ($IssueType) {
    Feature { "devhub/feature/" }
    Bug { "devhub/bugfix/" }
}
$name = $IssueName.ToLower().Replace(' ', '-') -replace "[^a-zA-Z0-9\s-]"
$branch = "$path$name"

Write-Host "Checking if $branch exists based on commit $CommitHash."
$useExistingBranch = $false
$branchExists = $null -ne (git rev-parse --verify --quiet "origin/$branch")
if ($branchExists) {
    Write-Host "Branch exists."
    
    if (!$CommitHash) {
        $useExistingBranch = $true
    }
    else {
        Write-Host "Checking existing branch is based on extract environments commit ($CommitHash)."
        $mergeBase = git merge-base HEAD "origin/$branch"

        Write-Host "Merge base with origin/$branch is $mergeBase."
        if ($CommitHash.Substring(0, 7) -eq $mergeBase.Substring(0, 7)) {
            $useExistingBranch = $true
        }
        else {
            Write-Host "Merge base does not match environment commit. Checking for solution changes."
            $filesChanged = (git diff $mergeBase $CommitHash --name-only)
            $solutionFilesChanges = $filesChanged | Where-Object {
                return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_).StartsWith(
                    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceFolder))
            }

            if (!$solutionFilesChanges) {
                Write-Host "Merged commits do not contain solution changes. Safe to extract into current merge base."
                $useExistingBranch = $true
            }
            else {
                Write-Host "Merged commits contain solution changes. Extracting may lead to reverted changes."
            }
        }
    }
}

if ($useExistingBranch) {
    Write-Host "Using existing branch."
    git checkout $branch
}
else {
    if ($branchExists) {
        Write-Host "Existing branch mismatch with extract environment. Deleting existing branch."
        git push origin --delete $branch
    }

    if ($CommitHash) {
        Write-Host "Creating new branch from commit $CommitHash."
        git checkout -b $branch $CommitHash
    }
    else {
        Write-Host "Creating new branch from branch $TargetBranch."
        git checkout -b $branch "origin/$TargetBranch"
    }
}

Write-Host "##vso[task.setvariable variable=DevelopmentHub.SolutionMerge.BranchName]$branch"
Write-Host "##vso[task.setvariable variable=branchName;isoutput=true]$branch"