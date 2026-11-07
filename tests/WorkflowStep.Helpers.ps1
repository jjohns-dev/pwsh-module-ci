# ==============================================================================
# Filename: WorkflowStep.Helpers.ps1
# Version:  0.1.0 | Updated: 2026-11-06
# Author:   johnsarie27
# ==============================================================================
# Dot-sourced by the *.Tests.ps1 files beside it. Requires powershell-yaml to be
# loaded already; Invoke-VerificationTest.ps1 imports it and fails loudly if it
# cannot.

function Get-WorkflowStepBody {
    <#
    .SYNOPSIS
        Returns the run: body of exactly one step in a workflow file.
    .PARAMETER Path
        Path to the workflow YAML file.
    .PARAMETER Name
        The step's name: value.
    .PARAMETER Id
        The step's id: value.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [System.String] $Path,
        [Parameter(Mandatory, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Name,
        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Id
    )

    $key = $PSCmdlet.ParameterSetName.ToLower()
    $value = if ($key -eq 'name') { $Name } else { $Id }
    $document = ConvertFrom-Yaml -Yaml (Get-Content -Path $Path -Raw)

    $bodies = foreach ($job in $document['jobs'].Values) {
        foreach ($step in $job['steps']) {
            if ($step[$key] -eq $value) {
                $step['run']
            }
        }
    }

    # EXACTLY ONE: A RENAMED OR DUPLICATED STEP MUST FAIL HERE, NOT TEST THE WRONG BODY
    $found = @($bodies)
    if ($found.Count -ne 1) {
        $message = 'Expected exactly one step with {0} [{1}] in [{2}], found {3}.'
        Write-Error -Message ($message -f $key, $value, $Path, $found.Count) -ErrorAction Stop
    }

    $found[0]
}

function Invoke-StepBody {
    <#
    .SYNOPSIS
        Runs a workflow step body in a child pwsh, from a given directory, with the given environment.
    .PARAMETER Body
        The run: body to execute.
    .PARAMETER WorkingDirectory
        Directory to run from. Steps resolve paths such as Artifacts/ and Build/ relative to it.
    .PARAMETER Environment
        Variables to set for the child only. A $null value leaves the variable unset.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Body,
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [System.String] $WorkingDirectory,
        [System.Collections.Hashtable] $Environment = @{}
    )

    # A CHILD PROCESS, NOT DOT-SOURCING: STEP BODIES CALL exit, WHICH WOULD END PESTER
    $scriptPath = Join-Path -Path $WorkingDirectory -ChildPath 'Invoke-Step.ps1'
    Set-Content -Path $scriptPath -Value $Body -Encoding 'utf8'

    # A NON-ZERO EXIT IS THE RESULT BEING MEASURED, NOT AN ERROR TO RETHROW
    $PSNativeCommandUseErrorActionPreference = $false

    # THE CHILD INHERITS THIS PROCESS'S ENVIRONMENT, SO RESTORE IT OR IT LEAKS INTO THE NEXT TEST
    $saved = @{}
    foreach ($key in $Environment.Keys) {
        $saved[$key] = [System.Environment]::GetEnvironmentVariable($key)
        [System.Environment]::SetEnvironmentVariable($key, $Environment[$key])
    }

    Push-Location -Path $WorkingDirectory
    try {
        $output = & pwsh -NoProfile -File $scriptPath 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
        foreach ($key in $Environment.Keys) {
            [System.Environment]::SetEnvironmentVariable($key, $saved[$key])
        }
    }

    [PSCustomObject] @{
        ExitCode = $exitCode
        Failed   = ($exitCode -ne 0)
        Output   = $output
    }
}
