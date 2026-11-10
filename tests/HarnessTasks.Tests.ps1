[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeAll {
    $buildScript = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'build.ps1'
    $cleanFunction = 'function Get-Fixture { [CmdletBinding()] param () ''ok'' }'
    $passingTest = 'Describe -Name ''fixture'' -Fixture { It -Name ''passes'' -Test { $true | Should -BeTrue } }'

    function Initialize-FixtureModule {
        param (
            [System.String] $FunctionBody = $cleanFunction,
            [System.Collections.Hashtable] $Tests = @{ 'Get-Fixture.tests.ps1' = $passingTest },
            [System.String] $Settings,
            [System.Management.Automation.SwitchParameter] $NoPublic,
            [System.Management.Automation.SwitchParameter] $EmptyPublic,
            [System.Management.Automation.SwitchParameter] $NoPrivate,
            [System.Management.Automation.SwitchParameter] $WithDocumentation
        )
        $root = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $root -ItemType 'Directory' | Out-Null
        $manifestParams = @{
            Path              = Join-Path -Path $root -ChildPath 'Fixture.psd1'
            RootModule        = 'Fixture.psm1'
            ModuleVersion     = '1.2.3'
            FunctionsToExport = 'Get-Fixture'
            CmdletsToExport   = @()
            AliasesToExport   = @()
            VariablesToExport = @()
        }
        New-ModuleManifest @manifestParams
        $loader = 'foreach ($f in @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath ''*'') -Include ''*.ps1'' -Recurse)) { . $f.FullName }'
        Set-Content -Path (Join-Path -Path $root -ChildPath 'Fixture.psm1') -Value $loader
        Set-Content -Path (Join-Path -Path $root -ChildPath 'README.md') -Value '# Fixture'
        if (-not $NoPublic) {
            $public = New-Item -Path (Join-Path -Path $root -ChildPath 'Public') -ItemType 'Directory'
            if (-not $EmptyPublic) {
                Set-Content -Path (Join-Path -Path $public -ChildPath 'Get-Fixture.ps1') -Value $FunctionBody
            }
        }
        if (-not $NoPrivate) {
            $private = New-Item -Path (Join-Path -Path $root -ChildPath 'Private') -ItemType 'Directory'
            Set-Content -Path (Join-Path -Path $private -ChildPath 'Get-Helper.ps1') -Value 'function Get-Helper { [CmdletBinding()] param () ''helper'' }'
        }
        if ($WithDocumentation) {
            $docs = New-Item -Path (Join-Path -Path $root -ChildPath 'Documentation') -ItemType 'Directory'
            Set-Content -Path (Join-Path -Path $docs -ChildPath 'index.md') -Value '# stale'
        }
        $unit = New-Item -Path (Join-Path -Path $root -ChildPath 'Tests' -AdditionalChildPath 'Unit') -ItemType 'Directory' -Force
        foreach ($name in $Tests.Keys) {
            Set-Content -Path (Join-Path -Path $unit -ChildPath $name) -Value $Tests[$name]
        }
        if ($Settings) {
            $build = New-Item -Path (Join-Path -Path $root -ChildPath 'Build') -ItemType 'Directory'
            Set-Content -Path (Join-Path -Path $build -ChildPath 'harness.psd1') -Value ('@{{ {0} }}' -f $Settings)
        }
        $root
    }

    # A CHILD pwsh ISOLATES psake STATE, STRICT MODE AND THE HARNESS_* VARIABLES FROM THIS RUN
    function Invoke-FixtureBuild {
        param (
            [System.String] $ProjectPath,
            [System.String[]] $TaskList,
            [System.Collections.Hashtable] $Properties
        )
        $propertyText = ''
        if ($Properties) {
            $pairs = foreach ($k in $Properties.Keys) { '{0} = ''{1}''' -f $k, $Properties[$k] }
            $propertyText = ' -Properties @{{ {0} }}' -f ($pairs -join '; ')
        }
        $driver = Join-Path -Path $TestDrive -ChildPath ('driver-{0}.ps1' -f [System.Guid]::NewGuid())
        $call = '& ''{0}'' -ProjectPath ''{1}'' -TaskList {2}{3}' -f $buildScript, $ProjectPath, ($TaskList -join ','), $propertyText
        Set-Content -Path $driver -Value @($call, 'exit $LASTEXITCODE')
        $output = & pwsh -NoProfile -NonInteractive -File $driver 2>&1
        $text = ($output -join [System.Environment]::NewLine) -replace '\x1b\[[0-9;]*m', ''
        [PSCustomObject] @{
            ExitCode = $LASTEXITCODE
            Output   = (($text -replace '\s*\|\s*', ' ') -replace '\s+', ' ')
        }
    }

    function Get-FixtureJUnit ([System.String] $ProjectPath) {
        $file = Get-ChildItem -Path (Join-Path -Path $ProjectPath -ChildPath 'Artifacts') -Filter 'Test-*.xml' | Select-Object -First 1
        $root = ([System.Xml.XmlDocument] (Get-Content -Path $file.FullName -Raw)).DocumentElement
        [PSCustomObject] @{
            Tests    = [System.Int32] $root.GetAttribute('tests')
            Disabled = [System.Int32] ($root.GetAttribute('disabled') -as [System.Int32])
            Failures = [System.Int32] $root.GetAttribute('failures')
        }
    }
}

Describe -Name 'Staging' -Fixture {
    It -Name 'loads the pinned build-tool versions, not the newest installed' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule) -TaskList 'Init'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike '*Build tools: Pester 6.2.0, psake 5.0.4, PSScriptAnalyzer 1.25.0*'
    }
    It -Name 'stages exactly Public, Private, README.md and the manifest and root module' -Test {
        $project = Initialize-FixtureModule -WithDocumentation
        $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'CombineFunctionsAndStage'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $staged = Get-ChildItem -Path (Join-Path -Path $project -ChildPath 'Staging' -AdditionalChildPath 'Fixture') -Name | Sort-Object
        $staged | Should -Be @('Fixture.psd1', 'Fixture.psm1', 'Private', 'Public', 'README.md')
    }
    It -Name 'stages without Private when the module has none' -Test {
        $project = Initialize-FixtureModule -NoPrivate
        $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'CombineFunctionsAndStage'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Join-Path -Path $project -ChildPath 'Staging' -AdditionalChildPath 'Fixture', 'Private' | Should -Not -Exist
    }
    It -Name 'fails when Public is missing' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -NoPublic) -TaskList 'CombineFunctionsAndStage'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*Required build input not found*Public*'
    }
    It -Name 'fails when Public is empty' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -EmptyPublic) -TaskList 'CombineFunctionsAndStage'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*Required build input directory is empty*Public*'
    }
}

Describe -Name 'Analyze' -Fixture {
    It -Name 'passes a clean module even at the Any threshold' -Test {
        $properties = @{ ScriptAnalysisFailBuildOnSeverityLevel = 'Any' }
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule) -TaskList 'Analyze' -Properties $properties
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }
    It -Name 'fails on an Error-severity finding' -Test {
        $body = 'function Get-Fixture { [CmdletBinding()] param () ConvertTo-SecureString -String ''x'' -AsPlainText -Force }'
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -FunctionBody $body) -TaskList 'Analyze'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*PSScriptAnalyzer finding(s) at or above `[Error`]*'
    }
    It -Name 'passes a Warning-severity finding at the default Error threshold' -Test {
        $body = 'function Get-Fixture { [CmdletBinding()] param () Write-Host -Object ''x'' }'
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -FunctionBody $body) -TaskList 'Analyze'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike '*PSAvoidUsingWriteHost*'
    }
    It -Name 'fails a Warning-severity finding at the Any threshold, the dead gate fixed' -Test {
        $body = 'function Get-Fixture { [CmdletBinding()] param () Write-Host -Object ''x'' }'
        $properties = @{ ScriptAnalysisFailBuildOnSeverityLevel = 'Any' }
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -FunctionBody $body) -TaskList 'Analyze' -Properties $properties
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*at or above `[Any`]*'
    }
    It -Name 'does not report or fail on a rule the repo excludes in harness.psd1' -Test {
        $body = 'function Get-Fixture { [CmdletBinding()] param () ConvertTo-SecureString -String ''x'' -AsPlainText -Force }'
        $settings = 'PSScriptAnalyzerExcludeRules = ''PSAvoidUsingConvertToSecureStringWithPlainText'''
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -FunctionBody $body -Settings $settings) -TaskList 'Analyze'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike '*Excluding rules from Build/harness.psd1: PSAvoidUsingConvertToSecureStringWithPlainText*'
    }
}

Describe -Name 'Test' -Fixture {
    BeforeAll {
        $mixedTests = @{
            'Get-Fixture.tests.ps1'         = $passingTest
            'Upper.Tests.windows.ps1'       = $passingTest
            'Get-Other.tests.windows.ps1'   = $passingTest
        }
        $windowsCount = if ($IsWindows) { 3 } else { 1 }
    }
    It -Name 'runs cross-platform files, plus Windows-only files on Windows, under the default All scope' -Test {
        $project = Initialize-FixtureModule -Tests $mixedTests
        $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'Test'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike ('*PesterScope `[All`]: {0} test file(s)*' -f $windowsCount)
        (Get-FixtureJUnit -ProjectPath $project).Tests | Should -Be $windowsCount
    }
    It -Name 'runs only cross-platform files under CrossPlatform' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -Tests $mixedTests) -TaskList 'Test' -Properties @{ PesterScope = 'CrossPlatform' }
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike '*PesterScope `[CrossPlatform`]: 1 test file(s)*'
    }
    It -Name 'runs only Windows-only files, matched regardless of case, under WindowsOnly' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -Tests $mixedTests) -TaskList 'Test' -Properties @{ PesterScope = 'WindowsOnly' }
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike '*PesterScope `[WindowsOnly`]: 2 test file(s)*'
    }
    It -Name 'rejects an unknown scope' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule) -TaskList 'Test' -Properties @{ PesterScope = 'Linux' }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*Unknown PesterScope `[Linux`]*'
    }
    It -Name 'fails when the scope selects no test files' -Test {
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule) -TaskList 'Test' -Properties @{ PesterScope = 'WindowsOnly' }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*No test files selected*'
    }
    It -Name 'fails the build when a test fails' -Test {
        $failing = 'Describe -Name ''fixture'' -Fixture { It -Name ''fails'' -Test { $false | Should -BeTrue } }'
        $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -Tests @{ 'Get-Fixture.tests.ps1' = $failing }) -TaskList 'Test'
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -BeLike '*Pester result `[Failed`]*'
    }
    Context -Name 'tag exclusion' -Fixture {
        BeforeAll {
            $tagged = 'Describe -Name ''fixture'' -Fixture { It -Name ''passes'' -Test { $true | Should -BeTrue }; It -Name ''network'' -Tag ''Network'' -Test { $false | Should -BeTrue } }'
        }
        It -Name 'runs a tagged test when the repo excludes no tags' -Test {
            $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -Tests @{ 'Get-Fixture.tests.ps1' = $tagged }) -TaskList 'Test'
            $result.ExitCode | Should -Not -Be 0
        }
        It -Name 'skips a tag the repo excludes in harness.psd1' -Test {
            $project = Initialize-FixtureModule -Tests @{ 'Get-Fixture.tests.ps1' = $tagged } -Settings 'PesterExcludeTag = ''Network'''
            $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'Test'
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $junit = Get-FixtureJUnit -ProjectPath $project
            $junit.Tests - $junit.Disabled | Should -Be 1
        }
    }
    Context -Name 'strict mode' -Fixture {
        BeforeAll {
            $loose = 'Describe -Name ''fixture'' -Fixture { It -Name ''reads an unset variable'' -Test { ($neverDefined.Count -eq 0) | Should -BeTrue } }'
        }
        It -Name 'does not reach consumer tests by default' -Test {
            $result = Invoke-FixtureBuild -ProjectPath (Initialize-FixtureModule -Tests @{ 'Get-Fixture.tests.ps1' = $loose }) -TaskList 'Test'
            $result.ExitCode | Should -Be 0 -Because $result.Output
        }
        It -Name 'applies to consumer tests when the repo opts in with PesterStrictMode' -Test {
            $project = Initialize-FixtureModule -Tests @{ 'Get-Fixture.tests.ps1' = $loose } -Settings 'PesterStrictMode = $true'
            $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'Test'
            $result.ExitCode | Should -Not -Be 0
        }
    }
}

Describe -Name 'CreateBuildArtifact' -Fixture {
    It -Name 'zips the staged module under its manifest version and keeps the earlier test results' -Test {
        $project = Initialize-FixtureModule
        $test = Invoke-FixtureBuild -ProjectPath $project -TaskList 'Test'
        $test.ExitCode | Should -Be 0 -Because $test.Output
        $artifact = Invoke-FixtureBuild -ProjectPath $project -TaskList 'CreateBuildArtifact'
        $artifact.ExitCode | Should -Be 0 -Because $artifact.Output
        $zip = Join-Path -Path $project -ChildPath 'Artifacts' -AdditionalChildPath 'Fixture-v1.2.3.zip'
        $zip | Should -Exist
        @(Get-ChildItem -Path (Join-Path -Path $project -ChildPath 'Artifacts') -Filter 'Test-*.xml') | Should -HaveCount 1
        $entries = [System.IO.Compression.ZipFile]::OpenRead($zip)
        try {
            $entries.Entries.FullName.Replace('\', '/') | Should -Contain 'Fixture/Fixture.psd1'
        }
        finally {
            $entries.Dispose()
        }
    }
}

Describe -Name 'Shim drift warning' -Fixture {
    BeforeAll {
        $reference = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'templates' -AdditionalChildPath 'Build', 'build.ps1'
    }
    It -Name 'stays quiet when the consumer shim matches the reference' -Test {
        $project = Initialize-FixtureModule
        New-Item -Path (Join-Path -Path $project -ChildPath 'Build') -ItemType 'Directory' -Force | Out-Null
        Copy-Item -Path $reference -Destination (Join-Path -Path $project -ChildPath 'Build' -AdditionalChildPath 'build.ps1')
        $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'Init'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Not -BeLike '*differs from the reference shim*'
    }
    It -Name 'warns, without failing, when the consumer shim has drifted' -Test {
        $project = Initialize-FixtureModule
        New-Item -Path (Join-Path -Path $project -ChildPath 'Build') -ItemType 'Directory' -Force | Out-Null
        Set-Content -Path (Join-Path -Path $project -ChildPath 'Build' -AdditionalChildPath 'build.ps1') -Value '# an old vendored harness'
        $result = Invoke-FixtureBuild -ProjectPath $project -TaskList 'Init'
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -BeLike '*differs from the reference shim*'
    }
}

Describe -Name 'Strict mode in harness tasks' -Fixture {
    BeforeAll {
        # A COPY OF THE REAL BUILD FILE WITH ONE PROBE TASK APPENDED, SO WHATEVER STRICT MODE IT SETS IS WHAT THE PROBE SEES
        $buildRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build'
        $probeRoot = Join-Path -Path $TestDrive -ChildPath 'probe-build'
        Copy-Item -Path $buildRoot -Destination $probeRoot -Recurse
        $probeTask = @(
            ''
            'Task ''Probe'' {'
            '    $probe = ($analysisResult.Count -eq 0)'
            '    Write-Output -InputObject (''PROBE completed: {0}'' -f $probe)'
            '}'
        )
        Add-Content -Path (Join-Path -Path $probeRoot -ChildPath 'build.psake.ps1') -Value $probeTask
        $project = Initialize-FixtureModule
    }
    It -Name 'stops a harness task that reads an undefined variable, the dead-gate pattern' -Test {
        $driver = Join-Path -Path $TestDrive -ChildPath 'probe-driver.ps1'
        Set-Content -Path $driver -Value @(
            'Import-Module -Name psake -RequiredVersion 5.0.4'
            ('. ''{0}''' -f (Join-Path -Path $probeRoot -ChildPath 'Harness.Functions.ps1'))
            ('Set-HarnessEnvironment -Project (Resolve-HarnessProject -ProjectPath ''{0}'')' -f $project)
            ('Invoke-psake -buildFile ''{0}'' -taskList Probe -nologo' -f (Join-Path -Path $probeRoot -ChildPath 'build.psake.ps1'))
            'exit ([System.Int32] (-not $psake.build_success))'
        )
        $output = (& pwsh -NoProfile -NonInteractive -File $driver 2>&1) -join [System.Environment]::NewLine
        $LASTEXITCODE | Should -Not -Be 0 -Because $output
        $output | Should -Not -BeLike '*PROBE completed*'
        $output | Should -BeLike '*analysisResult*'
    }
}
