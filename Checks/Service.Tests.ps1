Describe "SQL Service" -Tags SQLService, $filename {
    @(Get-Instance).ForEach{
        try {
            Context "Testing SQL Services are running on $psitem" {
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Effectively changing the setting with $RepairValue
                    $_.Start()                       
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue 
                    return $_.State -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $checkBlock = {
                    $_.State | Should -Be $ReferenceValue -Because 'The SQL Services are required to be running.'
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #                
                $ComputerName = ($psitem.ComputerName | Get-Unique) 
                $InstanceName = ($psitem.InstanceName | Get-Unique)                
                If ($CurrentConfig = Get-DbaService -ComputerName  $ComputerName -InstanceName $InstanceName -Type Engine,Agent ) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property ServiceType,InstanceName -RepairValue "Running" -ReferenceValue "Running"
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "SQL <ServiceType> Should Be running on <InstanceName>"                
                }
                else {
                    Write-PSFMessage -level Host -Message "No SQL Server Service was found with the used parameters: ComputerName:$ComputerName InstanceName:$InstanceName"
                }
            }
        }
        catch {
            $psitem = $Instance
            Context "Testing SQL Services are running on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The server should be available to be connected to!"
                }
            }
        }
    }
}

Describe "SQL Service Start Mode" -Tags ServiceStartMode, $filename {
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Testing SQL Services are running on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $Instance = $psitem
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                $psitem = $Instance
                Context "Testing SQL Services are running on $psitem" {
                    It "Can't Connect to $Psitem" {
                        $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                    }
                }
                $connectioncheck = [PSCustomObject]@{
                    Edition = "Express Edition"
                }
            }
                    
            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                Context "Testing SQL Services are running on $psitem" {
                    It "Can't Connect to $Psitem" {
                        $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                    }
                }
            }
            else {                
                $IsClustered = $Psitem.$IsClustered
                $Server = ($connectioncheck.ComputerName | Get-Unique)
                $InstanceName = ($connectioncheck.ServiceName | Get-Unique)            
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = Get-DbaService -ComputerName $Server -InstanceName $InstanceName -Type Engine,Agent -ErrorAction SilentlyContinue) {
                    Context "Testing SQL Services are running on $psitem" {
                        if ($IsClustered) {
                            # --------------------------------------- #
                            # Change the setting to the desired value #
                            # Passed on: Get-DbcTestCase funtion      #
                            # Used on: Repair-DbcCheck function       #
                            # --------------------------------------- #
                            $RepairBlock = {
                                # Effectively changing the setting with $RepairValue
                                $_.ChangeStartMode($RepairValue)
                                # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                                return $_.StartMode -eq $RepairValue                                 
                            }
                            # ------------------------------------------------ #
                            # Define the Pester check validation for a setting #
                            # Passed on: Get-DbcTestCase funtion               #
                            # ------------------------------------------------ #
                            $checkBlock = {
                                $_.StartMode | Should -Be $ReferenceValue -Because 'Clustered Instances required that the SQL services are set as manual'
                            }
                            # --------------------------------------------------------------------- #
                            # Function Get-DbcTestCase formatting the expected output for TestCases #
                            # --------------------------------------------------------------------- #
                            $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property ServiceType, InstanceName -RepairValue "Manual" -ReferenceValue "Manual"
                            # ---------------------- #
                            # Pester check execution #
                            # ---------------------- #
                            It @TestCases  "SQL <ServiceType> Service should have a start mode of Manual on FailOver Clustered Instance <InstanceName>"                         
                        }
                        else {
                            # --------------------------------------- #
                            # Change the setting to the desired value #
                            # Passed on: Get-DbcTestCase funtion      #
                            # Used on: Repair-DbcCheck function       #
                            # --------------------------------------- #
                            $RepairBlock = {
                                # Effectively changing the setting with $RepairValue
                                $_.ChangeStartMode($RepairValue)
                                # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                                return $_.StartMode -eq $RepairValue                                
                            }
                            # ------------------------------------------------ #
                            # Define the Pester check validation for a setting #
                            # Passed on: Get-DbcTestCase funtion               #
                            # ------------------------------------------------ #
                            $checkBlock = {
                                $_.StartMode | Should -Be $ReferenceValue -Because 'Otherwise If the server restarts, the SQL Server will not be accessible and/or not be able to run jobs'
                            }
                            # --------------------------------------------------------------------- #
                            # Function Get-DbcTestCase formatting the expected output for TestCases #
                            # --------------------------------------------------------------------- #
                            $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property ServiceType,InstanceName -RepairValue "Automatic" -ReferenceValue "Automatic"
                            # ---------------------- #
                            # Pester check execution #
                            # ---------------------- #
                            It @TestCases "SQL <ServiceType> Service should have a start mode of Automatic on standalone instance <InstanceName>"                       
                        }
                    }
                }
            }
        }            
    }
}