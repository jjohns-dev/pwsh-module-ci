[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    $workflows = @(
        @{ File = 'ci.yml'; Job = 'validate' }
        @{ File = 'release.yml'; Job = 'release' }
        @{ File = 'pssa-sarif.yml'; Job = 'analyze' }
    )
    $buildCallers = @(
        @{ File = 'ci.yml'; Job = 'validate'; Tasks = @('Init', 'CombineFunctionsAndStage', 'Analyze', 'Test') }
        @{ File = 'release.yml'; Job = 'release'; Tasks = @('Init', 'CombineFunctionsAndStage', 'Analyze', 'Test', 'CreateBuildArtifact') }
    )
}

BeforeAll {
    $workflowRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath '.github' -AdditionalChildPath 'workflows'
    function Get-WorkflowJob ([System.String] $File, [System.String] $Job) {
        $document = ConvertFrom-Yaml -Yaml (Get-Content -Path (Join-Path -Path $workflowRoot -ChildPath $File) -Raw)
        $document['jobs'][$Job]
    }
}

Describe -Name 'Harness checkout in <File>' -ForEach $workflows -Fixture {
    BeforeAll {
        $steps = @((Get-WorkflowJob -File $File -Job $Job)['steps'])
        $harnessSteps = @($steps.Where({ $_['with'] -and $_['with']['path'] -eq '.harness' }))
    }
    It -Name 'checks the harness out exactly once' -Test {
        $harnessSteps | Should -HaveCount 1
    }
    It -Name 'checks out the workflow''s own repository at the workflow''s own commit' -Test {
        $harnessSteps[0]['with']['repository'] | Should -BeExactly '${{ job.workflow_repository }}'
        $harnessSteps[0]['with']['ref'] | Should -BeExactly '${{ job.workflow_sha }}'
    }
    It -Name 'leaves no credentials in the harness checkout' -Test {
        $harnessSteps[0]['with']['persist-credentials'] | Should -BeFalse
    }
    It -Name 'uses the same pinned checkout action as the caller checkout' -Test {
        $harnessSteps[0]['uses'] | Should -BeExactly $steps[0]['uses']
        $harnessSteps[0]['uses'] | Should -Match '@[0-9a-f]{40}$'
    }
}

Describe -Name 'Harness location in <File>' -ForEach $workflows -Fixture {
    BeforeAll {
        $steps = @((Get-WorkflowJob -File $File -Job $Job)['steps'])
        $checkoutIndex = $steps.IndexOf(@($steps.Where({ $_['with'] -and $_['with']['path'] -eq '.harness' }))[0])
        $moveSteps = @($steps.Where({ "$($_['run'])" -match 'Move-Item\s+-LiteralPath\s+''\.harness''\s+-Destination\s+\(Join-Path\s+-Path\s+\$env:RUNNER_TEMP\s+-ChildPath\s+''harness''\)' }))
        $harnessUsers = @($steps.Where({ "$($_['run'])" -match 'RUNNER_TEMP/harness/' }))
    }
    It -Name 'moves the harness out of the workspace exactly once' -Test {
        $moveSteps | Should -HaveCount 1
    }
    It -Name 'moves it right after checking it out, before any step uses it' -Test {
        $steps.IndexOf($moveSteps[0]) | Should -Be ($checkoutIndex + 1)
        $harnessUsers.Count | Should -BeGreaterThan 0
        foreach ($user in $harnessUsers) {
            $steps.IndexOf($user) | Should -BeGreaterThan $steps.IndexOf($moveSteps[0])
        }
    }
    It -Name 'never runs anything from .harness/ inside the workspace' -Test {
        $steps.Where({ "$($_['run'])" -match '\.harness[\\/]' }) | Should -HaveCount 0
    }
}

Describe -Name 'Build calls in <File>' -ForEach $buildCallers -Fixture {
    BeforeAll {
        $runBodies = @((Get-WorkflowJob -File $File -Job $Job)['steps'].Where({ $_['run'] }).ForEach({ $_['run'] }))
        $harnessCalls = @($runBodies.Where({ $_ -match 'RUNNER_TEMP/harness/Build/build\.ps1' }))
    }
    It -Name 'never runs the consumer''s Build/build.ps1, which is the shim' -Test {
        $runBodies.Where({ $_ -match '(^|[\s(])\./Build/build\.ps1' }) | Should -HaveCount 0
    }
    It -Name 'passes the caller''s workspace as the project path on every harness call' -Test {
        $harnessCalls.Count | Should -BeGreaterThan 0
        $harnessCalls.Where({ $_ -notmatch 'ProjectPath\s*=?\s*\$env:GITHUB_WORKSPACE' }) | Should -HaveCount 0
    }
    It -Name 'runs every expected task through the harness' -Test {
        $joined = $harnessCalls -join "`n"
        foreach ($task in $Tasks) {
            $joined | Should -Match ('''{0}''' -f $task) -Because ('task {0} must be run' -f $task)
        }
    }
}

Describe -Name 'release.yml dry run' -Fixture {
    BeforeAll {
        $document = ConvertFrom-Yaml -Yaml (Get-Content -Path (Join-Path -Path $workflowRoot -ChildPath 'release.yml') -Raw)
        $steps = @($document['jobs']['release']['steps'])
    }
    It -Name 'declares a boolean dry-run input that defaults to false' -Test {
        $dryRun = $document['on']['workflow_call']['inputs']['dry-run']
        $dryRun['type'] | Should -BeExactly 'boolean'
        $dryRun['default'] | Should -BeFalse
    }
    It -Name 'skips only the publishing step on a dry run' -Test {
        $gated = @($steps.Where({ "$($_['if'])" -match 'inputs\.dry-run' }))
        $gated | Should -HaveCount 1
        $gated[0]['uses'] | Should -Match '^softprops/action-gh-release@'
    }
    It -Name 'still verifies the results and uploads the artifact on a dry run' -Test {
        $verify = $steps.Where({ $_['name'] -eq 'Verify Pester results' })[0]
        $upload = $steps.Where({ "$($_['uses'])" -match '^actions/upload-artifact@' })[0]
        "$($verify['if'])" | Should -Not -Match 'dry-run'
        "$($upload['if'])" | Should -Not -Match 'dry-run'
    }
}

Describe -Name 'pssa-sarif.yml' -Fixture {
    BeforeAll {
        $document = ConvertFrom-Yaml -Yaml (Get-Content -Path (Join-Path -Path $workflowRoot -ChildPath 'pssa-sarif.yml') -Raw)
        $run = @($document['jobs']['analyze']['steps'].Where({ $_['name'] -eq 'Run PSScriptAnalyzer' }))[0]['run']
    }
    It -Name 'no longer takes a settings path input' -Test {
        $document['on']['workflow_call'] | Should -BeNullOrEmpty
    }
    It -Name 'analyses the caller''s workspace through the harness' -Test {
        $run | Should -Match 'Invoke-HarnessAnalysis -ProjectPath \$env:GITHUB_WORKSPACE'
        $run | Should -Not -Match 'Invoke-ScriptAnalyzer'
    }
    It -Name 'takes the PSScriptAnalyzer version from the harness pin, not a literal' -Test {
        $run | Should -Match 'RUNNER_TEMP/harness/Build/depend\.psd1'
        $run | Should -Not -Match '1\.2\d\.\d'
    }
}
