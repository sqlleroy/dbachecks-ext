function Get-DbcTestCase {
	[CmdletBinding()]
	Param (
		[parameter(Mandatory, ValueFromPipeline)]
		[object[]]$InputObject,
		[string[]]$Property,
		[scriptblock]$CheckBlock,
		[scriptblock]$RepairBlock,
		[string]$Type,
		[string]$Target,
		[string]$Name,
        [hashtable]$Arguments,
		$RepairValue,
		$ReferenceValue
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

			$testCaseHash = @{ _ = $iObject }
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

			if ('RepairValue' -notin $testCaseHash.Keys) {
				$testCaseHash += @{ RepairValue = $RepairValue}
			}
			if ('ReferenceValue' -notin $testCaseHash.Keys) {
				$testCaseHash += @{ ReferenceValue = $ReferenceValue}
            }
            if ($Arguments) {
                $testCaseHash += $Arguments
            }
			# Add Param block to the input scriptblocks
			if ($RepairBlock) {
				if ($RepairBlock.ast.FindAll( {$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $true)) {
					Stop-PSFFunction -Message "Param blocks inside ScriptBlocks are not supported" -Continue
				}
				else {
					# Store parameters as arrays for further use
					$paramList = $testCaseHash.Keys
					foreach ($param in $paramList) {
						$argumentList += $testCaseHash.$param
					}
					$fBlock = $RepairBlock.ToString()
					if ($paramList) {
						$fBlock = "param(`$$($paramList -Join ", `$"))`r`n" + $fBlock
					}
					$testCaseHash += @{
						Repair = @{
							ScriptBlock  = $ExecutionContext.InvokeCommand.NewScriptBlock($fBlock)
                            ArgumentList = $argumentList
							RepairValue = $testCaseHash.RepairValue
							ReferenceValue = $testCaseHash.ReferenceValue
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
                # if ($RepairBlock) {
                #     $paramList += 'Repair'
				# }
				$sBlock = $CheckBlock.ToString()
				if ($paramList) {
					$sBlock = "param(`$$($paramList -Join ", `$"))`r`n" + $sBlock
				}
                $outputHash += @{ Test = $ExecutionContext.InvokeCommand.NewScriptBlock($sBlock) }
            }
        }
        $outputHash += @{ TestCases = $testCases}
        $outputHash
	}
}