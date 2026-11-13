[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    # EACH CASE NAMES EXACTLY THE TESTS IT MUST FAIL; EVERY OTHER TEST MUST PASS
    $manifestCases = @(
        @{ Case = 'a clean module'; Expect = @() }
        @{ Case = 'FileList naming a missing file'; Change = @{ FileList = @('missing.txt') }; Expect = @('TestModuleManifest') }
        @{ Case = 'RootModule without its extension'; Change = @{ RootModule = 'Fixture' }; Expect = @('RootModule') }
        @{ Case = 'no Description'; Remove = @('Description'); Expect = @('Description') }
        @{ Case = 'no Author'; Remove = @('Author'); Expect = @('Author') }
        @{ Case = 'no Copyright'; Remove = @('Copyright'); Expect = @('Copyright') }
        @{ Case = 'an empty FunctionsToExport'; Change = @{ FunctionsToExport = @() }; Expect = @('FunctionsNonEmpty', 'FunctionsMatchPublic', 'ResolvedExports') }
        @{ Case = 'a declared function with no Public/ file'; Change = @{ FunctionsToExport = @('Get-Fixture', 'Get-Missing') }; Expect = @('FunctionsMatchPublic') }
        @{ Case = 'a wildcard in AliasesToExport'; Change = @{ AliasesToExport = @('Fix*') }; Expect = @('Wildcard') }
        @{ Case = 'no PrivateData'; Remove = @('PrivateData'); Expect = @('ProjectUri') }
        @{ Case = 'PSData without ProjectUri'; Change = @{ PrivateData = @{ PSData = @{ Tags = @('fixture') } } }; Expect = @('ProjectUri') }
        @{ Case = 'PowerShellVersion 5.1'; Change = @{ PowerShellVersion = '5.1' }; Expect = @() }
        @{ Case = 'PowerShellVersion 7.0'; Change = @{ PowerShellVersion = '7.0' }; Expect = @() }
        @{ Case = 'PowerShellVersion 3.0'; Change = @{ PowerShellVersion = '3.0' }; Expect = @('PowerShellVersion') }
        @{ Case = 'PowerShellVersion 5.0'; Change = @{ PowerShellVersion = '5.0' }; Expect = @('PowerShellVersion') }
        @{ Case = 'PowerShellVersion 6.2'; Change = @{ PowerShellVersion = '6.2' }; Expect = @('PowerShellVersion') }
        @{ Case = 'no PowerShellVersion'; Remove = @('PowerShellVersion'); Expect = @('PowerShellVersion') }
        @{ Case = 'PowerShellVersion above the running PowerShell'; Change = @{ PowerShellVersion = '99.0' }; Expect = @('PowerShellVersion', 'TestModuleManifest', 'ResolvedExports') }
        @{ Case = 'a Public/ file whose function is misnamed'; Function = 'function Get-Other { ''ok'' }'; Expect = @('ResolvedExports') }
    )
    # BeforeDiscovery VARIABLES DO NOT REACH THE RUN PHASE, SO THE CASES TRAVEL AS -ForEach DATA
    $manifestModes = @(
        @{ Mode = 'lenient'; Strict = $false; Cases = $manifestCases }
        @{ Mode = 'strict'; Strict = $true; Cases = $manifestCases }
    )
}

BeforeAll {
    $driver = Join-Path -Path $PSScriptRoot -ChildPath 'SharedSuite.Driver.ps1'
    $suiteRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'SharedTests'
    $testNames = @{
        TestModuleManifest   = 'passes Test-ModuleManifest'
        RootModule           = 'names the module''s .psm1 as RootModule'
        Description          = 'declares a non-empty Description'
        Author               = 'declares a non-empty Author'
        Copyright            = 'declares a non-empty Copyright'
        FunctionsNonEmpty    = 'declares at least one function in FunctionsToExport'
        FunctionsMatchPublic = 'declares exactly the functions backed by a Public/ file'
        Wildcard             = 'declares no wildcard in any export field'
        ProjectUri           = 'declares a ProjectUri in PrivateData.PSData'
        PowerShellVersion    = 'declares a PowerShellVersion of 5.1, or from 7.0 up to the running PowerShell'
        ResolvedExports      = 'exports every Public/ function once the staged module is imported'
    }

    function ConvertTo-Psd1Text ([System.Object] $Value) {
        if ($Value -is [System.Collections.IDictionary]) {
            $pairs = foreach ($k in $Value.Keys) { '{0} = {1}' -f $k, (ConvertTo-Psd1Text -Value $Value[$k]) }
            return '@{{ {0} }}' -f ($pairs -join '; ')
        }
        if ($Value -is [System.Array]) {
            return '@({0})' -f ((@($Value).ForEach({ ConvertTo-Psd1Text -Value $_ })) -join ', ')
        }
        '''{0}''' -f ([System.String] $Value).Replace('''', '''''')
    }

    # A MODULE THAT PASSES EVERY SHARED TEST, WITH ONE DEFECT APPLIED, AND THE STAGED COPY THE HARNESS WOULD MAKE
    function Initialize-SharedFixture {
        param (
            [System.Collections.IDictionary] $Change,
            [System.String[]] $Remove,
            [System.String] $Function = 'function Get-Fixture { ''ok'' }'
        )
        $root = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        $public = New-Item -Path (Join-Path -Path $root -ChildPath 'Public') -ItemType 'Directory' -Force
        Set-Content -Path (Join-Path -Path $public -ChildPath 'Get-Fixture.ps1') -Value $Function
        $loader = 'foreach ($f in @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath ''Public'') -Filter ''*.ps1'')) { . $f.FullName }'
        Set-Content -Path (Join-Path -Path $root -ChildPath 'Fixture.psm1') -Value $loader
        $manifest = [ordered] @{
            RootModule        = 'Fixture.psm1'
            ModuleVersion     = '1.2.3'
            GUID              = [System.Guid]::NewGuid().ToString()
            Author            = 'fixture'
            Copyright         = '(c) fixture'
            Description       = 'fixture'
            PowerShellVersion = '7.0'
            FunctionsToExport = @('Get-Fixture')
            CmdletsToExport   = @()
            VariablesToExport = @()
            AliasesToExport   = @()
            PrivateData       = @{ PSData = @{ ProjectUri = 'https://example.invalid/fixture' } }
        }
        if ($Change) {
            foreach ($k in $Change.Keys) { $manifest[$k] = $Change[$k] }
        }
        foreach ($k in $Remove) { $manifest.Remove($k) }
        Set-Content -Path (Join-Path -Path $root -ChildPath 'Fixture.psd1') -Value (ConvertTo-Psd1Text -Value $manifest)
        $staged = New-Item -Path (Join-Path -Path $root -ChildPath 'Staging' -AdditionalChildPath 'Fixture') -ItemType 'Directory' -Force
        Copy-Item -Path (Join-Path -Path $root -ChildPath 'Fixture.psd1'), (Join-Path -Path $root -ChildPath 'Fixture.psm1'), $public -Destination $staged -Recurse
        $root
    }

    # ONE CHILD pwsh PER SUITE AND MODE KEEPS STRICT MODE AND IMPORTED FIXTURES OUT OF THIS RUN
    function Invoke-SharedSuite {
        param (
            [System.String] $Suite,
            [System.Object[]] $Cases,
            [System.Boolean] $Strict
        )
        $casesPath = Join-Path -Path $TestDrive -ChildPath ('cases-{0}.json' -f [System.Guid]::NewGuid())
        $outputPath = Join-Path -Path $TestDrive -ChildPath ('results-{0}.json' -f [System.Guid]::NewGuid())
        ConvertTo-Json -InputObject @($Cases) -Depth 4 | Set-Content -Path $casesPath
        $arguments = @('-NoProfile', '-NonInteractive', '-File', $driver, '-SuiteFile', (Join-Path -Path $suiteRoot -ChildPath $Suite), '-CasesPath', $casesPath, '-OutputPath', $outputPath)
        if ($Strict) {
            $arguments += '-Strict'
        }
        $output = & pwsh @arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message ('Driver failed: {0}' -f ($output -join ' ')) -ErrorAction 'Stop'
        }
        @(Get-Content -Path $outputPath -Raw | ConvertFrom-Json)
    }
}

Describe -Name 'manifest.tests.ps1 (<Mode>)' -ForEach $manifestModes -Fixture {
    BeforeAll {
        $runCases = @(foreach ($c in $Cases) {
                $fixtureParams = @{}
                foreach ($k in 'Change', 'Remove', 'Function') {
                    if ($c.ContainsKey($k)) { $fixtureParams[$k] = $c[$k] }
                }
                [PSCustomObject] @{ Case = $c.Case; ProjectPath = (Initialize-SharedFixture @fixtureParams); NoData = $false }
            })
        $runCases += [PSCustomObject] @{ Case = 'no -Data'; ProjectPath = ''; NoData = $true }
        $results = Invoke-SharedSuite -Suite 'manifest.tests.ps1' -Cases $runCases -Strict $Strict
    }
    It -Name 'fails exactly the expected tests for <Case>' -ForEach $manifestCases -Test {
        $caseResults = @($results.Where({ $_.Case -eq $Case }))
        $caseResults.Where({ $_.Test -eq '<container>' }) | Should -BeNullOrEmpty -Because ($caseResults.Message -join ' ')
        $caseResults | Should -HaveCount 11
        $failed = (@($caseResults.Where({ $_.Result -ne 'Passed' }).ForEach({ $_.Test })) | Sort-Object) -join ' | '
        $expected = (@($Expect.ForEach({ $testNames[$_] })) | Sort-Object) -join ' | '
        $failed | Should -BeExactly $expected -Because ($caseResults.Where({ $_.Result -ne 'Passed' }).Message -join ' ')
    }
    It -Name 'fails every one of its tests in at least one case' -Test {
        $everFailed = @($results.Where({ $_.Result -eq 'Failed' -and $_.Case -ne 'no -Data' }).ForEach({ $_.Test })) | Sort-Object -Unique
        $everFailed | Should -Be (@($testNames.Values) | Sort-Object)
    }
    It -Name 'fails the run, rather than prompting or passing, when -Data is missing' -Test {
        $noData = @($results.Where({ $_.Case -eq 'no -Data' }))
        $noData.Where({ $_.Result -eq 'Passed' }) | Should -BeNullOrEmpty
        $noData.Where({ $_.Result -in 'Failed', 'Error' }) | Should -Not -BeNullOrEmpty
    }
}
