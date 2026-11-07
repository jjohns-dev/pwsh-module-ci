[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    # SHOULDFAIL IS THE POINT OF EACH CASE: A CHECK THAT NEVER FIRES LOOKS LIKE A PASS
    $cases = @(
        @{ Description = 'container error with FailedCount 0'; Fixture = 'Test-FalseGreen.xml'; MinTests = $null; ShouldFail = $true }
        @{ Description = 'healthy run'; Fixture = 'Test-Healthy.xml'; MinTests = $null; ShouldFail = $false }
        @{ Description = 'no tests collected'; Fixture = 'Test-ZeroTests.xml'; MinTests = $null; ShouldFail = $true }
        @{ Description = 'genuine assertion failures'; Fixture = 'Test-Failures.xml'; MinTests = $null; ShouldFail = $false }
        @{ Description = 'NUnit root element'; Fixture = 'Test-NUnitRoot.xml'; MinTests = $null; ShouldFail = $true }
        @{ Description = 'malformed count attributes'; Fixture = 'Test-MalformedCounts.xml'; MinTests = $null; ShouldFail = $true }
        @{ Description = 'no result file at all'; Fixture = $null; MinTests = $null; ShouldFail = $true }
        @{ Description = 'below min-tests floor'; Fixture = 'Test-Healthy.xml'; MinTests = 433; ShouldFail = $true }
        @{ Description = 'exactly at min-tests floor'; Fixture = 'Test-Healthy.xml'; MinTests = 432; ShouldFail = $false }
        @{ Description = 'min-tests 0 disables the floor'; Fixture = 'Test-Healthy.xml'; MinTests = 0; ShouldFail = $false }
        # THE REGRESSION THIS STEP EXISTS TO CATCH: 'tests' IS UNCHANGED, THE SUITE STOPPED RUNNING
        @{ Description = 'mass skip: collected meets the floor but executed does not'; Fixture = 'Test-MassSkip.xml'; MinTests = 432; ShouldFail = $true }
        @{ Description = 'mass skip: executed exactly at the floor'; Fixture = 'Test-MassSkip.xml'; MinTests = 332; ShouldFail = $false }
        @{ Description = 'some skips, executed still clears the floor'; Fixture = 'Test-SomeSkipped.xml'; MinTests = 400; ShouldFail = $false }
        @{ Description = 'some skips, executed falls below the floor'; Fixture = 'Test-SomeSkipped.xml'; MinTests = 425; ShouldFail = $true }
    )
    foreach ($case in $cases) {
        $case.Verdict = if ($case.ShouldFail) { 'fails' } else { 'stays quiet' }
    }
}

Describe -Name 'Verify Pester results step' -Fixture {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath 'WorkflowStep.Helpers.ps1')
        $workflowRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath '.github/workflows'
        $fixtureRoot = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures'
        $ciBody = Get-WorkflowStepBody -Path (Join-Path -Path $workflowRoot -ChildPath 'ci.yml') -Name 'Verify Pester results'
        $releaseBody = Get-WorkflowStepBody -Path (Join-Path -Path $workflowRoot -ChildPath 'release.yml') -Name 'Verify Pester results'
    }
    It -Name 'is identical in ci.yml and release.yml' -Test {
        $releaseBody | Should -BeExactly $ciBody -Because 'both workflows ship the same check, and silent divergence is the hazard'
    }
    It -Name '<Verdict> when <Description>' -ForEach $cases -Test {
        # THE STEP RESOLVES ARTIFACTS RELATIVE TO THE WORKING DIRECTORY, SO EACH CASE GETS ITS OWN
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        $artifactRoot = Join-Path -Path $caseRoot -ChildPath 'Artifacts'
        New-Item -Path $artifactRoot -ItemType 'Directory' -Force | Out-Null
        if ($Fixture) {
            $copyParams = @{
                Path        = Join-Path -Path $fixtureRoot -ChildPath $Fixture
                Destination = Join-Path -Path $artifactRoot -ChildPath $Fixture
            }
            Copy-Item @copyParams
        }
        $stepParams = @{
            Body             = $ciBody
            WorkingDirectory = $caseRoot
            Environment      = @{ MIN_TESTS = $MinTests }
        }
        $result = Invoke-StepBody @stepParams
        $result.Failed | Should -Be $ShouldFail -Because $result.Output
    }
}
