Function Repair-DbcCheck {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [object[]]$DbcchecksResult
    )
    begin {
        [String[]]$ExpectedResult = ("Failed", "Fix Failed")
        #Variable to control how to display the message in the Else clause in case there is no PSConfig defined for an specific Describe
        [string[]]$RepairPFSConfig = @()
        #Variable to control how to display the message in the Else clause in case $TestResult.Parameters is empty
        [string[]]$Describes = @()
    }
    Process {
        Foreach ($Result in $DbcchecksResult) {
            Foreach ($TestResult in ($Result.TestResult | Where-Object {$_.Result -in $ExpectedResult})) {
                If (($TestResult.Parameters).Count -gt 0) {

                    $Repair = $TestResult.Parameters.Repair
                    $Describe = ($TestResult.Describe).ToLower()

                    If (Get-PSFConfigValue -Fullname dbachecks-ext.repair.$Describe) {
                        Try {
                            $Execution = Invoke-Command -ArgumentList $Repair.ArgumentList -ScriptBlock $Repair.ScriptBlock
                        }
                        catch {
                            # Return Exception Message to the Repair-DbcCheck function when failing to change the setting
                            $RepairErrorMsg = $Execution.Exception.Message
                        }

                        If ($Execution){
                            $TestResult.Result = "Fixed"
                            Add-Member -Force -InputObject $TestResult -MemberType NoteProperty -Name NewValue -value $Repair.RepairValue
                            $TestResult
                        }
                        Elseif ($RepairErrorMsg) {
                            $TestResult.Result = "Fix Failed"
                            Add-Member -Force -InputObject $TestResult -MemberType NoteProperty -Name RepairErrorMsg -value $RepairErrorMsg
                            $TestResult
                        }
                        Else {
                            Write-host "There are no tests to be repaired." -ForegroundColor DarkYellow
                        }                        
                    }
                    Else {
                        if ($Describe -notin $RepairPFSConfig) {
                            Write-Host "To repair the failing '$Describe' check, the PSFConfig value of the 'dbachecks-ext.repair.$Describe' must be set as True." -ForegroundColor DarkYellow
                            $RepairPFSConfig += $Describe
                        }
                    }
                }
                Else {
                    If ($TestResult.Describe -notin $Describes) {
                        Write-Host "The TestResult's 'Parameters' member is empty for the '$($TestResult.Describe)' check. Repair function is supported by the dbachecks-ext module." -ForegroundColor DarkYellow
                        $Describes += $TestResult.Describe
                    }
                }
            }
        }  
    }
}