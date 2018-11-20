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
                $Describe = $TestResult.Describe

                $PSConfig = Get-PSFConfigValue  -name repair.$Describe

                If ($PSConfig)
                {
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
}