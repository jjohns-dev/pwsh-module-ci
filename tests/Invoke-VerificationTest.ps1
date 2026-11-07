# ==============================================================================
# Filename: Invoke-VerificationTest.ps1
# Version:  0.2.0 | Updated: 2026-11-06
# Author:   johnsarie27
# ==============================================================================
<#
.SYNOPSIS
    Runs the Pester suites that verify the run: blocks shipped in the reusable workflows.
.DESCRIPTION
    Each *.Tests.ps1 beside this file extracts a step body directly out of the
    workflow YAML and runs it, so the code under test is the code that ships
    rather than a copy that can drift away from it.
    The checks under test guard against a build reporting green after collecting
    a fraction of its suite. Their failure mode is silently never firing, which
    is indistinguishable from passing, so each case asserts a direction: some
    must fail the step and some must leave it quiet.
    Exits non-zero if any test fails, no tests are collected, or a dependency
    cannot be imported.
.NOTES
    Cannot cover a step's `if:` condition, which is workflow orchestration rather
    than script logic. That requires a real run with an earlier step failing.
    Dependencies are imported rather than declared with `#Requires -Modules`,
    which would be the house convention. Under `pwsh -File`, a script carrying
    `#Requires -Modules` always exits 0 even when it calls `exit 1`, which would
    make this test permanently green -- the exact failure mode it exists to
    catch. Verified on PowerShell 7.6.6.
    The exit code is set explicitly from the Pester result rather than through
    Run.Exit. The suites start child pwsh processes that exit non-zero by design,
    and under `shell: pwsh` a step exits with whatever $LASTEXITCODE last held.
#>

$ErrorActionPreference = 'Stop'

#region - DEPENDENCIES =========================================================
# A FAILED IMPORT MUST STOP THE RUN AND SAY WHY, WHERE SOMEONE WILL SEE IT
$requiredModules = @(
    @{ Name = 'powershell-yaml'; RequiredVersion = '0.4.12' }
    @{ Name = 'Pester'; RequiredVersion = '6.2.0' }
)

foreach ($module in $requiredModules) {
    try {
        Import-Module @module -ErrorAction Stop
    }
    catch {
        $message = 'Cannot import module [{0}] version [{1}]: {2}' -f $module.Name, $module.RequiredVersion, $PSItem.Exception.Message
        # A WORKFLOW ANNOTATION SHOWS ON THE PR CHECKS SUMMARY, NOT ONLY IN THE RAW LOG
        Write-Output -InputObject ('::error title=Harness dependency missing::{0}' -f $message)
        Write-Error -Message $message -ErrorAction Stop
    }
}

#endregion ====================================================================


#region - RUN THE SUITES =======================================================
# Run.Path IS A STRING ARRAY OPTION; A SCALAR CAN FAIL TO BIND, SO PASS AN ARRAY
$config = New-PesterConfiguration
$config.Run.Path = @($PSScriptRoot)
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

#endregion ====================================================================


#region - REPORT ===============================================================
# AN EMPTY RUN REPORTS NO FAILURES, SO COLLECTING NOTHING MUST FAIL TOO
if ($result.TotalCount -eq 0) {
    Write-Output -InputObject '::error title=No tests collected::The harness collected zero tests.'
    exit 1
}

if ($result.Result -ne 'Passed') {
    $summary = '{0} of {1} test(s) failed; result [{2}].' -f $result.FailedCount, $result.TotalCount, $result.Result
    Write-Output -InputObject ('::error title=Harness failed::{0}' -f $summary)
    exit 1
}

Write-Output -InputObject ('All {0} tests passed.' -f $result.PassedCount)

# EXPLICIT: $LASTEXITCODE STILL HOLDS THE LAST CHILD PROCESS'S NON-ZERO EXIT
exit 0

#endregion ====================================================================
