$moduleCatalog = Get-Content "$PSScriptRoot\internal\json\dbachecks-ext.json" -Raw | ConvertFrom-Json

foreach ($function in $moduleCatalog.Functions) {
    . "$PSScriptRoot\$function"
}

# defining defaults
Set-PSFConfig -FullName dbachecks-ext.ExclusionsFilePath -Value "$PSScriptRoot\config\Exclusions\Exclusions.json"  -Initialize -Description "Exclusion file"
