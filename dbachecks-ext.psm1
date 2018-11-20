#internal functions
# foreach ($file in (Get-ChildItem "$PSScriptRoot\internal\functions")) {
#     . $file.FullName
# }

#public functions
foreach ($file in (Get-ChildItem "$PSScriptRoot\functions")) {
    . $file.FullName
}
# defining defaults
Set-PSFConfig -Module dbachecks-ext -Name exclusion.filepath -Value "$PSScriptRoot\config\Exclusions\Exclusions.json"  -Initialize -Description "Exclusion file"


Set-PSFConfig -Module dbachecks-ext -Name "repair.sql agent account" -Value $true -Initialize -Description "Repair Agent Account Services"
Set-PSFConfig -Module dbachecks-ext -Name "repair.valid job owner" -Value $true -Initialize -Description "Repair Valid Job Owner"