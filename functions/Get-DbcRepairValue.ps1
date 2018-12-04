Function Get-DbcRepairValue {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        $Name,
        $ArrayPosition
    )
    begin {
        $Name = $Name.ToLower()
        if (!$ArrayPosition) {
            $ArrayPosition = 0
        }
    }
    Process {
        [string[]]$RepairValue = Get-PSFConfigValue -Fullname $Name
        If ($RepairValue) {
            return $RepairValue[$ArrayPosition]
        }
    }
}
