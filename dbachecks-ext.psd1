#
# Module manifest for module 'dbapolicy'
#
# Generated by: Leandro da Silva
#
# Generated on: 10/24/2018
#
@{
    # Script module or binary module file associated with this manifest.
    RootModule             = 'dbachecks-ext.psm1'

    # Version number of this module.
    ModuleVersion          = '1.0.0'

    # Author of this module
    Author                 = 'Leandro da Silva'

    # Company or vendor of this module
    CompanyName            = ''

    # Copyright statement for this module
    Copyright              = 'Leandro da Silva (@sqlleroy) 2018. All rights reserved.'

    # Description of the functionality provided by this module
    Description            = 'SQL Server framework extension of dbachecks from dbatools allowing to exclude checks that are expected to fail as well as having a way to fix itself without manual intervention.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion      = '5.0'

    # Name of the Windows PowerShell host required by this module
    PowerShellHostName     = ''

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellHostVersion  = ''

    # Minimum version of the .NET Framework required by this module
    DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion             = ''

    # Processor architecture (None, X86, Amd64, IA64) required by this module
    ProcessorArchitecture  = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules        = @(
        @{ ModuleName = 'Pester'; ModuleVersion = '4.3.1' },
        @{ ModuleName = 'dbatools'; ModuleVersion = '0.9.410' }
        @{ ModuleName = 'PSFramework'; ModuleVersion = '0.9.23.82' }
    )

    #Functions to export from this module
    # This are the codes in \functions folder
    FunctionsToExport      = @(
        'Skip-DbcCheck',
        'Repair-DbcCheck'
    )
}