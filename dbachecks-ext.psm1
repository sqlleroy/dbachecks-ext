#internal functions
foreach ($file in (Get-ChildItem "$PSScriptRoot\internal\functions")) {
    . $file.FullName
}

#public functions
foreach ($file in (Get-ChildItem "$PSScriptRoot\functions")) {
    . $file.FullName
}
# defining defaults
Set-PSFConfig -FullName dbapolicy.ExclusionsFilePath -Value "$PSScriptRoot\config\Exclusions\Exclusions.json"  -Initialize -Description "Exclusion file"