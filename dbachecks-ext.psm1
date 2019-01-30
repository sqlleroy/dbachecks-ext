#internal functions
# foreach ($file in (Get-ChildItem "$PSScriptRoot\internal\functions")) {
#     . $file.FullName
# }

#public functions
foreach ($file in (Get-ChildItem "$PSScriptRoot\functions")) {
    . $file.FullName
}
# --------------------------- #
# defining PSFConfig defaults #
# --------------------------- #
$ExclusionPath = "$PSScriptRoot\config\Exclusions\Exclusions.json" 
Set-PSFConfig -Module dbachecks-ext -Name exclusion.filepath                                -Value $ExclusionPath   -Initialize -Description "PSFConfig to define Exclusion json file path."
Set-PSFConfig -Module dbachecks-ext -Name "repair.sql agent account"                        -Value $true            -Initialize -Description "Repair Agent Account Services"
Set-PSFConfig -Module dbachecks-ext -Name "repair.valid job owner"                          -Value $true            -Initialize -Description "Repair Valid Job Owner"
Set-PSFConfig -Module dbachecks-ext -Name "repair.dba operators"                            -Value $true            -Initialize -Description "Repair DBA Operators"
Set-PSFConfig -Module dbachecks-ext -Name "repair.failsafe operator"                        -Value $true            -Initialize -Description "Repair Failsafe Operator"
Set-PSFConfig -Module dbachecks-ext -Name "repair.database mail profile"                    -Value $true            -Initialize -Description "Repair Database Mail Profile"
Set-PSFConfig -Module dbachecks-ext -Name "repair.database mail xps"                        -Value $true            -Initialize -Description "Repair Database Mail XPs"
Set-PSFConfig -Module dbachecks-ext -Name "repair.valid database owner"                     -Value $true            -Initialize -Description "Repair Valid Database Owner"
Set-PSFConfig -Module dbachecks-ext -Name "repair.recovery model"                           -Value $true            -Initialize -Description "Repair Recovery Model"
Set-PSFConfig -Module dbachecks-ext -Name "repair.page verify"                              -Value $true            -Initialize -Description "Repair Page Verify"
Set-PSFConfig -Module dbachecks-ext -Name "repair.auto close"                               -Value $true            -Initialize -Description "Repair Auto Close"
Set-PSFConfig -Module dbachecks-ext -Name "repair.auto shrink"                              -Value $true            -Initialize -Description "Repair Auto Shrink"
Set-PSFConfig -Module dbachecks-ext -Name "repair.auto create statistics"                   -Value $true            -Initialize -Description "Repair Auto Create Statistics"
Set-PSFConfig -Module dbachecks-ext -Name "repair.auto update statistics"                   -Value $true            -Initialize -Description "Repair Auto Update Statistics"
Set-PSFConfig -Module dbachecks-ext -Name "repair.auto update statistics asynchronously"    -Value $true            -Initialize -Description "Repair Auto Update Statistics Asynchronously"
Set-PSFConfig -Module dbachecks-ext -Name "repair.trustworthy option"                       -Value $true            -Initialize -Description "Repair Trustworthy Option"