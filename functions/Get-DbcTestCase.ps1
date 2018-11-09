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
		[string]$Name,
        [hashtable]$Arguments,
		$TargetValue
	)
	begin {
        $outputHash = @{}
        $testCases = @()
        if ($Name) {
            $outputHash += @{ Name = $Name }
        }
	}
	process {
		foreach ($iObject in $InputObject) {
			# Get type name from the input object if missing
			if (!$Type) { $Type = $iObject.GetType().Name.Split('.')[-1] }
			# Get target if not specified
            if ($Target) { $currentTarget = $Target }
            else { $currentTarget = [string]$iObject}
            # Construct output hashtable

			$testCaseHash = @{ InputObject = $iObject }
			$argumentList = @()
			if ($Property) {
				$parsedObject = $iObject | Select-PSFObject -Property $Property
				foreach ($param in $parsedObject.psobject.Properties.Name) {
					$testCaseHash += @{ $param = $parsedObject.$param }
				}
			}
			if ('Type' -notin $testCaseHash.Keys) {
				$testCaseHash += @{ Type = $Type }
			}
			if ('Target' -notin $testCaseHash.Keys) {
				$testCaseHash += @{ Target = $currentTarget }
			}

			if ('TargetValue' -notin $testCaseHash.Keys) {
				$testCaseHash += @{ TargetValue = $TargetValue}
            }
            if ($Arguments) {
                $testCaseHash += $Arguments
            }
			# Add Param block to the input scriptblocks
			if ($FixBlock) {
				if ($FixBlock.ast.FindAll( {$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $true)) {
					Stop-PSFFunction -Message "Param blocks inside ScriptBlocks are not supported" -Continue
				}
				else {
					# Store parameters as arrays for further use
					$paramList = $testCaseHash.Keys
					foreach ($param in $paramList) {
						$argumentList += $testCaseHash.$param
					}
					$paramBlock = "param(`$$($paramList -Join ", `$"))`r`n"
					$testCaseHash += @{
						Fix = @{
							ScriptBlock  = $ExecutionContext.InvokeCommand.NewScriptBlock($paramBlock + $FixBlock.ToString())
                            ArgumentList = $argumentList
                            TargetValue = $testCaseHash.TargetValue
						}
					}
				}
			}
			$testCases += $testCaseHash
		}
	}
	end {
        if ($CheckBlock) {
            if ($CheckBlock.ast.FindAll( {$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $true)) {
                Stop-PSFFunction -Message "Param blocks inside ScriptBlocks are not supported" -Continue
            }
            else {
                $paramList = $testCases[0].Keys
                # if ($FixBlock) {
                #     $paramList += 'Fix'
                # }
                $paramBlock = "param(`$$($paramList -Join ", `$"))`r`n"
                $outputHash += @{ Test = $ExecutionContext.InvokeCommand.NewScriptBlock($paramBlock + $CheckBlock.ToString()) }
            }
        }
        $outputHash += @{ TestCases = $testCases}
        $outputHash
	}
}