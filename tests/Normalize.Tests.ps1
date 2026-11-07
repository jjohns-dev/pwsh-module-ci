[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    # THE SINGLE-ENTRY CASE MATTERS MOST: PS.Log PASSES '["ubuntu-latest"]', AND POWERSHELL UNWRAPS
    # ONE-ELEMENT ARRAYS, WHICH WOULD EMIT AN OBJECT WHERE GITHUB NEEDS A JSON ARRAY
    $accepted = @(
        @{ Description = 'a single OS string, the PS.Log shape'; Json = '["ubuntu-latest"]'; ExpectOs = @('ubuntu-latest'); ExpectMinTests = $null }
        @{ Description = 'three OS strings, the default'; Json = '["ubuntu-latest", "windows-latest", "macos-latest"]'; ExpectOs = @('ubuntu-latest', 'windows-latest', 'macos-latest'); ExpectMinTests = $null }
        @{ Description = 'objects carrying per-leg values'; Json = '[{"os":"ubuntu-latest","pesterScope":"CrossPlatform","minTests":986}]'; ExpectOs = @('ubuntu-latest'); ExpectMinTests = 986 }
    )
    $rejected = @(
        @{ Description = 'invalid JSON'; Json = 'not json at all' }
        @{ Description = 'an empty array'; Json = '[]' }
        @{ Description = 'an object with no os key'; Json = '[{"pesterScope":"CrossPlatform"}]' }
    )
}

Describe -Name 'normalize step' -Fixture {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath 'WorkflowStep.Helpers.ps1')
        $ciPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath '.github/workflows/ci.yml'
        $body = Get-WorkflowStepBody -Path $ciPath -Id 'norm'
    }
    It -Name 'emits a JSON array with values intact for <Description>' -ForEach $accepted -Test {
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $caseRoot -ItemType 'Directory' -Force | Out-Null
        $outputFile = Join-Path -Path $caseRoot -ChildPath 'github_output.txt'
        New-Item -Path $outputFile -ItemType 'File' -Force | Out-Null
        $stepParams = @{
            Body             = $body
            WorkingDirectory = $caseRoot
            Environment      = @{ OS_MATRIX = $Json; GITHUB_OUTPUT = $outputFile }
        }
        $result = Invoke-StepBody @stepParams
        $result.Failed | Should -BeFalse -Because $result.Output
        $emitted = ((Get-Content -Path $outputFile -Raw) -replace '^matrix=', '').Trim()
        $emitted | Should -BeLike '`[*' -Because 'a one-element array that collapses to an object breaks the matrix'
        $entries = @($emitted | ConvertFrom-Json)
        ($entries.os -join ',') | Should -BeExactly ($ExpectOs -join ',')
        if ($null -ne $ExpectMinTests) {
            $entries[0].minTests | Should -Be $ExpectMinTests
        }
    }
    It -Name 'rejects <Description>' -ForEach $rejected -Test {
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $caseRoot -ItemType 'Directory' -Force | Out-Null
        $outputFile = Join-Path -Path $caseRoot -ChildPath 'github_output.txt'
        New-Item -Path $outputFile -ItemType 'File' -Force | Out-Null
        $stepParams = @{
            Body             = $body
            WorkingDirectory = $caseRoot
            Environment      = @{ OS_MATRIX = $Json; GITHUB_OUTPUT = $outputFile }
        }
        $result = Invoke-StepBody @stepParams
        $result.Failed | Should -BeTrue -Because $result.Output
    }
}
