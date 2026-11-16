[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    $utf8Bom = [System.Byte[]] (@(0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes('function Get-Bom { ''x'' }'))
    $utf16 = [System.Text.Encoding]::Unicode.GetBytes('function Get-Wide { ''x'' }')
    $tabbed = 'function Get-Tab {{{0}''x'' }}' -f [System.Char] 9
    $helpExample = @(
        'function Get-Fixture {'
        '    <#'
        '    .EXAMPLE'
        '        Get-Fixture -Path "$HOME\Desktop\out.txt"'
        '    #>'
        '    ''ok'''
        '}'
    ) -join [System.Environment]::NewLine
    $inComment = @(
        'function Get-Fixture {'
        '    # see "$HOME\Desktop"'
        '    ''ok'''
        '}'
    ) -join [System.Environment]::NewLine

    # A FUNCTION WITH COMPLETE HELP FOR ONE [System.String] PARAMETER, -Path, UNLESS A SWITCH REMOVES OR CHANGES A PART
    function Get-HelpFixtureSource {
        param (
            [System.String] $Name = 'Get-Fixture',
            [System.String[]] $Parameters = @('Path'),
            [System.Collections.IDictionary] $ParameterHelp = [ordered] @{ Path = 'A path.' },
            [System.String[]] $Links = @(),
            [System.Management.Automation.SwitchParameter] $NoHelp,
            [System.Management.Automation.SwitchParameter] $NoSynopsis,
            [System.Management.Automation.SwitchParameter] $NoDescription,
            [System.Management.Automation.SwitchParameter] $NoExample,
            [System.Management.Automation.SwitchParameter] $Dynamic
        )
        $help = @(
            if (-not $NoSynopsis) { '    .SYNOPSIS', '        Fixture.' }
            if (-not $NoDescription) { '    .DESCRIPTION', '        A fixture function.' }
            # .PSBase: THE Keys CASE PUTS A Keys ENTRY IN THIS DICTIONARY
            foreach ($p in $ParameterHelp.PSBase.Keys) {
                '    .PARAMETER {0}' -f $p
                if ($ParameterHelp[$p]) { '        {0}' -f $ParameterHelp[$p] }
            }
            if (-not $NoExample) { '    .EXAMPLE', ('        {0}' -f $Name) }
            foreach ($l in $Links) { '    .LINK', ('        {0}' -f $l) }
        )
        $dynamicBlock = @(
            '    dynamicparam {'
            '        if ($PSBoundParameters.ContainsKey(''Path'')) {'
            '            $dictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()'
            '            $attributes = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()'
            '            $attributes.Add([System.Management.Automation.ParameterAttribute]::new())'
            '            $dictionary.Add(''Extra'', [System.Management.Automation.RuntimeDefinedParameter]::new(''Extra'', [System.String], $attributes))'
            '            $dictionary'
            '        }'
            '    }'
        )
        @(
            'function {0} {{' -f $Name
            if (-not $NoHelp) { '    <#'; $help; '    #>' }
            '    [CmdletBinding()]'
            ('    param ({0})' -f (($Parameters.ForEach({ '[System.String] ${0}' -f $_ })) -join ', '))
            if ($Dynamic) { $dynamicBlock }
            '    process { ''ok'' }'
            '}'
        ) -join [System.Environment]::NewLine
    }

    # EACH CASE NAMES EXACTLY THE TESTS IT MUST FAIL (BY KEY) AND HOW MANY TESTS THE SUITE MUST RUN
    $suites = @(
        @{
            Suite = 'help.tests.ps1'
            Names = @{
                Synopsis          = 'Get-Fixture has a synopsis'
                Description       = 'Get-Fixture has a description'
                Example           = 'Get-Fixture has an example'
                Parameters        = 'Get-Fixture documents exactly its parameters'
                Link              = 'has a well-formed absolute http or https URI in every .LINK'
                SecondSynopsis    = 'Get-Second has a synopsis'
                SecondDescription = 'Get-Second has a description'
                SecondExample     = 'Get-Second has an example'
                SecondParameters  = 'Get-Second documents exactly its parameters'
            }
            Cases = @(
                @{ Case = 'complete help'; Count = 5; Function = (Get-HelpFixtureSource); Expect = @() }
                @{ Case = 'no comment-based help'; Count = 5; Function = (Get-HelpFixtureSource -NoHelp); Expect = @('Synopsis', 'Description', 'Example', 'Parameters'); Mentions = @('no comment-based help') }
                @{ Case = 'no .SYNOPSIS'; Count = 5; Function = (Get-HelpFixtureSource -NoSynopsis); Expect = @('Synopsis') }
                @{ Case = 'no .DESCRIPTION'; Count = 5; Function = (Get-HelpFixtureSource -NoDescription); Expect = @('Description') }
                @{ Case = 'no .EXAMPLE'; Count = 5; Function = (Get-HelpFixtureSource -NoExample); Expect = @('Example') }
                @{ Case = 'an undocumented parameter'; Count = 5; Function = (Get-HelpFixtureSource -Parameters 'Path', 'Missing'); Expect = @('Parameters'); Mentions = @('Missing') }
                @{ Case = 'an empty .PARAMETER entry'; Count = 5; Function = (Get-HelpFixtureSource -ParameterHelp ([ordered] @{ Path = '' })); Expect = @('Parameters'); Mentions = @('Path') }
                @{ Case = 'a .PARAMETER naming no parameter'; Count = 5; Function = (Get-HelpFixtureSource -ParameterHelp ([ordered] @{ Path = 'A path.'; Ghost = 'Not declared.' })); Expect = @('Parameters'); Mentions = @('Ghost') }
                @{ Case = 'a .PARAMETER for a dynamic parameter'; Count = 5; Function = (Get-HelpFixtureSource -Dynamic -ParameterHelp ([ordered] @{ Path = 'A path.'; Extra = 'Dynamic.' })); Expect = @() }
                @{ Case = 'an undocumented parameter beside a DynamicParam block'; Count = 5; Function = (Get-HelpFixtureSource -Dynamic -Parameters 'Path', 'Missing'); Expect = @('Parameters'); Mentions = @('Missing') }
                @{ Case = 'a documented parameter named Keys'; Count = 5; Function = (Get-HelpFixtureSource -Parameters 'Path', 'Keys' -ParameterHelp ([ordered] @{ Path = 'A path.'; Keys = 'Some keys.' })); Expect = @() }
                @{ Case = 'a .LINK to a command'; Count = 5; Function = (Get-HelpFixtureSource -Links 'Get-Item'); Expect = @() }
                @{ Case = 'a .LINK to an https URI'; Count = 5; Function = (Get-HelpFixtureSource -Links 'https://example.com/ok'); Expect = @() }
                @{ Case = 'a .LINK with a non-http scheme'; Count = 5; Function = (Get-HelpFixtureSource -Links 'ftp://example.com/file'); Expect = @('Link'); Mentions = @('ftp://example.com/file') }
                @{ Case = 'a .LINK that is not a well-formed URI'; Count = 5; Function = (Get-HelpFixtureSource -Links 'https://example.com/a^b'); Expect = @('Link'); Mentions = @('https://example.com/a^b') }
                @{ Case = 'two malformed .LINK URIs'; Count = 5; Function = (Get-HelpFixtureSource -Links 'htp:/broken', 'ftp://example.com/two'); Expect = @('Link'); Mentions = @('htp:/broken', 'ftp://example.com/two') }
                @{ Case = 'a second function with no help'; Count = 9; Change = @{ FunctionsToExport = @('Get-Fixture', 'Get-Second') }; Function = (Get-HelpFixtureSource); Files = @{ 'Staging/Fixture/Public/Get-Second.ps1' = (Get-HelpFixtureSource -Name 'Get-Second' -NoHelp) }; Expect = @('SecondSynopsis', 'SecondDescription', 'SecondExample', 'SecondParameters'); Mentions = @('Get-Second') }
            )
        }
        @{
            Suite = 'manifest.tests.ps1'
            Names = @{
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
            Cases = @(
                @{ Case = 'a clean module'; Count = 11; Expect = @() }
                @{ Case = 'FileList naming a missing file'; Count = 11; Change = @{ FileList = @('missing.txt') }; Expect = @('TestModuleManifest') }
                @{ Case = 'RootModule without its extension'; Count = 11; Change = @{ RootModule = 'Fixture' }; Expect = @('RootModule') }
                @{ Case = 'no Description'; Count = 11; Remove = @('Description'); Expect = @('Description') }
                @{ Case = 'no Author'; Count = 11; Remove = @('Author'); Expect = @('Author') }
                @{ Case = 'no Copyright'; Count = 11; Remove = @('Copyright'); Expect = @('Copyright') }
                @{ Case = 'an empty FunctionsToExport'; Count = 11; Change = @{ FunctionsToExport = @() }; Expect = @('FunctionsNonEmpty', 'FunctionsMatchPublic', 'ResolvedExports') }
                @{ Case = 'a declared function with no Public/ file'; Count = 11; Change = @{ FunctionsToExport = @('Get-Fixture', 'Get-Missing') }; Expect = @('FunctionsMatchPublic') }
                @{ Case = 'a wildcard in AliasesToExport'; Count = 11; Change = @{ AliasesToExport = @('Fix*') }; Expect = @('Wildcard') }
                @{ Case = 'no PrivateData'; Count = 11; Remove = @('PrivateData'); Expect = @('ProjectUri') }
                @{ Case = 'PSData without ProjectUri'; Count = 11; Change = @{ PrivateData = @{ PSData = @{ Tags = @('fixture') } } }; Expect = @('ProjectUri') }
                @{ Case = 'PowerShellVersion 5.1'; Count = 11; Change = @{ PowerShellVersion = '5.1' }; Expect = @() }
                @{ Case = 'PowerShellVersion 7.0'; Count = 11; Change = @{ PowerShellVersion = '7.0' }; Expect = @() }
                @{ Case = 'PowerShellVersion 3.0'; Count = 11; Change = @{ PowerShellVersion = '3.0' }; Expect = @('PowerShellVersion') }
                @{ Case = 'PowerShellVersion 5.0'; Count = 11; Change = @{ PowerShellVersion = '5.0' }; Expect = @('PowerShellVersion') }
                @{ Case = 'PowerShellVersion 6.2'; Count = 11; Change = @{ PowerShellVersion = '6.2' }; Expect = @('PowerShellVersion') }
                @{ Case = 'no PowerShellVersion'; Count = 11; Remove = @('PowerShellVersion'); Expect = @('PowerShellVersion') }
                @{ Case = 'PowerShellVersion above the running PowerShell'; Count = 11; Change = @{ PowerShellVersion = '99.0' }; Expect = @('PowerShellVersion', 'TestModuleManifest', 'ResolvedExports') }
                @{ Case = 'a Public/ file whose function is misnamed'; Count = 11; Function = 'function Get-Other { ''ok'' }'; Expect = @('ResolvedExports') }
            )
        }
        @{
            Suite = 'meta.tests.ps1'
            Names = @{
                Bom = 'has no UTF-8 byte order mark in any text file'
                Tab = 'has no tab character in any text file'
                Nul = 'has no 0x00 byte in any text file'
            }
            Cases = @(
                @{ Case = 'a clean module'; Count = 3; Expect = @() }
                @{ Case = 'a UTF-8 BOM in a Public file'; Count = 3; Files = @{ 'Public/Get-Bom.ps1' = $utf8Bom }; Expect = @('Bom'); Mentions = @('Get-Bom.ps1') }
                @{ Case = 'a tab in a Private file'; Count = 3; Files = @{ 'Private/Get-Tab.ps1' = $tabbed }; Expect = @('Tab'); Mentions = @('Get-Tab.ps1') }
                @{ Case = 'a UTF-16 file'; Count = 3; Files = @{ 'Private/Get-Wide.ps1' = $utf16 }; Expect = @('Nul'); Mentions = @('Get-Wide.ps1') }
                @{ Case = 'defects only under .git, Staging and Artifacts'; Count = 3; Files = @{ '.git/hooks/pre.ps1' = $utf8Bom; 'Staging/Fixture/Get-Tab.ps1' = $tabbed; 'Artifacts/x.psd1' = $utf16 }; Expect = @() }
                @{ Case = 'a tab in a dot-folder script'; Count = 3; Files = @{ '.github/scripts/Run-Tab.ps1' = $tabbed }; Expect = @('Tab'); Mentions = @('Run-Tab.ps1') }
                @{ Case = 'a UTF-16 JSON data file'; Count = 3; Files = @{ 'Private/Data.json' = $utf16 }; Expect = @('Nul'); Mentions = @('Data.json') }
                @{ Case = 'a BOM in a dot-folder JSON file'; Count = 3; Files = @{ '.vscode/settings.json' = $utf8Bom }; Expect = @('Bom'); Mentions = @('settings.json') }
                @{ Case = 'a tab in .gitignore and in an XML file'; Count = 3; Files = @{ '.gitignore' = $tabbed; 'Private/Types.xml' = $tabbed }; Expect = @('Tab'); Mentions = @('.gitignore', 'Types.xml') }
                @{ Case = 'defects only in file types it does not check'; Count = 3; Files = @{ 'README.md' = $tabbed; 'notes.txt' = $utf16; 'data.csv' = $utf8Bom }; Expect = @() }
                @{ Case = 'twenty extra source files'; Count = 3; Files = [ordered] @{ 'Private/a01.ps1' = '# a'; 'Private/a02.ps1' = '# a'; 'Private/a03.ps1' = '# a'; 'Private/a04.ps1' = '# a'; 'Private/a05.ps1' = '# a'; 'Private/a06.ps1' = '# a'; 'Private/a07.ps1' = '# a'; 'Private/a08.ps1' = '# a'; 'Private/a09.ps1' = '# a'; 'Private/a10.ps1' = '# a'; 'Tests/Unit/b01.tests.ps1' = '# b'; 'Tests/Unit/b02.tests.ps1' = '# b'; 'Tests/Unit/b03.tests.ps1' = '# b'; 'Tests/Unit/b04.tests.ps1' = '# b'; 'Tests/Unit/b05.tests.ps1' = '# b'; 'Tests/Unit/b06.tests.ps1' = '# b'; 'Tests/Unit/b07.tests.ps1' = '# b'; 'Tests/Unit/b08.tests.ps1' = '# b'; 'Tests/Unit/b09.tests.ps1' = '# b'; 'Tests/Unit/b10.tests.ps1' = '# b' }; Expect = @() }
            )
        }
        @{
            Suite = 'pathliterals.tests.ps1'
            Names = @{
                Fixture = 'has no backslash after $HOME, $PSScriptRoot, $PWD or $TestDrive in a string in Get-Fixture.ps1'
                Second  = 'has no backslash after $HOME, $PSScriptRoot, $PWD or $TestDrive in a string in Get-Second.ps1'
            }
            Cases = @(
                @{ Case = 'a clean module'; Count = 1; Expect = @() }
                @{ Case = '$HOME\ in a string'; Count = 1; Function = 'function Get-Fixture { Join-Path -Path "$HOME\Desktop" -ChildPath ''x'' }'; Expect = @('Fixture') }
                @{ Case = '$PSScriptRoot\ in a string'; Count = 1; Function = 'function Get-Fixture { "$PSScriptRoot\data.json" }'; Expect = @('Fixture') }
                @{ Case = '$PWD\ in a string'; Count = 1; Function = 'function Get-Fixture { "$PWD\out.txt" }'; Expect = @('Fixture') }
                @{ Case = '$TestDrive\ in a string'; Count = 1; Function = 'function Get-Fixture { "$TestDrive\x" }'; Expect = @('Fixture') }
                @{ Case = 'the same text in a comment'; Count = 1; Function = $inComment; Expect = @() }
                @{ Case = 'the same text in a help .EXAMPLE'; Count = 1; Function = $helpExample; Expect = @() }
                @{ Case = 'two Public files, one with a literal'; Count = 2; Files = @{ 'Public/Get-Second.ps1' = 'function Get-Second { "$HOME\x" }' }; Expect = @('Second') }
            )
        }
    )
    # BeforeDiscovery VARIABLES DO NOT REACH THE RUN PHASE, SO EVERYTHING TRAVELS AS -ForEach DATA
    $runs = foreach ($s in $suites) {
        foreach ($strict in $false, $true) {
            @{ Suite = $s.Suite; Names = $s.Names; Cases = $s.Cases; Strict = $strict; Mode = $(if ($strict) { 'strict' } else { 'lenient' }) }
        }
    }
}

BeforeAll {
    $driver = Join-Path -Path $PSScriptRoot -ChildPath 'SharedSuite.Driver.ps1'
    $suiteRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'SharedTests'

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
            [System.String] $Function = 'function Get-Fixture { ''ok'' }',
            [System.Collections.IDictionary] $Files
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
        if ($Files) {
            foreach ($relative in $Files.Keys) {
                $path = Join-Path -Path $root -ChildPath $relative
                New-Item -Path (Split-Path -Path $path -Parent) -ItemType 'Directory' -Force | Out-Null
                if ($Files[$relative] -is [System.Byte[]]) {
                    [System.IO.File]::WriteAllBytes($path, $Files[$relative])
                }
                else {
                    Set-Content -Path $path -Value $Files[$relative]
                }
            }
        }
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

Describe -Name '<Suite> (<Mode>)' -ForEach $runs -Fixture {
    BeforeAll {
        $runCases = @(foreach ($c in $Cases) {
                $fixtureParams = @{}
                foreach ($k in 'Change', 'Remove', 'Function', 'Files') {
                    if ($c.ContainsKey($k)) { $fixtureParams[$k] = $c[$k] }
                }
                [PSCustomObject] @{ Case = $c.Case; ProjectPath = (Initialize-SharedFixture @fixtureParams); NoData = $false }
            })
        $runCases += [PSCustomObject] @{ Case = 'no -Data'; ProjectPath = ''; NoData = $true }
        $results = Invoke-SharedSuite -Suite $Suite -Cases $runCases -Strict $Strict
    }
    It -Name 'runs <Count> tests and fails exactly the expected ones for <Case>' -ForEach $Cases -Test {
        $caseResults = @($results.Where({ $_.Case -eq $Case }))
        $caseResults.Where({ $_.Test -eq '<container>' }) | Should -BeNullOrEmpty -Because ($caseResults.Message -join ' ')
        $caseResults | Should -HaveCount $Count
        $failedResults = @($caseResults.Where({ $_.Result -ne 'Passed' }))
        $failed = (@($failedResults.ForEach({ $_.Test })) | Sort-Object) -join ' | '
        $expected = (@($Expect.ForEach({ $Names[$_] })) | Sort-Object) -join ' | '
        $failed | Should -BeExactly $expected -Because ($failedResults.Message -join ' ')
        foreach ($fileName in @($_['Mentions']).Where({ $_ })) {
            ($failedResults.Message -join ' ') | Should -BeLike ('*{0}*' -f $fileName) -Because 'a failure must name the offending file'
        }
    }
    It -Name 'fails every one of its tests in at least one case' -Test {
        $everFailed = @($results.Where({ $_.Result -eq 'Failed' -and $_.Case -ne 'no -Data' }).ForEach({ $_.Test })) | Sort-Object -Unique
        $everFailed | Should -Be (@($Names.Values) | Sort-Object)
    }
    It -Name 'fails the run, rather than prompting or passing, when -Data is missing' -Test {
        $noData = @($results.Where({ $_.Case -eq 'no -Data' }))
        $noData.Where({ $_.Result -eq 'Passed' }) | Should -BeNullOrEmpty
        $noData.Where({ $_.Result -in 'Failed', 'Error' }) | Should -Not -BeNullOrEmpty
    }
}
