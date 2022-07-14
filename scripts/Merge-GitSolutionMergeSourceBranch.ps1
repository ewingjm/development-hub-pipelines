[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $Source,
    [Parameter(Mandatory)]
    [String]
    $SolutionRoot,
    [Parameter(Mandatory)]
    [String]
    $MetadataRoot
)

Write-Host "Merging $Source into current branch (excluding extracted solution metadata)."

$output = git merge --strategy-option theirs --no-commit --squash $Source
if ($LASTEXITCODE -eq 1) {
    $output | Select-String -Pattern "CONFLICT \(rename\/delete\): .* of (src\/.*\/$MetadataRoot\/.*) left in tree" | ForEach-Object {
        git rm $_.Matches[0].Groups[1].Value
    }
}
git restore --staged "$SolutionRoot/*/$MetadataRoot/*"
git clean -df
git checkout -- .
