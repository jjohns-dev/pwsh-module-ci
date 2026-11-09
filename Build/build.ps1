# ==============================================================================
# Filename: build.ps1
# Version:  2.0.0 | Updated: 2026-11-09
# Author:   johnsarie27
# ==============================================================================
<#
.SYNOPSIS
    Builds, analyses and tests a consumer module with the shared harness.
.DESCRIPTION
    The reusable workflows call this from a second checkout of this repo, and the shim in
    each consumer's Build/build.ps1 calls it locally. Both pass the consumer's root as
    -ProjectPath, so the harness never works out the project from its own location.
.PARAMETER ProjectPath
    Root of the consumer module's checkout. It must hold exactly one module manifest.
.PARAMETER TaskList
    psake tasks to run. Default runs Test.
.PARAMETER Parameters
    Passed through to Invoke-psake -parameters.
.PARAMETER Properties
    Passed through to Invoke-psake -properties, e.g. @{ PesterScope = 'CrossPlatform' }.
.PARAMETER ResolveDependency
    Install the pinned build tools and the module's RequiredModules before running.
.EXAMPLE
    ./Build/build.ps1 -ProjectPath ../PS.Log -ResolveDependency -TaskList 'Init'
.NOTES
    Strict mode is deliberately not set here. Set in this script it never reaches psake
    task bodies, but it does reach the consumer's Pester tests (measured 2026-11-09,
    psake 5.0.4, Pester 6.2.0). build.psake.ps1 sets it for the harness's own code.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $ProjectPath,

    [Parameter()]
    [ValidateSet(
        'Default',
        'Init',
        'Setup',
        'CombineFunctionsAndStage',
        'ImportStagingModule',
        'Analyze',
        'Test',
        'CreateBuildArtifact',
        'Cleanup'
    )]
    [System.String[]] $TaskList = 'Default',

    [Parameter()]
    [System.Collections.Hashtable] $Parameters,

    [Parameter()]
    [System.Collections.Hashtable] $Properties,

    [Parameter()]
    [System.Management.Automation.SwitchParameter] $ResolveDependency
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'Harness.Functions.ps1')
$harnessRoot = Split-Path -Path $PSScriptRoot -Parent
$nl = [System.Environment]::NewLine


#region - CONTEXT ==============================================================
# STATE WHICH HARNESS IS BUILDING WHAT, SO EVERY LOG CAN BE TRACED TO A COMMIT
Write-Output -InputObject ('{0}STARTED TASKS: {1}' -f $nl, ($TaskList -join ','))
Write-Output -InputObject ('Harness commit: {0}' -f (Get-HarnessCommit -HarnessRoot $harnessRoot))
Write-Output -InputObject ('PowerShell: {0}' -f $PSVersionTable.PSVersion)

$project = Resolve-HarnessProject -ProjectPath $ProjectPath
Set-HarnessEnvironment -Project $project
Write-Output -InputObject ('Project: {0} [{1}]{2}' -f $project.ModuleName, $project.ProjectPath, $nl)

# A DRIFTED SHIM STILL WORKS, SO WARN RATHER THAN FAIL; THE REFERENCE IS THIS HARNESS'S OWN TEMPLATE
$shimParams = @{
    ShimPath      = Join-Path -Path $project.ProjectPath -ChildPath 'Build' -AdditionalChildPath 'build.ps1'
    ReferencePath = Join-Path -Path $harnessRoot -ChildPath 'templates' -AdditionalChildPath 'Build', 'build.ps1'
}
if (-not (Test-HarnessShim @shimParams)) {
    Write-Warning -Message ('[{0}] differs from the reference shim in pwsh-module-ci templates/Build/build.ps1. Replace it with that copy.' -f $shimParams.ShimPath)
}

#endregion =====================================================================


#region - DEPENDENCIES =========================================================
# BUILD TOOLS ARE PINNED BY THE HARNESS; RUNTIME MODULES COME FROM THE CONSUMER'S MANIFEST AND FLOAT
$dependPath = Join-Path -Path $PSScriptRoot -ChildPath 'depend.psd1'
if ($ResolveDependency) {
    $dependency = @(Get-HarnessDependency -DependPath $dependPath -ManifestPath $project.ManifestPath)
    Install-HarnessDependency -Dependency $dependency
}
else {
    Write-Output -InputObject ('Skipping dependency resolution.{0}' -f $nl)
}

# IMPORTED AT THE PINNED VERSIONS, NOT DECLARED WITH #Requires: THEY MAY ONLY EXIST AFTER -ResolveDependency,
# AND AUTOLOADING WOULD OTHERWISE PICK WHATEVER VERSION IS NEWEST ON THE MACHINE
$buildTools = Import-PowerShellDataFile -LiteralPath $dependPath
foreach ($name in $buildTools.Keys) {
    $importParams = @{
        Name            = $name
        RequiredVersion = $buildTools[$name]
        Force           = $true
        ErrorAction     = 'Stop'
    }
    try {
        Import-Module @importParams
    }
    catch {
        $message = 'Cannot import build tool [{0}] version [{1}]. Run with -ResolveDependency to install it. {2}' -f $name, $buildTools[$name], $PSItem.Exception.Message
        Write-Error -Message $message -ErrorAction 'Stop'
    }
}
$loaded = foreach ($name in ($buildTools.Keys | Sort-Object)) {
    '{0} {1}' -f $name, @(Get-Module -Name $name)[0].Version
}
Write-Output -InputObject ('Build tools: {0}{1}' -f ($loaded -join ', '), $nl)

#endregion =====================================================================


#region - RUN ==================================================================
# THE BUILD FILE IS THE HARNESS'S OWN; PROJECT DETAILS REACH IT THROUGH THE ENVIRONMENT
$invokePsakeParams = @{
    buildFile = Join-Path -Path $PSScriptRoot -ChildPath 'build.psake.ps1'
    taskList  = $TaskList
    nologo    = $true
}
if ($Parameters) {
    $invokePsakeParams['parameters'] = $Parameters
}
if ($Properties) {
    $invokePsakeParams['properties'] = $Properties
}
Invoke-psake @invokePsakeParams

Write-Output -InputObject ('{0}FINISHED TASKS: {1}' -f $nl, ($TaskList -join ','))
exit ([System.Int32] (-not $psake.build_success))

#endregion =====================================================================
