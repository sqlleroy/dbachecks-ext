Function Skip-DbcCheck {    
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [object[]]$DbcchecksResult        
    )
    Process {
        # Loading the Json Exclusion file
        $Exclusion_File = (Get-PSFConfig dbachecks-ext.exclusion.filepath).Value
        $Exclusions = Get-Content -Path $Exclusion_File -Raw | ConvertFrom-Json

        # Collecting info regarding the number of the affected rows
        $TestsSkipped = $DbcchecksResult | Foreach-Object {
            $_.TestResult | Where-Object {
                $currentCheck = $_
                If (($currentCheck.Parameters).Count -gt 0) {
                    ($Exclusions | Where-Object {                    
                            (-not $_.TestName -or ($_.TestName -and $currentCheck.Describe -in $_.TestName)) -and `
                            (-not $_.Instances -or ($_.Instances -and $currentCheck.Parameters.SQLInstance -in $_.Instances)) -and `
                            (-not $_.($currentCheck.Parameters.Type) -or ($_.($currentCheck.Parameters.Type) -and $currentCheck.Parameters.Name -in $_.($currentCheck.Parameters.Type)))                           
                        }
                    )
                }
            }
        }

        # Removing the tests accordingly to the json exclusion file
        $DbcchecksResult | Foreach-Object {
            $_.TestResult = $_.TestResult | Where-Object {
                $currentCheck = $_
                If (($currentCheck.Parameters).Count -gt 0) {
                    -Not (
                            $Exclusions | Where-Object {                    
                                (-not $_.TestName -or ($_.TestName -and $currentCheck.Describe -in $_.TestName)) -and `
                                (-not $_.Instances -or ($_.Instances -and $currentCheck.Parameters._.Parent.Name -in $_.Instances)) -and `
                                (-not $_.($currentCheck.Parameters.Type) -or ($_.($currentCheck.Parameters.Type) -and $currentCheck.Parameters.Name -in $_.($currentCheck.Parameters.Type)))                           
                            }
                    )
                }
            }
        }

        If ($TestsSkipped) {
            Write-host "#"$TestsSkipped.Count "tests were skipped." -ForegroundColor DarkYellow
        }
        Else {
            Write-host "There are no tests to be skipped." -ForegroundColor DarkYellow
        }

    }
}