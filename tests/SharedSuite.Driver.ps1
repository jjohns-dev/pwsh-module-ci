# ==============================================================================
# Filename: SharedSuite.Driver.ps1
# Version:  0.1.0 | Updated: 2026-11-13
# Author:   johnsarie27
# ==============================================================================
<#
.SYNOPSIS
    Runs one shared suite from Build/SharedTests against a list of fixture projects.
.DESCRIPTION
    Called in a child pwsh by SharedTests.Tests.ps1, so strict mode, loaded fixture
    modules and Pester state never reach the verification run itself. Each case is a
    separate Invoke-Pester call with the suite's -Data, run in the order given. Writes
    one record per test, plus one per container error, to -OutputPath as JSON.
.PARAMETER SuiteFile
    Path to the shared .tests.ps1 file.
.PARAMETER CasesPath
    JSON file holding an array of { Case, ProjectPath, NoData }.
.PARAMETER OutputPath
    Where to write the result records.
.PARAMETER Strict
    Run the suite under Set-StrictMode -Version Latest, as a consumer with PesterStrictMode does.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [System.String] $SuiteFile,
    [Parameter(Mandatory)]
    [System.String] $CasesPath,
    [Parameter(Mandatory)]
    [System.String] $OutputPath,
    [Parameter()]
    [System.Management.Automation.SwitchParameter] $Strict
)

$ErrorActionPreference = 'Stop'
Import-Module -Name 'Pester' -RequiredVersion '6.2.0'
if ($Strict) {
    Set-StrictMode -Version 'Latest'
}

$records = [System.Collections.Generic.List[System.Object]]::new()
foreach ($case in @(Get-Content -LiteralPath $CasesPath -Raw | ConvertFrom-Json)) {
    $container = if ($case.NoData) {
        New-PesterContainer -Path $SuiteFile
    }
    else {
        New-PesterContainer -Path $SuiteFile -Data @{ ProjectPath = $case.ProjectPath; ModuleName = 'Fixture' }
    }
    $config = New-PesterConfiguration
    $config.Run.Container = @($container)
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'None'
    $result = Invoke-Pester -Configuration $config
    foreach ($test in $result.Tests) {
        $records.Add([PSCustomObject] @{ Case = $case.Case; Test = $test.ExpandedName; Result = $test.Result; Message = [System.String] $test.ErrorRecord })
    }
    foreach ($c in @($result.Containers).Where({ $_.ErrorRecord.Count -gt 0 })) {
        $records.Add([PSCustomObject] @{ Case = $case.Case; Test = '<container>'; Result = 'Error'; Message = [System.String] $c.ErrorRecord })
    }
}
ConvertTo-Json -InputObject @($records) -Depth 4 | Set-Content -LiteralPath $OutputPath
exit 0
