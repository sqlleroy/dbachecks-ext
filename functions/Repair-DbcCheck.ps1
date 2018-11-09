Function Repair-DbcCheck {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [object[]]$DbcchecksResult
    )
    Process {
        Foreach ($Result in $DbcchecksResult) {
            Foreach ($TestResult in ($Result.TestResult | Where-Object {$_.Result -eq "Failed"})) {
                $Fix = $TestResult.Parameters.Fix
                $AutoFix = Invoke-Command -ArgumentList $Fix.ArgumentList -ScriptBlock $Fix.ScriptBlock

                If ($AutoFix) {
                    $TestResult.Result = "Fixed"
                    Add-Member -Force -InputObject $TestResult -MemberType NoteProperty -Name NewValue -value $Fix.TargetValue
                }
                Else {
                    $TestResult.Result = "Fix Failed"
                }
                $TestResult
            }
        }
    }
}