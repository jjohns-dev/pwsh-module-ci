[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeAll {
    $template = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'templates' -AdditionalChildPath 'Build', 'build.ps1'

    # THROWAWAY FIXTURE REPOS ONLY: AN EMPTY GLOBAL CONFIG KEEPS THE RUNNER'S OR DEVELOPER'S HOOKS AND SIGNING OUT
    $emptyConfig = Join-Path -Path $TestDrive -ChildPath 'empty.gitconfig'
    Set-Content -Path $emptyConfig -Value ''
    $gitEnvironment = @{
        GIT_CONFIG_GLOBAL   = $emptyConfig
        GIT_AUTHOR_NAME     = 'fixture'
        GIT_AUTHOR_EMAIL    = 'fixture@example.invalid'
        GIT_COMMITTER_NAME  = 'fixture'
        GIT_COMMITTER_EMAIL = 'fixture@example.invalid'
    }
    $savedEnvironment = @{}
    foreach ($k in $gitEnvironment.Keys) {
        $savedEnvironment[$k] = [System.Environment]::GetEnvironmentVariable($k)
        [System.Environment]::SetEnvironmentVariable($k, $gitEnvironment[$k])
    }

    function Invoke-Git {
        $output = git @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message ('git {0} failed: {1}' -f ($args -join ' '), ($output -join ' ')) -ErrorAction 'Stop'
        }
        $output
    }

    # A STUB HARNESS THAT RECORDS EXACTLY WHAT THE SHIM PASSED IT
    $stubHarness = @(
        '[CmdletBinding()]'
        'param ('
        '    [Parameter(Mandatory)] [System.String] $ProjectPath,'
        '    [ValidateSet(''Init'', ''Analyze'', ''Test'', ''Cleanup'', ''Default'')] [System.String[]] $TaskList = ''Default'','
        '    [System.Collections.Hashtable] $Properties,'
        '    [System.Management.Automation.SwitchParameter] $ResolveDependency'
        ')'
        '$record = [ordered] @{'
        '    Version           = ''__VERSION__'''
        '    ProjectPath       = $ProjectPath'
        '    TaskList          = @($TaskList)'
        '    TaskListType      = $TaskList.GetType().FullName'
        '    Properties        = $Properties'
        '    ResolveDependency = $ResolveDependency.IsPresent'
        '}'
        '$record | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $env:SHIM_RECORD'
        'if ($Properties -and $Properties.ContainsKey(''ExitWith'')) { exit ([System.Int32] $Properties.ExitWith) }'
        'exit 0'
    ) -join "`n"

    # A LOCAL BARE REPO STANDS IN FOR GITHUB, WITH v1 AND v1.0.0 ON HARNESS A
    $origin = Join-Path -Path $TestDrive -ChildPath 'origin.git'
    $source = Join-Path -Path $TestDrive -ChildPath 'source'
    Invoke-Git init --quiet --bare --initial-branch=main $origin | Out-Null
    Invoke-Git init --quiet --initial-branch=main $source | Out-Null
    New-Item -Path (Join-Path -Path $source -ChildPath 'Build') -ItemType 'Directory' | Out-Null
    $harnessFile = Join-Path -Path $source -ChildPath 'Build' -AdditionalChildPath 'build.ps1'
    Set-Content -Path $harnessFile -Value $stubHarness.Replace('__VERSION__', 'A')
    Invoke-Git -C $source add -A | Out-Null
    Invoke-Git -C $source commit --quiet -m 'harness A' | Out-Null
    Invoke-Git -C $source tag -a v1 -m 'v1' | Out-Null
    Invoke-Git -C $source tag -a v1.0.0 -m 'v1.0.0' | Out-Null
    Invoke-Git -C $source remote add origin $origin | Out-Null
    Invoke-Git -C $source push --quiet origin main --tags | Out-Null
    $shaA = (Invoke-Git -C $source rev-parse HEAD).Trim()

    # THE SHIM UNDER TEST IS THE TEMPLATE WITH ONLY ITS URL AND CACHE POINTED AT THE FIXTURES
    $cache = Join-Path -Path $TestDrive -ChildPath 'cache'
    $urlLine = '$harnessUrl = ''https://github.com/jjohns-dev/pwsh-module-ci.git'''
    $cacheLine = '$cache = Join-Path -Path ([System.Environment]::GetFolderPath(''LocalApplicationData'')) -ChildPath ''pwsh-module-ci'''
    $templateText = Get-Content -Path $template -Raw
    $shimText = $templateText.Replace($urlLine, ('$harnessUrl = ''{0}''' -f $origin)).Replace($cacheLine, ('$cache = ''{0}''' -f $cache))

    $module = Join-Path -Path $TestDrive -ChildPath 'PS.Fixture'
    New-Item -Path (Join-Path -Path $module -ChildPath 'Build'), (Join-Path -Path $module -ChildPath '.github' -AdditionalChildPath 'workflows') -ItemType 'Directory' -Force | Out-Null
    $shim = Join-Path -Path $module -ChildPath 'Build' -AdditionalChildPath 'build.ps1'
    Set-Content -Path $shim -Value $shimText
    $callerPath = Join-Path -Path $module -ChildPath '.github' -AdditionalChildPath 'workflows', 'ci.yml'
    $callerV1 = @(
        'jobs:'
        '  validate:'
        '    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v1'
    ) -join "`n"
    Set-Content -Path $callerPath -Value $callerV1

    function Read-ShimRecord {
        if (Test-Path -Path $env:SHIM_RECORD) { Get-Content -Path $env:SHIM_RECORD -Raw | ConvertFrom-Json -AsHashtable } else { $null }
    }
}

AfterAll {
    foreach ($k in $savedEnvironment.Keys) {
        [System.Environment]::SetEnvironmentVariable($k, $savedEnvironment[$k])
    }
    # GIT WRITES OBJECT FILES READ-ONLY, WHICH PESTER'S OWN TestDrive CLEANUP CANNOT DELETE ON WINDOWS
    Remove-Item -Path $origin, $source, $cache -Recurse -Force -ErrorAction 'SilentlyContinue'
}

Describe -Name 'Shim template' -Fixture {
    BeforeEach {
        $env:SHIM_RECORD = Join-Path -Path $TestDrive -ChildPath ('record-{0}.json' -f [System.Guid]::NewGuid())
        Set-Content -Path $callerPath -Value $callerV1
    }
    AfterAll {
        Remove-Item -Path 'Env:SHIM_RECORD' -ErrorAction 'SilentlyContinue'
    }
    It -Name 'is only redirected at its URL and cache, so the code under test is the template' -Test {
        $templateText.Contains($urlLine) | Should -BeTrue
        $templateText.Contains($cacheLine) | Should -BeTrue
        $shimText | Should -Not -BeExactly $templateText
    }
    It -Name 'passes the module root as the project path when called with no arguments' -Test {
        & $shim
        $record = Read-ShimRecord
        $record.Version | Should -BeExactly 'A'
        $record.ProjectPath | Should -BeExactly $module
        $record.TaskList | Should -Be @('Default')
    }
    It -Name 'forwards several tasks, a switch and a hashtable with their types intact' -Test {
        & $shim -TaskList 'Analyze', 'Test' -ResolveDependency -Properties @{ PesterScope = 'All' }
        $record = Read-ShimRecord
        $record.TaskList | Should -Be @('Analyze', 'Test')
        $record.TaskListType | Should -BeExactly 'System.String[]'
        $record.ResolveDependency | Should -BeTrue
        $record.Properties.PesterScope | Should -BeExactly 'All'
    }
    It -Name 'binds a positional task name to TaskList' -Test {
        & $shim 'Cleanup'
        (Read-ShimRecord).TaskList | Should -Be @('Cleanup')
    }
    It -Name 'leaves validation to the harness, which rejects an unknown task' -Test {
        { & $shim -TaskList 'Bogus' } | Should -Throw -ExpectedMessage '*Bogus*'
        Read-ShimRecord | Should -BeNullOrEmpty
    }
    It -Name 'resolves the module root when called by path from another directory' -Test {
        Push-Location -Path $TestDrive
        try {
            & $shim -TaskList 'Test'
        }
        finally {
            Pop-Location
        }
        (Read-ShimRecord).ProjectPath | Should -BeExactly $module
    }
    It -Name 'propagates the harness exit code in-session' -Test {
        & $shim -Properties @{ ExitWith = 3 }
        $LASTEXITCODE | Should -Be 3
    }
    It -Name 'propagates the harness exit code through a child pwsh' -Test {
        & pwsh -NoProfile -NonInteractive -Command ('& ''{0}'' -Properties @{{ ExitWith = 5 }}; exit $LASTEXITCODE' -f $shim)
        $LASTEXITCODE | Should -Be 5
    }
    It -Name 'uses the commit an immutable tag names' -Test {
        Set-Content -Path $callerPath -Value $callerV1.Replace('@v1', '@v1.0.0')
        & $shim
        (Read-ShimRecord).Version | Should -BeExactly 'A'
    }
    It -Name 'uses a full SHA pin with a trailing version comment' -Test {
        Set-Content -Path $callerPath -Value $callerV1.Replace('@v1', ('@{0} # v1.0.0' -f $shaA))
        & $shim
        (Read-ShimRecord).Version | Should -BeExactly 'A'
    }
    It -Name 'stops and names the ref when the caller pins one that does not exist' -Test {
        Set-Content -Path $callerPath -Value $callerV1.Replace('@v1', '@v9.9.9')
        { & $shim } | Should -Throw -ExpectedMessage '*`[v9.9.9`]*Nothing was run*'
        Read-ShimRecord | Should -BeNullOrEmpty
    }
    It -Name 'stops when the caller does not reference pwsh-module-ci' -Test {
        Set-Content -Path $callerPath -Value $callerV1.Replace('jjohns-dev/pwsh-module-ci', 'someone/else')
        { & $shim } | Should -Throw -ExpectedMessage '*No jjohns-dev/pwsh-module-ci ci.yml reference*'
        Read-ShimRecord | Should -BeNullOrEmpty
    }
    It -Name 'picks up v1 after a release moves it' -Test {
        Set-Content -Path $harnessFile -Value $stubHarness.Replace('__VERSION__', 'B')
        Invoke-Git -C $source commit --quiet -am 'harness B' | Out-Null
        Invoke-Git -C $source tag -fa v1 -m 'v1 moved' | Out-Null
        Invoke-Git -C $source push --quiet origin main | Out-Null
        Invoke-Git -C $source push --quiet --force origin v1 | Out-Null
        & $shim
        (Read-ShimRecord).Version | Should -BeExactly 'B'
    }
    It -Name 'stops, runs nothing, and names the cache when the fetch fails' -Test {
        $moved = '{0}.unreachable' -f $origin
        Move-Item -Path $origin -Destination $moved
        try {
            { & $shim } | Should -Throw -ExpectedMessage ('*{0}*Nothing was run*' -f $cache)
            Read-ShimRecord | Should -BeNullOrEmpty
        }
        finally {
            Move-Item -Path $moved -Destination $origin
        }
    }
}

Describe -Name 'Test-HarnessShim' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
        $reference = Get-Content -Path $template -Raw
        $lf = $reference -replace "`r`n", "`n"
        function Initialize-ShimCopy ([System.String] $Text) {
            $path = Join-Path -Path $TestDrive -ChildPath ('shim-{0}.ps1' -f [System.Guid]::NewGuid())
            [System.IO.File]::WriteAllText($path, $Text)
            $path
        }
    }
    It -Name 'reports no drift for an identical copy' -Test {
        Test-HarnessShim -ShimPath (Initialize-ShimCopy -Text $lf) -ReferencePath $template | Should -BeTrue
    }
    It -Name 'reports no drift for a CRLF checkout of the same shim' -Test {
        Test-HarnessShim -ShimPath (Initialize-ShimCopy -Text ($lf -replace "`n", "`r`n")) -ReferencePath $template | Should -BeTrue
    }
    It -Name 'reports drift when the shim has been edited' -Test {
        $edited = $lf.Replace('$ErrorActionPreference = ''Stop''', '$ErrorActionPreference = ''Continue''')
        $edited | Should -Not -BeExactly $lf
        Test-HarnessShim -ShimPath (Initialize-ShimCopy -Text $edited) -ReferencePath $template | Should -BeFalse
    }
    It -Name 'reports drift for a change of case only' -Test {
        Test-HarnessShim -ShimPath (Initialize-ShimCopy -Text $lf.ToLowerInvariant()) -ReferencePath $template | Should -BeFalse
    }
    It -Name 'reports no drift when the consumer has no shim' -Test {
        Test-HarnessShim -ShimPath (Join-Path -Path $TestDrive -ChildPath 'absent.ps1') -ReferencePath $template | Should -BeTrue
    }
}
