[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    $cases = @(
        @{ Description = 'no scope supplied'; Scope = $null; ExpectProperties = $false; Verdict = 'omits -Properties entirely' }
        @{ Description = 'a whitespace-only scope'; Scope = '   '; ExpectProperties = $false; Verdict = 'omits -Properties entirely' }
        @{ Description = 'a scope supplied'; Scope = 'CrossPlatform'; ExpectProperties = $true; Verdict = 'passes -Properties carrying the scope' }
    )
}

Describe -Name 'Test step scope branch' -Fixture {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath 'WorkflowStep.Helpers.ps1')
        $ciPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath '.github/workflows/ci.yml'
        $body = Get-WorkflowStepBody -Path $ciPath -Id 'pester'
        # NO CI RUN CAN TELL OMITTED FROM PASSED-EMPTY: A REPO WITH NO PesterScope BEHAVES THE SAME EITHER WAY.
        # A STUB build.ps1 RECORDS HOW IT WAS CALLED, AND ContainsKey MAKES THAT DISTINCTION.
        $stubBuild = @(
            'param('
            '    [System.String] $ProjectPath,'
            '    [System.String] $TaskList,'
            '    [System.Collections.Hashtable] $Properties,'
            '    [System.Management.Automation.SwitchParameter] $ResolveDependency'
            ')'
            '$record = [ordered] @{'
            '    ProjectPath   = $ProjectPath'
            '    TaskList      = $TaskList'
            '    HasProperties = $PSBoundParameters.ContainsKey(''Properties'')'
            '    PesterScope   = if ($Properties) { $Properties[''PesterScope''] } else { $null }'
            '}'
            '$record | ConvertTo-Json -Depth 2 -Compress | Set-Content -Path ''invocation.json'' -Encoding ''utf8'''
        ) -join [System.Environment]::NewLine
    }
    It -Name '<Verdict> for <Description>' -ForEach $cases -Test {
        $caseRoot = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        $runnerTemp = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        # THE STEP RUNS THE HARNESS MOVED TO $RUNNER_TEMP/harness, AGAINST THE CALLER'S WORKSPACE
        $buildRoot = Join-Path -Path $runnerTemp -ChildPath 'harness' -AdditionalChildPath 'Build'
        New-Item -Path $caseRoot -ItemType 'Directory' -Force | Out-Null
        New-Item -Path $buildRoot -ItemType 'Directory' -Force | Out-Null
        Set-Content -Path (Join-Path -Path $buildRoot -ChildPath 'build.ps1') -Value $stubBuild -Encoding 'utf8'
        $stepParams = @{
            Body             = $body
            WorkingDirectory = $caseRoot
            Environment      = @{ PESTER_SCOPE = $Scope; GITHUB_WORKSPACE = $caseRoot; RUNNER_TEMP = $runnerTemp }
        }
        $result = Invoke-StepBody @stepParams
        $recordPath = Join-Path -Path $caseRoot -ChildPath 'invocation.json'
        $recordPath | Should -Exist -Because ('build.ps1 must have been invoked. Step output: {0}' -f $result.Output)
        $record = Get-Content -Path $recordPath -Raw | ConvertFrom-Json
        $record.ProjectPath | Should -BeExactly $caseRoot
        $record.TaskList | Should -BeExactly 'Test'
        $record.HasProperties | Should -Be $ExpectProperties
        if ($ExpectProperties) {
            $record.PesterScope | Should -BeExactly $Scope
        }
    }
}
