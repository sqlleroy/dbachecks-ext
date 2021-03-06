﻿$filename = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
[string[]]$NotContactable = (Get-PSFConfig -Module dbachecks -Name global.notcontactable).Value
@(Get-Instance).ForEach{
    $Instance = $psitem
    try {  
        $connectioncheck = Connect-DbaInstance  -SqlInstance $Instance -ErrorAction SilentlyContinue -ErrorVariable errorvar
    }
    catch {
        $NotContactable += $Instance
    }
                
    if (($connectioncheck).Edition -like "Express Edition*") {Return}
    elseif ($null -eq $connectioncheck.version) {
        $NotContactable += $Instance
    }
    else {

    }
    Describe "Database Mail XPs" -Tags DatabaseMailEnabled, security, $filename {
        if ($NotContactable -contains $psitem) {
            Context "Testing Database Mail XPs on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false	|  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            Context "Testing Testing Database Mail XPs  on $psitem" {
                # PSFConfig with the desired value
                $DatabaseMailEnabled = Get-DbcConfigValue policy.security.DatabaseMailEnabled                
                # --------------------------------------- #
                # Change the setting to the desired value #
                # Passed on: Get-DbcTestCase funtion      #
                # Used on: Repair-DbcCheck function       #
                # --------------------------------------- #
                $RepairBlock = {
                    # Change the setting with desired value from the $RepairValue
                    $_.DatabaseMailEnabled.ConfigValue = $RepairValue
                    # Effectively changing the setting with $RepairValue
                    $_.Alter()                    
                    # Forcing the setting to reflect the recent change
                    $_.Refresh()
                    # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue                     
                    return $_.DatabaseMailEnabled.ConfigValue -eq $RepairValue
                }
                # ------------------------------------------------ #
                # Define the Pester check validation for a setting #
                # Passed on: Get-DbcTestCase funtion               #
                # ------------------------------------------------ #
                $checkBlock = {
                    $ConfigValue | Should -Be $ReferenceValue -Because 'The Database Mail XPS is required to send notifications.'
                }
                # ----------------------------------------------- #
                # Current state of a setting to be tested/checked #
                # ----------------------------------------------- #
                If ($CurrentConfig = $connectioncheck.Configuration) {
                    # --------------------------------------------------------------------- #
                    # Function Get-DbcTestCase formatting the expected output for TestCases #                
                    # --------------------------------------------------------------------- #
                    $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -RepairValue $DatabaseMailEnabled -ReferenceValue $DatabaseMailEnabled
                    # ---------------------- #
                    # Pester check execution #
                    # ---------------------- #
                    It @TestCases "Testing Database Mail XPs is set to $DatabaseMailEnabled on <SqlInstance>"
                }
            }
        }
    }
}

Set-PSFConfig -Module dbachecks -Name global.notcontactable -Value $NotContactable 
Describe "DBA Operators" -Tags DbaOperator, Operator, $filename {
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Testing DBA Operators exists on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
                    
            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            else {
                Context "Testing DBA Operators exists on $psitem" {
                    # PSFConfig with the desired value (can be an array)
                    [string[]]$operatorname = Get-DbcConfigValue agent.dbaoperatorname                
                    # PSFConfig with the desired value (can be an array)                    
                    [string[]]$operatoremail = Get-DbcConfigValue agent.dbaoperatoremail
                    # ----------------------------------------------- #
                    # Current state of a setting to be tested/checked #
                    # ----------------------------------------------- #
                    If ($CurrentConfig = Get-DbaAgentOperator -SqlInstance $Psitem -Operator $operatorname) {
                        # --------------------------------------- #
                        # Change the setting to the desired value #
                        # Passed on: Get-DbcTestCase funtion      #
                        # Used on: Repair-DbcCheck function       #
                        # --------------------------------------- #
                        # **** There is no change for the operator name since it must exist ****
                        $RepairBlock = {                            
                            return $false
                        }
                        # ------------------------------------------------ #
                        # Define the Pester check validation for a setting #
                        # Passed on: Get-DbcTestCase funtion               #
                        # ------------------------------------------------ #
                        $checkBlock = {
                            $_.Name | Should -BeIn $ReferenceValue -Because 'This Operator is expected to exist'
                        }
                        # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                        # **** There is no Target value for the operator name since it must exist ****
                        [string]$TargetValue = ""
                        # --------------------------------------------------------------------- #
                        # Function Get-DbcTestCase formatting the expected output for TestCases #
                        # --------------------------------------------------------------------- #
                        $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name -RepairValue $TargetValue -ReferenceValue $operatorname
                        # ---------------------- #
                        # Pester check execution #
                        # ---------------------- #  
                        It @TestCases "operator name <Name> exists on <SQLInstance>"
                        
                        #Code block for Email Address
                        # --------------------------------------- #
                        # Change the setting to the desired value #
                        # Passed on: Get-DbcTestCase funtion      #
                        # Used on: Repair-DbcCheck function       #
                        # --------------------------------------- #
                        $RepairBlock = {
                            # Change the setting with desired value from the $RepairValue
                            $_.EmailAddress = $RepairValue
                            # Effectively changing the setting with $RepairValue
                            $_.Alter()
                            # Forcing the setting to reflect the recent change
                            $_.Refresh()
                            # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                            return $_.EmailAddress -eq $RepairValue                            
                        }
                        # ------------------------------------------------ #
                        # Define the Pester check validation for a setting #
                        # Passed on: Get-DbcTestCase funtion               #
                        # ------------------------------------------------ #
                        $checkBlock = {
                            $_.EmailAddress | Should -BeIn $ReferenceValue -Because 'This operator email is expected to exist'
                        }
                        # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                        [string]$TargetValue = Get-DbcRepairValue -Name dbachecks.agent.dbaoperatoremail -ArrayPosition 0
                        # --------------------------------------------------------------------- #
                        # Function Get-DbcTestCase formatting the expected output for TestCases #
                        # --------------------------------------------------------------------- #
                        $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property Name, EmailAddress -RepairValue $TargetValue -ReferenceValue $operatoremail
                        # ---------------------- #
                        # Pester check execution #
                        # ---------------------- #  
                        It @TestCases "operator's <Name> email <EmailAddress> is correct on <SQLInstance>" 
                    }
                    Else {
                        Write-Host "    There is no Operator" $operatorname "on" $Psitem"." -ForegroundColor DarkYellow
                    }
                }
            }
        }
    }
}

Describe "Failsafe Operator" -Tags FailsafeOperator, Operator, $filename {
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Testing failsafe operator exists on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
                    
            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            else {
                Context "Testing failsafe operator exists on $psitem" {
                    # PSFConfig with the desired value
                    $failsafeoperator = Get-DbcConfigValue agent.failsafeoperator                    
                    # --------------------------------------- #
                    # Change the setting to the desired value #
                    # Passed on: Get-DbcTestCase funtion      #
                    # Used on: Repair-DbcCheck function       #
                    # --------------------------------------- #
                    $RepairBlock = {
                        # Change the setting with desired value from the $RepairValue
                        $_.FailSafeOperator = $RepairValue
                        $_.NotificationMethod = "NotifyEmail"
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                        # Forcing the setting to reflect the recent change
                        $_.Refresh()
                        # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                        return $_.FailSafeOperator -eq $RepairValue                        
                    }
                    # ------------------------------------------------ #
                    # Define the Pester check validation for a setting #
                    # Passed on: Get-DbcTestCase funtion               #
                    # ------------------------------------------------ #
                    $checkBlock = {
                        $_.FailSafeOperator | Should -Be $ReferenceValue -Because 'The failsafe operator will ensure that any job failures will be notified to someone if not set explicitly'
                    }
                    # ----------------------------------------------- #
                    # Current state of a setting to be tested/checked #
                    # ----------------------------------------------- #
                    If ($CurrentConfig = $connectioncheck.JobServer.AlertSystem) {
                        # --------------------------------------------------------------------- #
                        # Function Get-DbcTestCase formatting the expected output for TestCases #
                        # --------------------------------------------------------------------- #
                        $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property FailSafeOperator, Name -RepairValue $failsafeoperator -ReferenceValue $failsafeoperator
                        # ---------------------- #
                        # Pester check execution #
                        # ---------------------- #  
                        It @TestCases "failsafe operator <FailSafeOperator> on <Name> exists on <SQLInstance>"
                    }
                }
            }
        }
    }
}

Describe "Database Mail Profile" -Tags DatabaseMailProfile, $filename {
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Testing database mail profile is set on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
                    
            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            else {
                Context "Testing database mail profile is set on $psitem" {
                    # PSFConfig with the desired value
                    $databasemailprofile = Get-DbcConfigValue  agent.databasemailprofile                    
                    # --------------------------------------- #
                    # Change the setting to the desired value #
                    # Passed on: Get-DbcTestCase funtion      #
                    # Used on: Repair-DbcCheck function       #
                    # --------------------------------------- #
                    $RepairBlock = {
                        # Change the setting with desired value from the $RepairValue
                        $_.DatabaseMailProfile = $RepairValue
                        $_.AgentMailType = "DatabaseMail"
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                        # Forcing the setting to reflect the recent change
                        $_.Refresh()
                        # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                        return $_.DatabaseMailProfile -eq $RepairValue                       
                    }
                    # ------------------------------------------------ #
                    # Define the Pester check validation for a setting #
                    # Passed on: Get-DbcTestCase funtion               #
                    # ------------------------------------------------ #
                    $checkBlock = {
                        $_.DatabaseMailProfile | Should -Be $ReferenceValue -Because 'The database mail profile is required to send emails'
                    }
                    # ----------------------------------------------- #
                    # Current state of a setting to be tested/checked #
                    # ----------------------------------------------- #
                    If ($CurrentConfig = $connectioncheck.JobServer) {
                        # --------------------------------------------------------------------- #
                        # Function Get-DbcTestCase formatting the expected output for TestCases #
                        # --------------------------------------------------------------------- #
                        $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property DatabaseMailProfile, Name -RepairValue $databasemailprofile -ReferenceValue $databasemailprofile
                        # ---------------------- #
                        # Pester check execution #
                        # ---------------------- # 
                        It @TestCases "database mail profile on <Name> is <DatabaseMailProfile>"
                    }
                }
            }
        }
    }
}

Describe "Failed Jobs" -Tags FailedJob, $filename {
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Checking for failed enabled jobs on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
                    
            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            else {
                Context "Checking for failed enabled jobs on $psitem" {
                    @(Get-DbaAgentJob -SqlInstance $psitem | Where-Object IsEnabled).ForEach{
                        if ($psitem.LastRunOutcome -eq "Unknown") {
                            It -Skip "$psitem's last run outcome on $($psitem.SqlInstance) is unknown" {
                                $psitem.LastRunOutcome | Should -Be "Succeeded" -Because 'All Agent Jobs should have succeed this one is unknown - you need to investigate the failed jobs'
                            }
                        }
                        else {
                            It "$psitem's last run outcome on $($psitem.SqlInstance) is $($psitem.LastRunOutcome)" {
                                $psitem.LastRunOutcome | Should -Be "Succeeded" -Because 'All Agent Jobs should have succeed - you need to investigate the failed jobs'
                            }
                        }
                    }
                }
            }
        }
    }
}
Describe "Valid Job Owner" -Tags ValidJobOwner, $filename {
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Testing job owners on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }

            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            else {
                Context "Testing job owners on $psitem" {
                    # PSFConfig with the desired value (can be an array)
                    [string[]]$targetowner = Get-DbcConfigValue agent.validjobowner.name
                    # Function Get-DbcRepairValue to set which value from the above PSFConfig will be used as a repair value
                    [string]$TargetValue = Get-DbcRepairValue dbachecks.agent.validjobowner.name -ArrayPosition 0
                    # --------------------------------------- #
                    # Change the setting to the desired value #
                    # Passed on: Get-DbcTestCase funtion      #
                    # Used on: Repair-DbcCheck function       #
                    # --------------------------------------- #
                    $RepairBlock = {
                        # Change the setting with desired value from the $RepairValue
                        $_.OwnerLoginName = $RepairValue
                        # Effectively changing the setting with $RepairValue
                        $_.Alter()
                        # Forcing the setting to reflect the recent change
                        $_.Refresh()
                        # Return to the Repair-DbcCheck function whether the current setting match the $RepairValue
                        return $_.OwnerLoginName -eq $RepairValue                        
                    }
                    # ------------------------------------------------ #
                    # Define the Pester check validation for a setting #
                    # Passed on: Get-DbcTestCase funtion               #
                    # ------------------------------------------------ #
                    $checkBlock = {
                        $_.OwnerLoginName | Should -BeIn $ReferenceValue -Because "The account that is the job owner is not what was expected"
                    }
                    # ----------------------------------------------- #
                    # Current state of a setting to be tested/checked #
                    # ----------------------------------------------- #
                    If ($CurrentConfig = $connectioncheck.JobServer.Jobs){
                        # --------------------------------------------------------------------- #
                        # Function Get-DbcTestCase formatting the expected output for TestCases #
                        # --------------------------------------------------------------------- #
                        $TestCases = $CurrentConfig | Get-DbcTestCase -RepairBlock $RepairBlock -CheckBlock $checkBlock -Property OwnerLoginName -RepairValue $TargetValue -ReferenceValue $targetowner
                        # ---------------------- #
                        # Pester check execution #
                        # ---------------------- # 
                        It @TestCases "Job <Target> - owner <OwnerLoginName> should be in this list ( $( [String]::Join(", ", $targetowner) ) ) on <SqlInstance>"
                    }
                }
            }
        }
    }
}
Describe "Agent Alerts" -Tags AgentAlert, $filename {
    $severity = Get-DbcConfigValue agent.alert.Severity
    $messageid = Get-DbcConfigValue agent.alert.messageid
    $AgentAlertJob = Get-DbcConfigValue agent.alert.Job
    $AgentAlertNotification = Get-DbcConfigValue agent.alert.Notification
    @(Get-Instance).ForEach{
        if ($NotContactable -contains $psitem) {
            Context "Testing Agent Alerts Severity exists on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            Context "Testing Agent Alerts MessageID exists on $psitem" {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
        }
        else {
            try {
                $connectioncheck = Connect-DbaInstance  -SqlInstance $Psitem -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
                    
            if (($connectioncheck).Edition -like "Express Edition*") {}
            elseif ($null -eq $connectioncheck.version) {
                It "Can't Connect to $Psitem" {
                    $false  |  Should -BeTrue -Because "The instance should be available to be connected to!"
                }
            }
            else {
                $alerts = Get-DbaAgentAlert -SqlInstance $psitem
                Context "Testing Agent Alerts Severity exists on $psitem" {
                    ForEach ($sev in $severity) {
                        It "$psitem should have Severity $sev Alert" {
                            ($alerts.Where{$psitem.Severity -eq $sev}) | Should -be $true -Because "Recommended Agent Alerts to exists http://blog.extreme-advice.com/2013/01/29/list-of-errors-and-severity-level-in-sql-server-with-catalog-view-sysmessages/"
                        }
                        It "$psitem should have Severity $sev Alert enabled" {
                            ($alerts.Where{$psitem.Severity -eq $sev}) | Should -be $true -Because "Configured alerts should be enabled"
                        }
                        if ($AgentAlertJob) {
                            It "$psitem should have Jobname for Severity $sev Alert" {
                                ($alerts.Where{$psitem.Severity -eq $sev}).jobname -ne $null | Should -be $true -Because "Should notify by SQL Agent Job"
                            }
                        }
                        if ($AgentAlertNotification) {
                            It "$psitem should have notification for Severity $sev Alert" {
                                ($alerts.Where{$psitem.Severity -eq $sev}).HasNotification -in 1, 2, 3, 4, 5, 6, 7  | Should -be $true -Because "Should notify by Agent notifications"
                            }
                        }
                    }
                }
                Context "Testing Agent Alerts MessageID exists on $psitem" {
                    ForEach ($mid in $messageid) {
                        It "$psitem should have Message_ID $mid Alert" {
                            ($alerts.Where{$psitem.messageid -eq $mid}) | Should -be $true -Because "Recommended Agent Alerts to exists http://blog.extreme-advice.com/2013/01/29/list-of-errors-and-severity-level-in-sql-server-with-catalog-view-sysmessages/"
                        }
                        It "$psitem should have Message_ID $mid Alert enabled" {
                            ($alerts.Where{$psitem.messageid -eq $mid}) | Should -be $true -Because "Configured alerts should be enabled"
                        }
                        if ($AgentAlertJob) {
                            It "$psitem should have Job name for Message_ID $mid Alert" {
                                ($alerts.Where{$psitem.messageid -eq $mid}).jobname -ne $null | Should -be $true -Because "Should notify by SQL Agent Job"
                            }
                        }
                        if ($AgentAlertNotification) {
                            It "$psitem should have notification for Message_ID $mid Alert" {
                                ($alerts.Where{$psitem.messageid -eq $mid}).HasNotification -in 1, 2, 3, 4, 5, 6, 7 | Should -be $true -Because "Should notify by Agent notifications"
                            }
                        }
                    }
                }
            }
        }
    }
}

# SIG # Begin signature block
# MIINEAYJKoZIhvcNAQcCoIINATCCDP0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUS3BQQfhFX8N9zCc5rEfchMOJ
# Kr2gggpSMIIFGjCCBAKgAwIBAgIQAsF1KHTVwoQxhSrYoGRpyjANBgkqhkiG9w0B
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
# BgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQk0RUhRz09iMbUv8UEynX0Wqpl
# AzANBgkqhkiG9w0BAQEFAASCAQCGCGY1z7BjN8OowIMIpaYhU9Y7OFQ8KyP99vv9
# 33w8sU16VpOhy/fpafkclDQxCDGMebzuOXBbSc8n/Jf7B5VCKfRwaqHwt1UkQdIN
# 3F3dJz+Juun7gU5Bztibz06cRd4KqR0Rscgns71bw/Q2cFIkjfM2PX9YkFQYPMTP
# qA0ijxxcfzR1gSkE1D7kTK94n7KPsOKRZ/8eXcI2BrgVz96T8t49ZqOA3nmx49jG
# H+szEtyR7f/1cCe321OlrLk5ERTGwPkou+0nMN5rJ3+8jrlO9FC7tbYTTugU6yFU
# D5XpNOgPdySpI+mI54P1UDr2p/48n+MVwEguZP0ExxYlbm6j
# SIG # End signature block
