function Get-DbcTestCase {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        [string[]]$Property,
        [scriptblock]$CheckBlock,
        [scriptblock]$FixBlock,
        [string]$Type,
        [string]$Target,
        [string]$Name
    )
    begin {

    }
    process {
        foreach ($iObject in $InputObject) {
            # Get type name from the input object if missing
            if (!$Type) { $Type = $iObject.GetType().Name.Split('.')[-1] }
            # Get target if not specified
            if (!$Target) { $Target = [string]$iObject}
            # Construct output hashtable
            $outputHash = @{ InputObject = $iObject }
            $arguments = @()
            if ($Property) {
                $parsedObject = $iObject | Select-PSFObject -Property $Property
                foreach ($param in $parsedObject.psobject.Properties.Name) {
                    $outputHash += @{ $param = $parsedObject.$param }
                }
            }
            if ('Type' -notin $outputHash.Keys) {
                $outputHash += @{ Type = $Type }
            }
            if ('Target' -notin $outputHash.Keys) {
                $outputHash += @{ Target = $Target }
            }
            if ($Name -and 'Name' -notin $outputHash.Keys) {
                $outputHash += @{ Name = $Name }
            }
            # Store parameters as arrays for further use
            $paramList = $outputHash.Keys
            foreach ($param in $paramList) {
                $arguments += $outputHash.$param
            }
            # Add Param block to the input scriptblocks
            $paramBlock = "param(`$$($paramList -Join ", `$"))`r`n"
            if ($CheckBlock) {
                if ($CheckBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $true)) {
                    Stop-PSFFunction -Message "Param blocks inside ScriptBlocks are not supported" -Continue
                }
                else {
                    $outputHash += @{ Test = $ExecutionContext.InvokeCommand.NewScriptBlock($paramBlock + $CheckBlock.ToString()) }
                }
            }
            if ($FixBlock) {
                if ($FixBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $true)) {
                    Stop-PSFFunction -Message "Param blocks inside ScriptBlocks are not supported" -Continue
                }
                else {
                    $outputHash += @{ 
                        Fix = @{
                            ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($paramBlock + $CheckBlock.ToString()) 
                            ArgumentList = $arguments
                        }
                    }
                }
            }
            $outputHash
        }
    }
    end {

    }
}