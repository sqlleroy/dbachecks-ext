Function Skip-DbcCheck {    
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        [object[]]$DbcchecksResult        
    )
    Process {
        #Loading the Json Exclusion file
        $Exclusion_File = (Get-PSFConfig dbapolicy.ExclusionsFilePath).Value
        $Exclusions = Get-Content -Path $Exclusion_File -Raw | ConvertFrom-Json                

        #Removing the tests accordingly to the json exclusion file
        $DbcchecksResult | Foreach-Object {
            $_.TestResult = $_.TestResult | Where-Object {
                $currentCheck = $_
                -Not (
                        $Exclusions | Where-Object {                    
                            ($_.TestName -and $currentCheck.Describe -in $_.TestName ) -and `
                            ($_.Instances -and $currentCheck.Parameters.InstanceObject.Name -in $_.Instances ) -and `
                            ($_.($currentCheck.Parameters.Type) -and $currentCheck.Parameters.Target -in $_.($currentCheck.Parameters.Type) )
                        }
                )
            }
        }
    }
}