Function Repair-DbcCheck {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [object[]]$DbcchecksResult
    )
    begin {
        [String[]]$ExpectedResult = ("Failed", "Fix Failed")        
    }
    Process {
        $Describe = $DbcchecksResult.TestResult[0].Describe

        If (Get-PSFConfigValue -Fullname dbachecks-ext.repair.$Describe) {
            Foreach ($Result in $DbcchecksResult) {
                Foreach ($TestResult in ($Result.TestResult | Where-Object {$_.Result -in $ExpectedResult})) {
                    $Repair = $TestResult.Parameters.Repair                    
                    
                    If (Invoke-Command -ArgumentList $Repair.ArgumentList -ScriptBlock $Repair.ScriptBlock) {
                        $TestResult.Result = "Fixed"
                        Add-Member -Force -InputObject $TestResult -MemberType NoteProperty -Name NewValue -value $Repair.RepairValue
                    }
                    Else {
                        $TestResult.Result = "Fix Failed"
                    }
                    $TestResult
                }
            }
        }
        Else {
            Write-Host "To repair the failing $Describe, the PSFConfig '"dbachecks-ext.repair.$Describe"' value must be set as True." -ForegroundColor DarkYellow
        }
    }
}