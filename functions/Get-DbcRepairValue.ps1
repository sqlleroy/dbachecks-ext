Function Get-DbcRepairValue {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        $Name,
        [int]$Position = 0
    )
    begin {
        $Name = $Name.ToLower()        
    }
    Process {
        [string[]]$RepairValue = Get-PSFConfigValue -Fullname $Name
        If ($RepairValue) {
            return $RepairValue[$Position]
        }
    }
}
