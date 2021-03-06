﻿$filename = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

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

    Describe "Database Collation" -Tags DatabaseCollation, $filename {
        $Wrongcollation = Get-DbcConfigValue policy.database.wrongcollation
        $exclude = "ReportingServer", "ReportingServerTempDB"
        $exclude += $Wrongcollation
        $exclude += $ExcludedDatabases
  
        if ($NotContactable -contains $psitem) {
            Context "Testing database collation on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing database collation on $psitem" {
                @(Test-DbaDbCollation -SqlInstance $psitem -Database $Database -ExcludeDatabase $exclude).ForEach{
                    It "database collation ($($psitem.DatabaseCollation)) should match server collation ($($psitem.ServerCollation)) for $($psitem.Database) on $($psitem.SqlInstance)" {
                        $psitem.ServerCollation | Should -Be $psitem.DatabaseCollation -Because "You will get collation conflict errors in tempdb"
                    }
                }
                if ($Wrongcollation) {
                    @(Test-DbaDbCollation -SqlInstance $psitem -Database $Wrongcollation ).ForEach{
                        It "database collation ($($psitem.DatabaseCollation)) should not match server collation ($($psitem.ServerCollation)) for $($psitem.Database) on $($psitem.SqlInstance)" {
                            $psitem.ServerCollation | Should -Not -Be $psitem.DatabaseCollation -Because "You have defined the database to have another collation then the server. You will get collation conflict errors in tempdb"
                        }
                    }
                }
            }
        }
    
    }

    Describe "Suspect Page" -Tags SuspectPage, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing suspect pages on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing suspect pages on $psitem" {
                $Instance.Databases.Where{if ($Database) {$_.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name}}.ForEach{
                    $results = Get-DbaSuspectPage -SqlInstance $psitem.Parent -Database $psitem.Name
                    It "$($psitem.Name) should return 0 suspect pages on $($psitem.Parent.Name)" {
                        @($results).Count | Should -Be 0 -Because "You do not want suspect pages"
                    }
                }
            }
        }
    }

    Describe "Last Backup Restore Test" -Tags TestLastBackup, Backup, $filename {
        if (-not (Get-DbcConfigValue skip.backup.testing)) {
            $destserver = Get-DbcConfigValue policy.backup.testserver
            $destdata = Get-DbcConfigValue policy.backup.datadir
            $destlog = Get-DbcConfigValue policy.backup.logdir
            if ($NotContactable -contains $psitem) {
                Context "Testing Backup Restore & Integrity Checks on $psitem" {
                    It "Can't Connect to $Psitem" {
                        $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                    }
                }
            }
            else {
                if (-not $destserver) {
                    $destserver = $psitem
                }
                Context "Testing Backup Restore & Integrity Checks on $psitem" {
                    $srv = Connect-DbaInstance -SqlInstance $psitem
                    $dbs = ($srv.Databases.Where{$_.CreateDate -lt (Get-Date).AddHours( - $graceperiod) -and $(if ($Database) {$_.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}).Name
                    if (-not ($destdata)) {$destdata -eq $srv.DefaultFile}
                    if (-not ($destlog)) {$destlog -eq $srv.DefaultLog}
                    @(Test-DbaLastBackup -SqlInstance $psitem -Database $dbs -Destination $destserver -DataDirectory $destdata -LogDirectory $destlog -VerifyOnly).ForEach{                    if ($psitem.DBCCResult -notmatch "skipped for restored master") {
                            It "DBCC for $($psitem.Database) on $($psitem.SourceServer) Should Be success" {
                                $psitem.DBCCResult | Should -Be "Success" -Because "You need to run DBCC CHECKDB to ensure your database is consistent"
                            }
                            It "restore for $($psitem.Database) on $($psitem.SourceServer) Should Be success" {
                                $psitem.RestoreResult | Should -Be "Success" -Because "The backup file has not successfully restored - you have no backup"
                            }
                        }
                    }
                }
            }
        }
    }

    Describe "Last Backup VerifyOnly" -Tags TestLastBackupVerifyOnly, Backup, $filename {
        $graceperiod = Get-DbcConfigValue policy.backup.newdbgraceperiod
        if ($NotContactable -contains $psitem) {
            Context "VerifyOnly tests of last backups on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "VerifyOnly tests of last backups on $psitem" {
                @(Test-DbaLastBackup -SqlInstance $psitem -Database ((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{$_.CreateDate -lt (Get-Date).AddHours( - $graceperiod) -and $(if ($Database) {$_.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}).Name -VerifyOnly).ForEach{
                    It "restore for $($psitem.Database) on $($psitem.SourceServer) Should be success" {
                        $psitem.RestoreResult | Should -Be "Success" -Because "The restore file has not successfully verified - you have no backup"
                    }
                    It "file exists for last backup of $($psitem.Database) on $($psitem.SourceServer)" {
                        $psitem.FileExists | Should -BeTrue -Because "Without a backup file you have no backup"
                    }
                }
            }
        }
    }

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
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    It @TestCases "Database <Name> - owner <Owner> should be in this list ( $( [String]::Join(", ", $targetowner) ) ) on <SQLInstance>"
                }                
            }
        }
    }

    Describe "Invalid Database Owner" -Tags InvalidDatabaseOwner, $filename {
        [string[]]$targetowner = Get-DbcConfigValue policy.invaliddbowner.name
        [string[]]$exclude = Get-DbcConfigValue policy.invaliddbowner.excludedb
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
                @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{if ($database) {$_.Name -in $database}else {$_.Name -notin $exclude}}).ForEach{
                    It "Database $($psitem.Name) - owner $($psitem.Owner) should Not be in this list ( $( [String]::Join(", ", $targetowner) ) ) on $($psitem.Parent.Name)" {
                        $psitem.Owner | Should -Not -BeIn $TargetOwner -Because "The database owner was one specified as incorrect"
                    }
                }
            }
        }
    }

    Describe "Last Good DBCC CHECKDB" -Tags LastGoodCheckDb, $filename {
        $maxdays = Get-DbcConfigValue policy.dbcc.maxdays
        $datapurity = Get-DbcConfigValue skip.dbcc.datapuritycheck
        $graceperiod = Get-DbcConfigValue policy.backup.newdbgraceperiod
        if ($NotContactable -contains $psitem) {
            Context "Testing Last Good DBCC CHECKDB on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Last Good DBCC CHECKDB on $psitem" {
                @(Get-DbaLastGoodCheckDb -SqlInstance $psitem -Database ((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{$_.CreateDate -lt (Get-Date).AddHours( - $graceperiod) -and ($_.IsAccessible -eq $true) -and $(if ($database) {$psitem.name -in $Database}else {$ExcludedDatabases -notcontains $_.Name})}).Name ).ForEach{
                    if ($psitem.Database -ne "tempdb") {
                        It "last good integrity check for $($psitem.Database) on $($psitem.SqlInstance) Should Be less than $maxdays days old" {
                            $psitem.LastGoodCheckDb | Should -BeGreaterThan (Get-Date).AddDays( - ($maxdays)) -Because "You should have run a DBCC CheckDB inside that time"
                        }
                        It -Skip:$datapurity "last good integrity check for $($psitem.Database) on $($psitem.SqlInstance) has Data Purity Enabled" {
                            $psitem.DataPurityEnabled | Should -BeTrue -Because "the DATA_PURITY option causes the CHECKDB command to look for column values that are invalid or out of range."
                        }
                    }
                }
            }
        }
    }
    
    Describe "Column Identity Usage" -Tags IdentityUsage, $filename {
        $maxpercentage = Get-DbcConfigValue policy.identity.usagepercent
        if ($NotContactable -contains $psitem) {
            Context "Testing Column Identity Usage on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Column Identity Usage on $psitem" {
                $exclude = $ExcludedDatabases
                $exclude += (Connect-DbaInstance -SqlInstance $psitem).Databases.Where{$_.IsAccessible -eq $false}.Name
                @(Test-DbaIdentityUsage -SqlInstance $psitem -Database $Database -ExcludeDatabase $exclude).ForEach{
                    if ($psitem.Database -ne "tempdb") {
                        $columnfqdn = "$($psitem.Database).$($psitem.Schema).$($psitem.Table).$($psitem.Column)"
                        It "usage for $columnfqdn on $($psitem.SqlInstance) Should Be less than $maxpercentage percent" {
                            $psitem.PercentUsed -lt $maxpercentage | Should -BeTrue -Because "You do not want your Identity columns to hit the max value and stop inserts"
                        }
                    }
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.RecoveryModel = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $recoverymodel -ReferenceValue $recoverymodel
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- # 
                    It @TestCases "<Name> should be set to $recoverymodel on <SQLInstance>" 
                }
            }
        }
    }

    Describe "Duplicate Index" -Tags DuplicateIndex, $filename {
        $Excludeddbs = $ExcludedDatabases + 'msdb'
        if ($NotContactable -contains $psitem) {
            Context "Testing duplicate indexes on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing duplicate indexes on $psitem" {
                $instance = $Psitem
                @(Get-Database -Instance $instance -Requiredinfo Name -Exclusions NotAccessible -Database $Database -ExcludedDbs $Excludeddbs).ForEach{
                    It "$psitem on $Instance should return 0 duplicate indexes" {
                        Assert-DatabaseDuplicateIndex -Instance $instance -Database $psitem
                    }
                }
            }
        }
    }

    Describe "Unused Index" -Tags UnusedIndex, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Unused indexes on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Unused indexes on $psitem" {
                try {
                    @($results = Find-DbaUnusedIndex -SqlInstance $psitem -Database $Database -ExcludeDatabase $ExcludedDatabases -EnableException).ForEach{
                        It "$psitem on $($psitem.SQLInstance) should return 0 Unused indexes" {
                            @($results).Count | Should -Be 0 -Because "You should have indexes that are used"
                        }
                    }
                }
                catch {
                    It -Skip "$psitem on $($psitem.SQLInstance) should return 0 Unused indexes" {
                        @($results).Count | Should -Be 0 -Because "You should have indexes that are used"
                    }
                }
            }
        }
    }

    Describe "Disabled Index" -Tags DisabledIndex, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Disabled indexes on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Disabled indexes on $psitem" {
                $Instance.Databases.Where{$(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name}) -and ($_.IsAccessible -eq $true)}.ForEach{
                    $results = Find-DbaDisabledIndex -SqlInstance $psitem.Parent -Database $psitem.Name
                    It "$($psitem.Name) on $($psitem.Parent.Name) should return 0 Disabled indexes" {
                        @($results).Count | Should -Be 0 -Because "Disabled indexes are wasting disk space"
                    }
                }
            }
        }
    }

    Describe "Database Growth Event" -Tags DatabaseGrowthEvent, $filename {
        $exclude = Get-DbcConfigValue policy.database.filegrowthexcludedb
        if ($NotContactable -contains $psitem) {
            Context "Testing database growth event on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing database growth event on $psitem" {
                $Instance.Databases.Where{$(if ($Database) {$PsItem.Name -in $Database}else {$PSItem.Name -notin $exclude -and ($ExcludedDatabases -notcontains $PsItem.Name)})}.ForEach{
                    $results = Find-DbaDbGrowthEvent -SqlInstance $psitem.Parent -Database $psitem.Name
                    It "$($psitem.Name) should return 0 database growth events on $($psitem.Parent.Name)" {
                        @($results).Count | Should -Be 0 -Because "You want to control how your database files are grown"
                    }
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.PageVerify = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $pageverify -ReferenceValue $pageverify
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "<Name> on <SQLInstance> should have page verify set to $pageverify"
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoClose = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $autoclose -ReferenceValue $autoclose
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "<Name> on <SQLInstance> should have Auto Close set to $autoclose"
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoShrink = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $autoshrink -ReferenceValue $autoshrink
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "<Name> on <SQLInstance> should have Auto Shrink set to $autoshrink"
                }
            }
        }
    }

    Describe "Last Full Backup Times" -Tags LastFullBackup, LastBackup, Backup, DISA, $filename {
        $maxfull = Get-DbcConfigValue policy.backup.fullmaxdays
        $graceperiod = Get-DbcConfigValue policy.backup.newdbgraceperiod
        $skipreadonly = Get-DbcConfigValue skip.backup.readonly
        if ($NotContactable -contains $psitem) {
            Context "Testing last full backups on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing last full backups on $psitem" {
                $Instance.Databases.Where{ ($psitem.Name -ne 'tempdb') -and $Psitem.CreateDate -lt (Get-Date).AddHours( - $graceperiod) -and $(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}.ForEach{
                    $skip = ($psitem.Status -match "Offline") -or ($psitem.IsAccessible -eq $false) -or ($psitem.Readonly -eq $true -and $skipreadonly -eq $true)
                    It -Skip:$skip "$($psitem.Name) full backups on $($psitem.Parent.Name) Should Be less than $maxfull days" {
                        $psitem.LastBackupDate | Should -BeGreaterThan (Get-Date).AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
                    }
                }
            }
        }
    }

    Describe "Last Diff Backup Times" -Tags LastDiffBackup, LastBackup, Backup, DISA, $filename {
        if (-not (Get-DbcConfigValue skip.diffbackuptest)) {
            $maxdiff = Get-DbcConfigValue policy.backup.diffmaxhours
            $graceperiod = Get-DbcConfigValue policy.backup.newdbgraceperiod
            $skipreadonly = Get-DbcConfigValue skip.backup.readonly
            if ($NotContactable -contains $psitem) {
                Context "Testing last diff backups on $psitem" {
                    It "Can't Connect to $Psitem" {
                        $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                    }
                }
            }
            else {
                Context "Testing last diff backups on $psitem" {
                    @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{ (-not $psitem.IsSystemObject) -and $Psitem.CreateDate -lt (Get-Date).AddHours( - $graceperiod) -and $(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}).ForEach{
                        $skip = ($psitem.Status -match "Offline") -or ($psitem.IsAccessible -eq $false) -or ($psitem.Readonly -eq $true -and $skipreadonly -eq $true)
                        It -Skip:$skip "$($psitem.Name) diff backups on $($psitem.Parent.Name) Should Be less than $maxdiff hours" {
                            $psitem.LastDifferentialBackupDate | Should -BeGreaterThan (Get-Date).AddHours( - ($maxdiff)) -Because 'Taking regular backups is extraordinarily important'
                        }
                    }
                }
            }
        }
    }

    Describe "Last Log Backup Times" -Tags LastLogBackup, LastBackup, Backup, DISA, $filename {
        $maxlog = Get-DbcConfigValue policy.backup.logmaxminutes
        $graceperiod = Get-DbcConfigValue policy.backup.newdbgraceperiod
        $skipreadonly = Get-DbcConfigValue skip.backup.readonly
        if ($NotContactable -contains $psitem) {
            Context "Testing last log backups on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing last log backups on $psitem" {
                @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{ (-not $psitem.IsSystemObject) -and $Psitem.CreateDate -lt (Get-Date).AddHours( - $graceperiod) -and $(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}).ForEach{
                    if ($psitem.RecoveryModel -ne "Simple") {
                        $skip = ($psitem.Status -match "Offline") -or ($psitem.IsAccessible -eq $false) -or ($psitem.Readonly -eq $true -and $skipreadonly -eq $true)
                        It -Skip:$skip  "$($psitem.Name) log backups on $($psitem.Parent.Name) Should Be less than $maxlog minutes" {
                            $psitem.LastLogBackupDate | Should -BeGreaterThan (Get-Date).AddMinutes( - ($maxlog) + 1) -Because "Taking regular backups is extraordinarily important"
                        }
                    }
                }
            }
        }
    }

    Describe "Virtual Log Files" -Tags VirtualLogFile, $filename {
        $vlfmax = Get-DbcConfigValue policy.database.maxvlf
        if ($NotContactable -contains $psitem) {
            Context "Testing Database VLFs on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Database VLFs on $psitem" {
                @(Test-DbaDbVirtualLogFile -SqlInstance $psitem -ExcludeDatabase $ExcludedDatabases -Database $Database).ForEach{
                    It "$($psitem.Database) VLF count on $($psitem.SqlInstance) Should Be less than $vlfmax" {
                        $psitem.Total | Should -BeLessThan $vlfmax -Because "Too many VLFs can impact performance and slow down backup/restore"
                    }
                }
            }
        }
    }

    Describe "Log File Count Checks" -Tags LogfileCount, $filename {
        $LogFileCountTest = Get-DbcConfigValue skip.database.logfilecounttest
        $LogFileCount = Get-DbcConfigValue policy.database.logfilecount
        If (-not $LogFileCountTest) {   
            if ($NotContactable -contains $psitem) {
                Context "Testing Log File count for $psitem" {
                    It "Can't Connect to $Psitem" {
                        $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                    }
                }
            }
            else {
                Context "Testing Log File count for $psitem" {
                    @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name}}).ForEach{
                        $Files = Get-DbaDbFile -SqlInstance $psitem.Parent.Name -Database $psitem.Name
                        $LogFiles = $Files | Where-Object {$_.TypeDescription -eq "LOG"}
                        It "$($psitem.Name) on $($psitem.Parent.Name) Should have less than $LogFileCount Log files" {
                            $LogFiles.Count | Should -BeLessThan $LogFileCount -Because "You want the correct number of log files"
                        }
                    }
                }
            }
        }
    }

    Describe "Log File Size Checks" -Tags LogfileSize, $filename {
        $LogFileSizePercentage = Get-DbcConfigValue policy.database.logfilesizepercentage
        $LogFileSizeComparison = Get-DbcConfigValue policy.database.logfilesizecomparison
        if ($NotContactable -contains $psitem) {
            Context "Testing Log File size for $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Log File size for $psitem" {
                $Instance.Databases.Where{$(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name}) -and ($Psitem.IsAccessible -eq $true)}.ForEach{
                    $Files = Get-DbaDbFile -SqlInstance $psitem.Parent.Name -Database $psitem.Name
                    $LogFiles = $Files | Where-Object {$_.TypeDescription -eq "LOG"}
                    $Splat = @{$LogFileSizeComparison = $true;
                        property                      = "size"
                    }
                    $LogFileSize = ($LogFiles | Measure-Object -Property Size -Maximum).Maximum
                    $DataFileSize = ($Files | Where-Object {$_.TypeDescription -eq "ROWS"} | Measure-Object @Splat).$LogFileSizeComparison
                    It "$($psitem.Name) on $($psitem.Parent.Name) Should have no log files larger than $LogFileSizePercentage% of the $LogFileSizeComparison of DataFiles" {
                        $LogFileSize | Should -BeLessThan ($DataFileSize * $LogFileSizePercentage) -Because "If your log file is this large you are not maintaining it well enough"
                    }
                }
            }
        }
    }

    Describe "Future File Growth" -Tags FutureFileGrowth, $filename {
        $threshold = Get-DbcConfigValue policy.database.filegrowthfreespacethreshold
        [string[]]$exclude = Get-DbcConfigValue policy.database.filegrowthexcludedb
        $exclude += $ExcludedDatabases 
        if ($NotContactable -contains $psitem) {
            Context "Testing for files likely to grow soon on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing for files likely to grow soon on $psitem" {
                $Instance.Databases.Where{$(if ($Database) {$PsItem.Name -in $Database}else {$PsItem.Name -notin $exclude})}.ForEach{
                    $Files = Get-DbaDbFile -SqlInstance $psitem.Parent.Name -Database $psitem.Name
                    $Files | Add-Member ScriptProperty -Name PercentFree -Value {100 - [Math]::Round(([int64]$PSItem.UsedSpace.Byte / [int64]$PSItem.Size.Byte) * 100, 3)}
                    $Files | ForEach-Object {
                        if (-Not (($PSItem.Growth -eq 0) -and (Get-DbcConfigValue skip.database.filegrowthdisabled))) {
                            It "$($PSItem.Database) file $($PSItem.LogicalName) on $($PSItem.SqlInstance) has free space under threshold" {
                                $PSItem.PercentFree | Should -BeGreaterOrEqual $threshold -Because "free space within the file should be lower than threshold of $threshold %"
                            }
                        }
                    }
                }
            }
        }
    }

    Describe "Correctly sized Filegroup members" -Tags FileGroupBalanced, $filename {
        $Tolerance = Get-DbcConfigValue policy.database.filebalancetolerance
        if ($NotContactable -contains $psitem) {
            Context "Testing for balanced FileGroups on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing for balanced FileGroups on $psitem" {
                @(Connect-DbaInstance -SqlInstance $_).Databases.Where{$(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}.ForEach{
                    $Files = Get-DbaDbFile -SqlInstance $psitem.Parent.Name -Database $psitem.Name
                    $FileGroups = $Files | Where-Object {$_.TypeDescription -eq "ROWS"} | Group-Object -Property FileGroupName
                    @($FileGroups).ForEach{
                        $Unbalanced = 0
                        $Average = ($psitem.Group.Size | Measure-Object -Average).Average
                        ## files where average size is less than 95% of the average or more than 105% of the average filegroup size (using default 5% config value)
                        $Unbalanced = $psitem | Where-Object {$psitem.group.Size -lt ((1 - ($Tolerance / 100)) * $Average) -or $psitem.group.Size -gt ((1 + ($Tolerance / 100)) * $Average)}
                        It "$($psitem.Name) of $($psitem.Group[0].Database) on $($psitem.Group[0].SqlInstance) Should have FileGroup members with sizes within $tolerance % of the average" {
                            $Unbalanced.count | Should -Be 0 -Because "If your file groups are not balanced the files with the most free space will become allocation hotspots"
                        }
                    }
                }
            }
        }
    }

    Describe "Certificate Expiration" -Tags CertificateExpiration, $filename {
        $CertificateWarning = Get-DbcConfigValue policy.certificateexpiration.warningwindow
        [string[]]$exclude = Get-DbcConfigValue policy.certificateexpiration.excludedb
        $exclude += $ExcludedDatabases 
        if ($NotContactable -contains $psitem) {
            Context "Checking that encryption certificates have not expired on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Checking that encryption certificates have not expired on $psitem" {
                @(Get-DbaDbEncryption -SqlInstance $psitem -IncludeSystemDBs -Database $Database | Where-Object {$_.Encryption -eq "Certificate" -and ($_.Database -notin $exclude)}).ForEach{
                    It "$($psitem.Name) in $($psitem.Database) has not expired" {
                        $psitem.ExpirationDate  | Should -BeGreaterThan (Get-Date) -Because "this certificate should not be expired"
                    }
                    It "$($psitem.Name) in $($psitem.Database) does not expire for more than $CertificateWarning months" {
                        $psitem.ExpirationDate  | Should -BeGreaterThan (Get-Date).AddMonths($CertificateWarning) -Because "expires inside the warning window of $CertificateWarning"
                    }
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoCreateStatisticsEnabled = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $autocreatestatistics -ReferenceValue $autocreatestatistics
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "<Name> on <SQLInstance> should have Auto Create Statistics set to $autocreatestatistics"
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoUpdateStatisticsEnabled = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $autoupdatestatistics -ReferenceValue $autoupdatestatistics
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "<Name> on <SQLInstance> should have Auto Update Statistics set to $autoupdatestatistics"
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
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.AutoUpdateStatisticsAsync = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $autoupdatestatisticsasynchronously -ReferenceValue $autoupdatestatisticsasynchronously
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #                
                    It @TestCases "<Name> on <SQLInstance> should have Auto Update Statistics Asynchronously set to $autoupdatestatisticsasynchronously"
                }
            }
        }
    }
    
    Describe "Datafile Auto Growth Configuration" -Tags DatafileAutoGrowthType, $filename {
        $datafilegrowthtype = Get-DbcConfigValue policy.database.filegrowthtype
        $datafilegrowthvalue = Get-DbcConfigValue policy.database.filegrowthvalue
        $exclude = Get-DbcConfigValue policy.database.filegrowthexcludedb
        $exclude += $ExcludedDatabases 
        if ($NotContactable -contains $psitem) {
            Context "Testing datafile growth type on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing datafile growth type on $psitem" {
                @(Get-DbaDbFile -SqlInstance $psitem -Database $Database -ExcludeDatabase $exclude ).ForEach{
                    if (-Not (($psitem.Growth -eq 0) -and (Get-DbcConfigValue skip.database.filegrowthdisabled))) {
                        It "$($psitem.LogicalName) on filegroup $($psitem.FileGroupName) should have GrowthType set to $datafilegrowthtype on $($psitem.SqlInstance)" {
                            $psitem.GrowthType | Should -Be $datafilegrowthtype -Because "We expect a certain file growth type"
                        }
                        if ($datafilegrowthtype -eq "kb") {
                            It "$($psitem.LogicalName) on filegroup $($psitem.FileGroupName) should have Growth set equal or higher than $datafilegrowthvalue on $($psitem.SqlInstance)" {
                                $psitem.Growth * 8 | Should -BeGreaterOrEqual $datafilegrowthvalue  -because "We expect a certain file growth value"
                            }
                        }
                        else {
                            It "$($psitem.LogicalName) on filegroup $($psitem.FileGroupName) should have Growth set equal or higher than $datafilegrowthvalue on $($psitem.SqlInstance)" {
                                $psitem.Growth | Should -BeGreaterOrEqual $datafilegrowthvalue  -because "We expect a certain fFile growth value"
                            }
                        }
                    }
                }
            }
        }
    }

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
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()
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
                    It @TestCases "Trustworthy on <Name> is set to false on <SQLInstance>"
                }
            }
        }
    }    
}
Describe "Database Orphaned User" -Tags OrphanedUser, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing database orphaned user event on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing database orphaned user event on $psitem" {
                $instance = $psitem
                @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{($(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name}))}).ForEach{
                    It "$($psitem.Name) should return 0 orphaned users" {
                        @(Get-DbaOrphanUser -SqlInstance $instance -ExcludeDatabase $ExcludedDatabases -Database $psitem.Name).Count | Should -Be 0 -Because "We dont want orphaned users"
                    }
                }
            }
        }
    }

    Describe "PseudoSimple Recovery Model" -Tags PseudoSimple, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing database is not in PseudoSimple recovery model on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing database is not in PseudoSimple recovery model on $psitem" {
                @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{$psitem.Name -ne 'tempdb' -and $psitem.Name -ne 'model' -and ($(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name}))}).ForEach{
                    if (-not($psitem.RecoveryModel -eq "Simple")) {
                        It "$($psitem.Name) has PseudoSimple recovery model equal false on $($psitem.Parent.Name)" { (Test-DbaRecoveryModel -SqlInstance $psitem.Parent -Database $psitem.Name).ActualRecoveryModel -eq "SIMPLE" | Should -BeFalse -Because "PseudoSimple means that a FULL backup has not been taken and the database is still effectively in SIMPLE mode" } 
                    }
                }
            }
        }
    }

    Describe "Compatibility Level" -Tags CompatibilityLevel, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing database compatibility level matches server compatibility level on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing database compatibility level matches server compatibility level on $psitem" {
                @(Test-DbaDbCompatibility -SqlInstance $psitem -ExcludeDatabase $ExcludedDatabases -Database $Database).ForEach{
                    It "$($psitem.Database) has a database compatibility level equal to the level of $($psitem.SqlInstance)" {
                        $psItem.DatabaseCompatibility | Should -Be $psItem.ServerLevel -Because "it means you are on the appropriate compatibility level for your SQL Server version to use all available features"
                    }
                }
            }
        }
    }

    Describe "Foreign keys and check constraints not trusted" -Tags FKCKTrusted, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Foreign Keys and Check Constraints are not trusted $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Foreign Keys and Check Constraints are not trusted $psitem" {
                @(Get-DbaDbForeignKey -SqlInstance $psitem -ExcludeDatabase $ExcludedDatabases -Database $Database).Where{$_.NotForReplication -eq $false}.ForEach{
                    It "$($psitem.Name) foreign key on table $($psitem.Parent) within database $($psitem.Database) should be trusted." {
                        $psitem.IsChecked | Should -Be $true -Because "This can have a huge performance impact on queries. SQL Server wonâ€™t use untrusted constraints to build better execution plans. It will also avoid data violation"
                    }
                }

                @(Get-DbaDbCheckConstraint -SqlInstance $psitem -ExcludeDatabase $ExcludedDatabases -Database $Database).Where{$_.NotForReplication -eq $false -and $_.IsEnabled -eq $true}.ForEach{
                    It "$($psitem.Name) check constraint on table $($psitem.Parent) within database $($psitem.Database) should be trusted." {
                        $psitem.IsChecked | Should -Be $true -Because "This can have a huge performance impact on queries. SQL Server wonâ€™t use untrusted constraints to build better execution plans. It will also avoid data violation"
                    }
                }
            }
        }
    }

    Describe "Database MaxDop" -Tags MaxDopDatabase, MaxDop, $filename {
        $MaxDopValue = Get-DbcConfigValue policy.database.maxdop
        [string[]]$exclude = Get-DbcConfigValue policy.database.maxdopexcludedb
        $exclude += $ExcludedDatabases 
        if ($exclude) {Write-Warning "Excluded $exclude from testing"}
        if ($NotContactable -contains $psitem) {
            Context "Database MaxDop setting is correct on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Database MaxDop setting is correct on $psitem" {
                @(Test-DbaMaxDop -SqlInstance $psitem).Where{$_.Database -ne 'N/A' -and $(if ($database) {$PsItem.Database -in $Database} else {$_.Database -notin $exclude})}.ForEach{
                    It "Database $($psitem.Database) should have the correct MaxDop setting" {
                        Assert-DatabaseMaxDop -MaxDop $PsItem -MaxDopValue $MaxDopValue
                    }
                }
            }
        }
    }

    Describe "Database Status" -Tags DatabaseStatus, $filename {
        $ExcludeReadOnly = Get-DbcConfigValue policy.database.status.excludereadonly
        $ExcludeOffline = Get-DbcConfigValue policy.database.status.excludeoffline
        $ExcludeRestoring = Get-DbcConfigValue policy.database.status.excluderestoring
  
        if ($NotContactable -contains $psitem) {
            Context "Database status is correct on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Database status is correct on $psitem" {
                $instance = $psitem
                @((Connect-DbaInstance -SqlInstance $psitem).Databases.Where{$(if ($Database) {$PsItem.Name -in $Database}else {$ExcludedDatabases -notcontains $PsItem.Name})}).Foreach{
                    It "Database $($psitem.Name) has the expected status" {
                        Assert-DatabaseStatus -Instance $instance -Database $Database -ExcludeReadOnly $ExcludeReadOnly -ExcludeOffline $ExcludeOffline -ExcludeRestoring $ExcludeRestoring
                    }
                }
            }
        }
    }

    Describe "Database Exists" -Tags DatabaseExists, $filename {
        $Excludedbs = $ExcludedDatabases
        $expected = Get-DbcConfigValue database.exists
        if ($Database) {$expected += $Database}
        $expected = $expected.where{$psitem -notin $ExcludeDatabase}
        if ($NotContactable -contains $psitem) {
            Context "Database exists on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            $instance = $psitem
            Context "Database exists on $psitem" {
                $expected.ForEach{
                    It "Database $psitem should exist" {
                        Assert-DatabaseExists -Instance $instance -Expecteddb $psitem 
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
