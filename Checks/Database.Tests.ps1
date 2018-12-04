$filename = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

[array]$ExcludedDatabases = Get-DbcConfigValue command.invokedbccheck.excludedatabases
$ExcludedDatabases += $ExcludeDatabase
[string[]]$NotContactable = (Get-PSFConfig -Module dbachecks -Name global.notcontactable).Value

@(Get-Instance).ForEach{
    if ($NotContactable -notcontains $psitem) {
        $Instance = $psitem
        try {  
            $connectioncheck = Connect-DbaInstance  -SqlInstance $Instance -ErrorAction SilentlyContinue -ErrorVariable errorvar
        }
        catch {
            $NotContactable += $Instance
        }
        if ($NotContactable -notcontains $psitem) {
            if ($null -eq $connectioncheck.version) {
                $NotContactable += $Instance
            }
            else {

            }
        }
    }

    Set-PSFConfig -Module dbachecks -Name global.notcontactable -Value $NotContactable 
    Describe "Valid Database Owner" -Tags ValidDatabaseOwner, $filename {
        [string[]]$exclude = Get-DbcConfigValue policy.validdbowner.excludedb
        $exclude += $ExcludedDatabases 
        if ($NotContactable -contains $psitem) {
            Context "Testing Database Owners on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Database Owners on $psitem" {
                # PSFConfig with the desired value (can be an array)
                [string[]]$targetowner = Get-DbcConfigValue policy.validdbowner.name
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                [string]$TargetValue = Get-DbcRepairValue dbachecks.policy.validdbowner.name -ArrayPosition 0
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.SetOwner($RepairValue,$true)
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.Owner -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.Owner | Should -BeIn $ReferenceValue -Because "The account that is the database owner is not what was expected"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database}else {$_.Name -notin $exclude}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name, Owner -RepairValue $TargetValue -ReferenceValue $targetowner
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- # 
                    It @TestCases "Database <Name> - owner <Owner> should be in this list ( $( [String]::Join(", ", $targetowner) ) ) on $($_.Parent.Name)"
                }                
            }
        }
    }
    Describe "Recovery Model" -Tags RecoveryModel, DISA, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Recovery Model on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Recovery Model on $psitem" {
                $exclude = Get-DbcConfigValue policy.recoverymodel.excludedb
                $exclude += $ExcludedDatabases 
                # PSFConfig with the desired value
                $recoverymodel = Get-DbcConfigValue policy.recoverymodel.type
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                [string]$TargetValue = Get-DbcRepairValue dbachecks.policy.recoverymodel.type
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.RecoveryModel = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.RecoveryModel -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.RecoveryModel | Should -Be $ReferenceValue -Because "You expect this recovery model"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$_.Name -notin $exclude}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $recoverymodel
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- # 
                    It @TestCases "<Name> should be set to $recoverymodel on $_" 
                }
            }
        }
    }
    Describe "Page Verify" -Tags PageVerify, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing page verify on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing page verify on $psitem" {
                # PSFConfig with the desired value
                $pageverify = Get-DbcConfigValue policy.pageverify
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                [string]$TargetValue = Get-DbcRepairValue dbachecks.policy.pageverify
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.PageVerify = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.PageVerify -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.PageVerify | Should -Be $ReferenceValue -Because "Page verify helps SQL Server to detect corruption"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $pageverify
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "<Name> on $_ should have page verify set to $pageverify"
                }
            }
        }
    }
    Describe "Auto Close" -Tags AutoClose, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Auto Close on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Auto Close on $psitem" {
                 # PSFConfig with the desired value
                 $autoclose = Get-DbcConfigValue policy.database.autoclose
                 # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                 $TargetValue = Get-DbcRepairValue dbachecks.policy.database.autoclose
                 # Treating the boolean variable when it is set as a string from the source
                 if ($TargetValue -is [string]) {
                    $TargetValue = [bool]::Parse($TargetValue)
                 }
                 # --------------------------------------- #
                 # Change the setting to the desired value #
                 # Passed on: Get-DbcTestCase funtion      #
                 # Used on: Repair-DbcCheck function       #
                 # --------------------------------------- #
                 $RepairBlock = {
                     # Change the setting with desired value from the $RepairValue
                     $_.AutoClose = $RepairValue
                     try {
                         # Effectively changing the setting with $RepairValue
                         $_.Alter()
                     }
                     catch {
                         # Return $false to the Repair-DbcCheck function when failing to change the setting
                         return $false
                     }
                     # Forcing the setting to reflect the recent change
                     $_.Refresh()
                     # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                     return $_.AutoClose -eq $RepairValue
                 }
                 # ------------------------------------------------ #
                 # Define the Pester check validation for a setting #
                 # Passed on: Get-DbcTestCase funtion               #
                 # ------------------------------------------------ #
                 $CheckBlock = {
                     $_.AutoClose | Should -Be $ReferenceValue -Because "Because!"
                 }
                 # ----------------------------------------------- #
                 # Current state of a setting to be tested/checked #
                 # ----------------------------------------------- #
                 If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                     # --------------------------------------------------------------------- #
                     # Function Get-DbcTestCase formatting the expected output for TestCases #
                     # --------------------------------------------------------------------- #
                     $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $autoclose
                     # ---------------------- #
                     # Pester check execution #
                     # ---------------------- #
                     It @TestCases "<Name> on $_ should have Auto Close set to $autoclose"
                }
            }
        }
    }
    Describe "Auto Shrink" -Tags AutoShrink, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Auto Shrink on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Auto Shrink on $psitem" {
                # PSFConfig with the desired value
                $autoshrink = Get-DbcConfigValue policy.database.autoshrink
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                $TargetValue = Get-DbcRepairValue dbachecks.policy.database.autoshrink
                # Treating the boolean variable when it is set as a string from the source
                if ($TargetValue -is [string]) {
                   $TargetValue = [bool]::Parse($TargetValue)
                }
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoShrink = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.AutoShrink -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.AutoShrink | Should -Be $ReferenceValue -Because "Shrinking databases causes fragmentation and performance issues"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $autoshrink
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "<Name> on $_ should have Auto Shrink set to $autoshrink"
                }
            }
        }
    }
    Describe "Auto Create Statistics" -Tags AutoCreateStatistics, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Auto Create Statistics on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Auto Create Statistics on $psitem" {
                # PSFConfig with the desired value
                $autocreatestatistics = Get-DbcConfigValue policy.database.autocreatestatistics
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                $TargetValue = Get-DbcRepairValue dbachecks.policy.database.autocreatestatistics
                # Treating the boolean variable when it is set as a string from the source
                if ($TargetValue -is [string]) {
                   $TargetValue = [bool]::Parse($TargetValue)
                }
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoCreateStatisticsEnabled = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.AutoCreateStatisticsEnabled -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.AutoCreateStatisticsEnabled | Should -Be $ReferenceValue -Because "This is value expected for autocreate statistics"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $autocreatestatistics
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "<Name> on $_ should have Auto Create Statistics set to $autocreatestatistics"
                }
            }
        }
    }
    Describe "Auto Update Statistics" -Tags AutoUpdateStatistics, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Auto Update Statistics on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Auto Update Statistics on $psitem" {
                # PSFConfig with the desired value
                $autoupdatestatistics = Get-DbcConfigValue policy.database.autoupdatestatistics
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                $TargetValue = Get-DbcRepairValue dbachecks.policy.database.autoupdatestatistics
                # Treating the boolean variable when it is set as a string from the source
                if ($TargetValue -is [string]) {
                   $TargetValue = [bool]::Parse($TargetValue)
                }
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoUpdateStatisticsEnabled = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.AutoUpdateStatisticsEnabled -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.AutoUpdateStatisticsEnabled | Should -Be $ReferenceValue -Because "This is value expected for autoupdate statistics"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $autoupdatestatistics
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "<Name> on $_ should have Auto Update Statistics set to $autoupdatestatistics"
                }
            }
        }
    }
    Describe "Auto Update Statistics Asynchronously" -Tags AutoUpdateStatisticsAsynchronously, $filename {
        $autoupdatestatisticsasynchronously = Get-DbcConfigValue policy.database.autoupdatestatisticsasynchronously
        if ($NotContactable -contains $psitem) {
            Context "Testing Auto Update Statistics Asynchronously on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Auto Update Statistics Asynchronously on $psitem" {
                # PSFConfig with the desired value
                $autoupdatestatisticsasynchronously = Get-DbcConfigValue policy.database.autoupdatestatisticsasynchronously
                # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                $TargetValue = Get-DbcRepairValue dbachecks.policy.database.autoupdatestatisticsasynchronously
                # Treating the boolean variable when it is set as a string from the source
                if ($TargetValue -is [string]) {
                   $TargetValue = [bool]::Parse($TargetValue)
                }
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoUpdateStatisticsAsync = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.AutoUpdateStatisticsAsync -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.AutoUpdateStatisticsAsync | Should -Be $ReferenceValue -Because "This is value expeceted for autoupdate statistics asynchronously"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $autoupdatestatisticsasynchronously
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "<Name> on $_ should have Auto Update Statistics Asynchronously set to $autoupdatestatisticsasynchronously"
                }
            }
        }
    }
    # **** ????
    Describe "Trustworthy Option" -Tags Trustworthy, DISA, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing database trustworthy option on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing database trustworthy option on $psitem" {
                $TargetValue = $False                
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.Trustworthy = $RepairValue
                    try {
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                    }
                    catch {
                        # Return $false to the Repair-DbcCheck function when failing to change the setting
                        return $false
                    }
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                    return $_.Trustworthy -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $CheckBlock = {
                    $_.Trustworthy | Should -Be $ReferenceValue -Because "Trustworthy has security implications and may expose your SQL Server to additional risk"
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = ($connectioncheck.Databases.Where{if ($database) {$_.Name -in $database} else {$ExcludedDatabases -notcontains $_.Name}})) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $False
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "Trustworthy on <Name> is set to false on $_"
                }
            }
        }
    }    
}

Set-PSFConfig -Module dbachecks -Name global.notcontactable -Value $NotContactable 

# SIG # Begin signature block
# MIINEAYJKoZIhvcNAQcCoIINATCCDP0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUzAcnLvtegnn5mJG15lbVsce1
# 5hSgggpSMIIFGjCCBAKgAwIBAgIQAsF1KHTVwoQxhSrYoGRpyjANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE3MDUwOTAwMDAwMFoXDTIwMDUx
# MzEyMDAwMFowVzELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMQ8wDQYD
# VQQHEwZWaWVubmExETAPBgNVBAoTCGRiYXRvb2xzMREwDwYDVQQDEwhkYmF0b29s
# czCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAI8ng7JxnekL0AO4qQgt
# Kr6p3q3SNOPh+SUZH+SyY8EA2I3wR7BMoT7rnZNolTwGjUXn7bRC6vISWg16N202
# 1RBWdTGW2rVPBVLF4HA46jle4hcpEVquXdj3yGYa99ko1w2FOWzLjKvtLqj4tzOh
# K7wa/Gbmv0Si/FU6oOmctzYMI0QXtEG7lR1HsJT5kywwmgcjyuiN28iBIhT6man0
# Ib6xKDv40PblKq5c9AFVldXUGVeBJbLhcEAA1nSPSLGdc7j4J2SulGISYY7ocuX3
# tkv01te72Mv2KkqqpfkLEAQjXgtM0hlgwuc8/A4if+I0YtboCMkVQuwBpbR9/6ys
# Z+sCAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZldQ5Y
# MB0GA1UdDgQWBBRcxSkFqeA3vvHU0aq2mVpFRSOdmjAOBgNVHQ8BAf8EBAMCB4Aw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGGL2h0
# dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMEwG
# A1UdIARFMEMwNwYJYIZIAYb9bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3
# LmRpZ2ljZXJ0LmNvbS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcwAoZC
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJ
# RENvZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQAD
# ggEBANuBGTbzCRhgG0Th09J0m/qDqohWMx6ZOFKhMoKl8f/l6IwyDrkG48JBkWOA
# QYXNAzvp3Ro7aGCNJKRAOcIjNKYef/PFRfFQvMe07nQIj78G8x0q44ZpOVCp9uVj
# sLmIvsmF1dcYhOWs9BOG/Zp9augJUtlYpo4JW+iuZHCqjhKzIc74rEEiZd0hSm8M
# asshvBUSB9e8do/7RhaKezvlciDaFBQvg5s0fICsEhULBRhoyVOiUKUcemprPiTD
# xh3buBLuN0bBayjWmOMlkG1Z6i8DUvWlPGz9jiBT3ONBqxXfghXLL6n8PhfppBhn
# daPQO8+SqF5rqrlyBPmRRaTz2GQwggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7Vv
# lVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0Rp
# Z2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEw
# MjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNI
# QTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx
# 6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEj
# lpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJN
# YBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2
# DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9
# hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNV
# HRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEF
# BQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDig
# NoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9v
# dENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAo
# BggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgB
# hv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAU
# Reuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi
# 0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6l
# jlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0k
# riTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/P
# QMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d
# 9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJm
# oecYpJpkUe8xggIoMIICJAIBATCBhjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQD
# EyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBAhACwXUo
# dNXChDGFKtigZGnKMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAM
# BgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRFqowGCQB4Mgow8jCjPMmoco/m
# 3TANBgkqhkiG9w0BAQEFAASCAQCKSqD+lTfIv1uqi1BQVaY8t/7Ukwj/C+BWmzyn
# 789oOi1VOj81dqBR7UewdArEM6ta0Iq04EYNXP1fo3fhEjca9gmmSSLwojOnnik2
# +hsw7hGIKTOsUHx4SlICfc0w7mHu+rC/nGreppToVueaFEDJpgWGT1pGckNmzofx
# h1/0bF5NKc5QE9r7G9qGHZHHOnvQP3DuWQVwDr8q8x8oFa5RLH/vKPpQGajQUvzr
# kQP5U5HvDmJmjGcslWdvDEDMPz2BrYPMwBywNzDBWh5J8+Yzb5p5dRTulC5VYtvI
# 6HAT725T/gofOJbhiqwdfGJgVVeHeSDIIqm6b0cBBlHQn/0y
# SIG # End signature block
