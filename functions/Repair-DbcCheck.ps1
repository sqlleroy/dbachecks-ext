Function Repair-DbcCheck {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [object[]]$DbcchecksResult
    )
    begin {
        [String[]]$ExpectedResult = ("Failed", "Fix Failed")
        #Variable to control how to display the message in the Else clause in a foreach loop.
        [string[]]$RepairPFSConfig = @()
    }
    Process {
        Foreach ($Result in $DbcchecksResult) {
            Foreach ($TestResult in ($Result.TestResult | Where-Object {$_.Result -in $ExpectedResult})) {
                $Repair = $TestResult.Parameters.Repair
                $Describe = ($TestResult.Describe).ToLower()

                If (Get-PSFConfigValue -Fullname dbachecks-ext.repair.$Describe) {
                    $Execution = Invoke-Command -ArgumentList $Repair.ArgumentList -ScriptBlock $Repair.ScriptBlock

                    If ($Execution.RepairResult) {
                        $TestResult.Result = "Fixed"
                        Add-Member -Force -InputObject $TestResult -MemberType NoteProperty -Name NewValue -value $Repair.RepairValue
                    }
                    Else {
                        $TestResult.Result = "Fix Failed"
                        Add-Member -Force -InputObject $TestResult -MemberType NoteProperty -Name RepairErrorMsg -value $Execution.RepairErrorMsg
                    }
                    $TestResult
                }
                Else {
                    if ($Describe -notin $RepairPFSConfig) {
                        Write-Host "To repair the failing '$Describe' check, the PSFConfig value of the 'dbachecks-ext.repair.$Describe' must be set as True." -ForegroundColor DarkYellow
                        $RepairPFSConfig += $Describe
                    }
                }
            }
        }  
    }
}