[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
param ()

BeforeDiscovery {
    $manifestForms = @(
        @{ Description = 'a bare name floats'; Entry = '''ImportExcel'''; Version = $null }
        @{ Description = 'a ModuleVersion minimum floats'; Entry = '@{ ModuleName = ''ImportExcel''; ModuleVersion = ''7.0.0'' }'; Version = $null }
        @{ Description = 'a RequiredVersion pins exactly'; Entry = '@{ ModuleName = ''ImportExcel''; RequiredVersion = ''7.8.10'' }'; Version = '7.8.10' }
    )
    $badSettings = @(
        @{ Description = 'an unknown key'; Body = 'PesterExcludeTags = ''Network'''; Expected = '*Unknown key `[PesterExcludeTags`]*' }
        @{ Description = 'a non-boolean PesterStrictMode'; Body = 'PesterStrictMode = ''yes'''; Expected = '*PesterStrictMode*must be*' }
        @{ Description = 'a non-string exclude rule'; Body = 'PSScriptAnalyzerExcludeRules = 5'; Expected = '*PSScriptAnalyzerExcludeRules*must be*' }
        @{ Description = 'an empty exclude tag'; Body = 'PesterExcludeTag = '''''; Expected = '*PesterExcludeTag*must be*' }
    )
}

Describe -Name 'Harness build-tool pins and shared settings' -Fixture {
    BeforeAll {
        $buildRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build'
    }
    It -Name 'pins exactly Pester, psake and PSScriptAnalyzer, and nothing else' -Test {
        $depend = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $buildRoot -ChildPath 'depend.psd1')
        @($depend.Keys | Sort-Object) | Should -Be @('Pester', 'psake', 'PSScriptAnalyzer')
        $depend['Pester'] | Should -BeExactly '6.2.0'
        $depend['psake'] | Should -BeExactly '5.0.4'
        $depend['PSScriptAnalyzer'] | Should -BeExactly '1.25.0'
    }
    It -Name 'carries no ExcludeRules in the shared analyzer settings' -Test {
        $settings = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $buildRoot -ChildPath 'PSScriptAnalyzerSettings.psd1')
        $settings.ContainsKey('ExcludeRules') | Should -BeFalse
    }
}

Describe -Name 'Resolve-HarnessProject' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
    }
    BeforeEach {
        $project = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $project -ItemType 'Directory' | Out-Null
    }
    It -Name 'returns the root, module name and manifest when there is exactly one manifest' -Test {
        Set-Content -Path (Join-Path -Path $project -ChildPath 'Fixture.psd1') -Value '@{}'
        $result = Resolve-HarnessProject -ProjectPath $project
        $result.ModuleName | Should -BeExactly 'Fixture'
        $result.ManifestPath | Should -BeExactly (Join-Path -Path $result.ProjectPath -ChildPath 'Fixture.psd1')
    }
    It -Name 'rejects a project with no manifest' -Test {
        { Resolve-HarnessProject -ProjectPath $project } | Should -Throw -ExpectedMessage '*exactly one module manifest*found 0*'
    }
    It -Name 'rejects a project with two manifests instead of joining their names' -Test {
        Set-Content -Path (Join-Path -Path $project -ChildPath 'One.psd1') -Value '@{}'
        Set-Content -Path (Join-Path -Path $project -ChildPath 'Two.psd1') -Value '@{}'
        { Resolve-HarnessProject -ProjectPath $project } | Should -Throw -ExpectedMessage '*found 2*'
    }
    It -Name 'rejects a path that is not a directory' -Test {
        $file = Join-Path -Path $project -ChildPath 'file.txt'
        Set-Content -Path $file -Value 'x'
        { Resolve-HarnessProject -ProjectPath $file } | Should -Throw -ExpectedMessage '*is not a directory*'
    }
}

Describe -Name 'Set-HarnessEnvironment' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
        $names = 'HARNESS_PROJECT_PATH', 'HARNESS_MODULE_NAME', 'HARNESS_MANIFEST_PATH', 'BHProjectPath', 'BHProjectName', 'BHPSModuleManifest'
        $saved = @{}
        foreach ($n in $names) {
            $saved[$n] = [System.Environment]::GetEnvironmentVariable($n)
        }
    }
    AfterAll {
        foreach ($n in $saved.Keys) {
            [System.Environment]::SetEnvironmentVariable($n, $saved[$n])
        }
    }
    It -Name 'sets the HARNESS_ names and the legacy BH names to the same values' -Test {
        $project = [PSCustomObject] @{ ProjectPath = '/p'; ModuleName = 'Fixture'; ManifestPath = '/p/Fixture.psd1' }
        Set-HarnessEnvironment -Project $project
        $env:HARNESS_PROJECT_PATH | Should -BeExactly '/p'
        $env:HARNESS_MODULE_NAME | Should -BeExactly 'Fixture'
        $env:HARNESS_MANIFEST_PATH | Should -BeExactly '/p/Fixture.psd1'
        $env:BHProjectPath | Should -BeExactly $env:HARNESS_PROJECT_PATH
        $env:BHProjectName | Should -BeExactly $env:HARNESS_MODULE_NAME
        $env:BHPSModuleManifest | Should -BeExactly $env:HARNESS_MANIFEST_PATH
    }
}

Describe -Name 'Get-HarnessSetting' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
        function Initialize-SettingFixture ([System.String] $Body) {
            $root = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
            $build = Join-Path -Path $root -ChildPath 'Build'
            New-Item -Path $build -ItemType 'Directory' | Out-Null
            if ($null -ne $Body) {
                Set-Content -Path (Join-Path -Path $build -ChildPath 'harness.psd1') -Value ('@{{ {0} }}' -f $Body)
            }
            $root
        }
    }
    It -Name 'returns defaults when the repo has no harness.psd1' -Test {
        $settings = Get-HarnessSetting -ProjectPath (Initialize-SettingFixture -Body $null)
        $settings.PSScriptAnalyzerExcludeRules | Should -HaveCount 0
        $settings.PesterExcludeTag | Should -HaveCount 0
        $settings.PesterStrictMode | Should -BeFalse
    }
    It -Name 'applies every allowed key' -Test {
        $body = 'PSScriptAnalyzerExcludeRules = ''RuleA'', ''RuleB''; PesterExcludeTag = ''Network''; PesterStrictMode = $true'
        $settings = Get-HarnessSetting -ProjectPath (Initialize-SettingFixture -Body $body)
        $settings.PSScriptAnalyzerExcludeRules | Should -Be @('RuleA', 'RuleB')
        $settings.PesterExcludeTag | Should -Be @('Network')
        $settings.PesterStrictMode | Should -BeTrue
    }
    It -Name 'rejects <Description>' -ForEach $badSettings -Test {
        $root = Initialize-SettingFixture -Body $Body
        { Get-HarnessSetting -ProjectPath $root } | Should -Throw -ExpectedMessage $Expected
    }
    It -Name 'gives exactly the defaults for the optional template copied as-is' -Test {
        $root = Initialize-SettingFixture -Body $null
        $template = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'templates' -AdditionalChildPath 'Build', 'harness.psd1'
        Copy-Item -Path $template -Destination (Join-Path -Path $root -ChildPath 'Build' -AdditionalChildPath 'harness.psd1')
        $settings = Get-HarnessSetting -ProjectPath $root
        $settings.PSScriptAnalyzerExcludeRules | Should -HaveCount 0
        $settings.PesterExcludeTag | Should -HaveCount 0
        $settings.PesterStrictMode | Should -BeFalse
    }
}

Describe -Name 'Get-HarnessDependency' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
        $dependPath = Join-Path -Path $TestDrive -ChildPath 'depend.psd1'
        Set-Content -Path $dependPath -Value '@{ psake = ''5.0.4''; Pester = ''6.2.0'' }'
        function Initialize-ManifestFixture ([System.String] $RequiredModulesLine) {
            $path = Join-Path -Path $TestDrive -ChildPath ('{0}.psd1' -f [System.Guid]::NewGuid())
            Set-Content -Path $path -Value @('@{', '    ModuleVersion = ''1.0.0''', $RequiredModulesLine, '}')
            $path
        }
    }
    It -Name 'lists the pinned build tools with their exact versions' -Test {
        $result = @(Get-HarnessDependency -DependPath $dependPath -ManifestPath (Initialize-ManifestFixture -RequiredModulesLine ''))
        $result.Name | Should -Be @('Pester', 'psake')
        $result.Version | Should -Be @('6.2.0', '5.0.4')
        $result.Source | Should -Be @('Build', 'Build')
    }
    It -Name '<Description>' -ForEach $manifestForms -Test {
        $manifest = Initialize-ManifestFixture -RequiredModulesLine ('    RequiredModules = @({0})' -f $Entry)
        $runtime = @(Get-HarnessDependency -DependPath $dependPath -ManifestPath $manifest).Where({ $_.Source -eq 'Manifest' })
        $runtime | Should -HaveCount 1
        $runtime[0].Name | Should -BeExactly 'ImportExcel'
        $runtime[0].Version | Should -Be $Version
    }
    It -Name 'rejects a MaximumVersion and names the module' -Test {
        $manifest = Initialize-ManifestFixture -RequiredModulesLine '    RequiredModules = @(@{ ModuleName = ''ImportExcel''; MaximumVersion = ''7.9.9'' })'
        { Get-HarnessDependency -DependPath $dependPath -ManifestPath $manifest } | Should -Throw -ExpectedMessage '*`[ImportExcel`]*MaximumVersion*'
    }
    It -Name 'adds no runtime modules when RequiredModules is commented out' -Test {
        $manifest = Initialize-ManifestFixture -RequiredModulesLine '    # RequiredModules = @()'
        @(Get-HarnessDependency -DependPath $dependPath -ManifestPath $manifest).Where({ $_.Source -eq 'Manifest' }) | Should -HaveCount 0
    }
    It -Name 'reads every runtime module in manifest order' -Test {
        $manifest = Initialize-ManifestFixture -RequiredModulesLine '    RequiredModules = @(''ImportExcel'', ''AWS.Tools.Common'')'
        @(Get-HarnessDependency -DependPath $dependPath -ManifestPath $manifest).Where({ $_.Source -eq 'Manifest' }).Name | Should -Be @('ImportExcel', 'AWS.Tools.Common')
    }
}

Describe -Name 'Install-HarnessDependency' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
    }
    BeforeEach {
        Mock -CommandName 'Install-PSResource' -MockWith { }
        Mock -CommandName 'Get-InstalledPSResource' -MockWith {
            [PSCustomObject] @{ Name = $Name; Version = [System.Version] '7.8.10' }
            [PSCustomObject] @{ Name = $Name; Version = [System.Version] '7.9.0' }
        }
    }
    It -Name 'installs a floating module without -Version and reports the newest installed' -Test {
        $result = Install-HarnessDependency -Dependency ([PSCustomObject] @{ Name = 'ImportExcel'; Version = $null; Source = 'Manifest' })
        Should -Invoke -CommandName 'Install-PSResource' -Times 1 -Exactly -ParameterFilter { -not $PSBoundParameters.ContainsKey('Version') }
        $result | Should -BeExactly 'Resolved dependency: ImportExcel 7.9.0'
    }
    It -Name 'installs a pinned module with its exact -Version and reports that version' -Test {
        $result = Install-HarnessDependency -Dependency ([PSCustomObject] @{ Name = 'ImportExcel'; Version = '7.8.10'; Source = 'Manifest' })
        Should -Invoke -CommandName 'Install-PSResource' -Times 1 -Exactly -ParameterFilter { $Version -eq '7.8.10' }
        $result | Should -BeExactly 'Resolved dependency: ImportExcel 7.8.10'
    }
    It -Name 'reports one resolved line per module' -Test {
        $dependency = @(
            [PSCustomObject] @{ Name = 'Pester'; Version = $null; Source = 'Build' }
            [PSCustomObject] @{ Name = 'ImportExcel'; Version = $null; Source = 'Manifest' }
        )
        $result = @(Install-HarnessDependency -Dependency $dependency)
        $result | Should -HaveCount 2
        $result | Should -BeLike 'Resolved dependency: *'
    }
    It -Name 'fails when a module is still missing after installation' -Test {
        Mock -CommandName 'Get-InstalledPSResource' -MockWith { }
        { Install-HarnessDependency -Dependency ([PSCustomObject] @{ Name = 'Ghost'; Version = $null; Source = 'Manifest' }) } |
            Should -Throw -ExpectedMessage '*`[Ghost`] is not installed*'
    }
}

Describe -Name 'Get-HarnessAnalyzerSetting and Invoke-HarnessAnalysis' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
        $pssaVersion = (Import-PowerShellDataFile -LiteralPath (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'depend.psd1'))['PSScriptAnalyzer']
        Import-Module -Name 'PSScriptAnalyzer' -RequiredVersion $pssaVersion -Force -ErrorAction 'Stop'
        # THE SAME ALIAS FINDING IN EACH FOLDER, SO A WRONGLY INCLUDED OR EXCLUDED FOLDER CHANGES THE COUNT
        function Initialize-AnalysisFixture ([System.String] $HarnessBody) {
            $root = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
            foreach ($folder in 'Public', '.github', (Join-Path -Path '.harness' -ChildPath 'Build')) {
                $dir = Join-Path -Path $root -ChildPath $folder
                New-Item -Path $dir -ItemType 'Directory' -Force | Out-Null
                Set-Content -Path (Join-Path -Path $dir -ChildPath 'Get-Fixture.ps1') -Value 'function Get-Fixture { gci }'
            }
            if ($HarnessBody) {
                New-Item -Path (Join-Path -Path $root -ChildPath 'Build') -ItemType 'Directory' | Out-Null
                Set-Content -Path (Join-Path -Path $root -ChildPath 'Build' -AdditionalChildPath 'harness.psd1') -Value ('@{{ {0} }}' -f $HarnessBody)
            }
            $root
        }
    }
    It -Name 'returns the shared settings unchanged when the repo excludes nothing' -Test {
        $settings = Get-HarnessAnalyzerSetting -ProjectPath (Initialize-AnalysisFixture -HarnessBody $null)
        $settings['Severity'] | Should -Be @('Error', 'Warning')
        $settings.ContainsKey('ExcludeRules') | Should -BeFalse
    }
    It -Name 'adds the repo''s exclusions to the shared settings' -Test {
        $settings = Get-HarnessAnalyzerSetting -ProjectPath (Initialize-AnalysisFixture -HarnessBody 'PSScriptAnalyzerExcludeRules = ''RuleA''')
        $settings['Severity'] | Should -Be @('Error', 'Warning')
        $settings['ExcludeRules'] | Should -Be @('RuleA')
    }
    It -Name 'reports dot-folders such as .github but never the harness checkout' -Test {
        $findings = @(Invoke-HarnessAnalysis -ProjectPath (Initialize-AnalysisFixture -HarnessBody $null))
        $findings.RuleName | Should -Be @('PSAvoidUsingCmdletAliases', 'PSAvoidUsingCmdletAliases')
        $findings.Where({ $_.ScriptPath -match '[\\/]\.harness[\\/]' }) | Should -HaveCount 0
        $findings.Where({ $_.ScriptPath -match '[\\/]\.github[\\/]' }) | Should -HaveCount 1
    }
    It -Name 'applies the repo''s exclusions' -Test {
        $root = Initialize-AnalysisFixture -HarnessBody 'PSScriptAnalyzerExcludeRules = ''PSAvoidUsingCmdletAliases'''
        @(Invoke-HarnessAnalysis -ProjectPath $root) | Should -HaveCount 0
    }
}

Describe -Name 'Write-HarnessAnalysisReport' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
        function Get-FindingFixture ([System.String] $Severity, [System.String] $Rule = 'PSRule', [System.String] $Path = 'Public/Get-A.ps1', [System.String] $Message = 'A message.') {
            [PSCustomObject] @{
                RuleName   = $Rule
                Severity   = $Severity
                ScriptPath = if ($Path) { Join-Path -Path $script:root -ChildPath $Path } else { $null }
                Line       = 3
                Column     = 5
                Message    = $Message
            }
        }
        # RUNS THE REPORT AND KEEPS WHAT IT EMITTED EVEN WHEN IT THROWS, SO THE FAILING CASES CAN INSPECT IT
        function Invoke-Report ([System.Object[]] $Finding) {
            $captured = [System.Collections.Generic.List[System.String]]::new()
            $threw = $false
            try {
                Write-HarnessAnalysisReport -Finding $Finding -ProjectPath $script:root -SummaryPath $script:summary | ForEach-Object -Process { $captured.Add($_) }
            }
            catch {
                $threw = $true
            }
            [PSCustomObject] @{ Threw = $threw; Output = @($captured); Summary = (Get-Content -LiteralPath $script:summary -Raw) }
        }
    }
    BeforeEach {
        $script:root = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $script:root -ItemType 'Directory' | Out-Null
        $script:summary = Join-Path -Path $script:root -ChildPath 'summary.md'
    }
    It -Name 'fails and annotates a finding at Error severity, with file, line and column' -Test {
        $result = Invoke-Report -Finding @(Get-FindingFixture -Severity 'Error' -Rule 'PSAvoidUsingInvokeExpression' -Message 'Bad thing.')
        $result.Threw | Should -BeTrue
        $result.Output | Should -Be @('::error file=Public/Get-A.ps1,line=3,col=5,title=PSAvoidUsingInvokeExpression::Bad thing.')
        $result.Summary | Should -BeLike '*1 error(s), 0 warning(s).*'
        $result.Summary | Should -BeLike '*| PSAvoidUsingInvokeExpression | Error | Public/Get-A.ps1:3 | Bad thing. |*'
    }
    It -Name 'fails on a parse error' -Test {
        $result = Invoke-Report -Finding @(Get-FindingFixture -Severity 'ParseError')
        $result.Threw | Should -BeTrue
        $result.Output[0] | Should -BeLike '::error *'
    }
    It -Name 'annotates a Warning-only run but does not fail it' -Test {
        $result = Invoke-Report -Finding @(Get-FindingFixture -Severity 'Warning' -Rule 'PSAvoidUsingWriteHost'), (Get-FindingFixture -Severity 'Warning' -Path 'Private/B.ps1')
        $result.Threw | Should -BeFalse
        $result.Output | Should -HaveCount 2
        $result.Output | ForEach-Object -Process { $_ | Should -BeLike '::warning file=*' }
        $result.Output -join "`n" | Should -Not -BeLike '*::error*'
        $result.Summary | Should -BeLike '*0 error(s), 2 warning(s).*'
    }
    It -Name 'fails a mixed run on its Error and still annotates the Warning' -Test {
        $result = Invoke-Report -Finding @(Get-FindingFixture -Severity 'Warning'), (Get-FindingFixture -Severity 'Error' -Path 'Private/B.ps1')
        $result.Threw | Should -BeTrue
        $result.Output | Should -HaveCount 2
        $result.Output.Where({ $_ -like '::warning *' }) | Should -HaveCount 1
        $result.Output.Where({ $_ -like '::error *' }) | Should -HaveCount 1
    }
    It -Name 'reports a clean tree with no annotations, a no-findings line, and a pass' -Test {
        $result = Invoke-Report -Finding @()
        $result.Threw | Should -BeFalse
        $result.Output | Should -HaveCount 0
        $result.Summary | Should -BeLike '*No PSScriptAnalyzer findings.*'
        $result.Summary | Should -Not -BeLike '*| Rule |*'
    }
    It -Name 'omits the location properties for a finding with no file' -Test {
        $result = Invoke-Report -Finding @(Get-FindingFixture -Severity 'Warning' -Path $null)
        $result.Output | Should -Be @('::warning title=PSRule::A message.')
    }
    It -Name 'cannot be made to inject a workflow command through a hostile file name, rule or message' -Test {
        $hostile = "bad%name:with,comma`n::error::injected-from-path.ps1"
        $finding = Get-FindingFixture -Severity 'Warning' -Path $hostile -Rule "Rule,x`n::set-output name=a::b" -Message "boom 100% :: stop`r`n::add-mask::secret`n::error file=evil::pwned"
        $result = Invoke-Report -Finding @($finding)
        # ONE FINDING, ONE LINE: EVERY LINE BREAK IN THE DATA WAS ESCAPED
        $result.Output | Should -HaveCount 1
        $line = $result.Output[0]
        $line | Should -Not -Match "[`r`n]"
        $line | Should -Match '^::warning file=[^,]*,line=3,col=5,title=[^,]*::'
        # THE PROPERTIES CARRY NO RAW DELIMITER, SO THE DATA CANNOT END THE LIST EARLY
        $properties = ($line -split '::', 3)[1]
        ($properties -split ',').Count | Should -Be 4
        $properties | Should -BeLike '*bad%25name%3Awith%2Ccomma%0A%3A%3Aerror%3A%3Ainjected-from-path.ps1*'
        $line | Should -BeLike '*boom 100%25 :: stop%0D%0A::add-mask::secret%0A::error file=evil::pwned'
        # AND NO LINE OF THE REPORT, OR OF THE SUMMARY, STARTS A COMMAND OF ITS OWN
        $result.Output.Where({ $_ -notmatch '^::warning ' }) | Should -HaveCount 0
        ($result.Summary -split "`r?`n").Where({ $_ -match '^::' }) | Should -HaveCount 0
    }
    It -Name 'keeps a hostile finding on one row of the summary table, with no raw markup' -Test {
        $finding = Get-FindingFixture -Severity 'Warning' -Message "a | b`nc <img src=x> `` d"
        $result = Invoke-Report -Finding @($finding)
        $rows = @(($result.Summary -split "`r?`n").Where({ $_ -like '| PSRule *' }))
        $rows | Should -HaveCount 1
        $rows[0] | Should -Not -BeLike '*<img*'
        # -BeExactly, NOT -BeLike: A BACKTICK IS THE ESCAPE CHARACTER IN A WILDCARD PATTERN
        $rows[0] | Should -BeExactly '| PSRule | Warning | Public/Get-A.ps1:3 | a \| b c &lt;img src=x&gt; \` d |'
    }
}

Describe -Name 'ConvertTo-HarnessWorkflowCommandText' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
    }
    It -Name 'escapes % first so an escape is not double-escaped, then CR and LF' -Test {
        ConvertTo-HarnessWorkflowCommandText -Text "a%0Ab`r`nc" | Should -BeExactly 'a%250Ab%0D%0Ac'
    }
    It -Name 'leaves : and , alone in a message' -Test {
        ConvertTo-HarnessWorkflowCommandText -Text 'a:b,c' | Should -BeExactly 'a:b,c'
    }
    It -Name 'also escapes : and , in a property' -Test {
        ConvertTo-HarnessWorkflowCommandText -Text 'a:b,c' -Property | Should -BeExactly 'a%3Ab%2Cc'
    }
    It -Name 'turns null into an empty string' -Test {
        ConvertTo-HarnessWorkflowCommandText -Text $null | Should -BeExactly ''
    }
}

Describe -Name 'Get-HarnessSharedContainer' -Fixture {
    BeforeAll {
        . (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'Harness.Functions.ps1')
    }
    BeforeEach {
        $suiteRoot = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $suiteRoot -ItemType 'Directory' | Out-Null
    }
    It -Name 'gives each suite only the keys its param block declares, in file name order' -Test {
        Set-Content -Path (Join-Path -Path $suiteRoot -ChildPath 'b.tests.ps1') -Value 'param ([System.String] $ProjectPath)'
        Set-Content -Path (Join-Path -Path $suiteRoot -ChildPath 'a.tests.ps1') -Value 'param ([System.String] $ProjectPath, [System.String] $ModuleName)'
        Set-Content -Path (Join-Path -Path $suiteRoot -ChildPath 'c.tests.ps1') -Value 'Describe -Name ''none'' -Fixture { }'
        $containers = @(Get-HarnessSharedContainer -SharedTestPath $suiteRoot -ProjectPath '/p' -ModuleName 'M')
        $containers.ForEach({ Split-Path -Path $_.Item -Leaf }) | Should -Be @('a.tests.ps1', 'b.tests.ps1', 'c.tests.ps1')
        ($containers[0].Data.Keys | Sort-Object) | Should -Be @('ModuleName', 'ProjectPath')
        $containers[0].Data['ModuleName'] | Should -BeExactly 'M'
        @($containers[1].Data.Keys) | Should -Be @('ProjectPath')
        $containers[1].Data['ProjectPath'] | Should -BeExactly '/p'
        @($containers[2].Data.Keys) | Should -HaveCount 0
    }
    It -Name 'stops when a suite declares a parameter the harness does not supply' -Test {
        Set-Content -Path (Join-Path -Path $suiteRoot -ChildPath 'x.tests.ps1') -Value 'param ([System.String] $Unknown)'
        { Get-HarnessSharedContainer -SharedTestPath $suiteRoot -ProjectPath '/p' -ModuleName 'M' } | Should -Throw -ExpectedMessage '*declares `[Unknown`]*'
    }
    It -Name 'stops when the folder holds no suites' -Test {
        { Get-HarnessSharedContainer -SharedTestPath $suiteRoot -ProjectPath '/p' -ModuleName 'M' } | Should -Throw -ExpectedMessage '*No shared suites*'
    }
    It -Name 'defaults to the harness''s own four suites' -Test {
        $containers = @(Get-HarnessSharedContainer -ProjectPath '/p' -ModuleName 'M')
        $containers.ForEach({ Split-Path -Path $_.Item -Leaf }) | Should -Be @('help.tests.ps1', 'manifest.tests.ps1', 'meta.tests.ps1', 'pathliterals.tests.ps1')
    }
}

Describe -Name 'build.ps1 entry point' -Fixture {
    BeforeAll {
        $buildScript = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Build' -AdditionalChildPath 'build.ps1'
    }
    It -Name 'refuses to run without -ProjectPath' -Test {
        $output = & pwsh -NoProfile -NonInteractive -File $buildScript -TaskList 'Init' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join [System.Environment]::NewLine) | Should -BeLike '*ProjectPath*'
    }
    It -Name 'prints the harness commit, then fails on a project with two manifests' -Test {
        $project = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path $project -ItemType 'Directory' | Out-Null
        Set-Content -Path (Join-Path -Path $project -ChildPath 'One.psd1') -Value '@{}'
        Set-Content -Path (Join-Path -Path $project -ChildPath 'Two.psd1') -Value '@{}'
        $output = (& pwsh -NoProfile -NonInteractive -File $buildScript -ProjectPath $project -TaskList 'Init' 2>&1) -join [System.Environment]::NewLine
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'Harness commit: [0-9a-f]{40}'
        # THE CHILD'S ERROR VIEW COLOURS AND WRAPS THE MESSAGE BEHIND A '|' GUTTER, SO FLATTEN IT BEFORE MATCHING
        $flat = (($output -replace '\x1b\[[0-9;]*m', '') -replace '\s*\|\s*', ' ') -replace '\s+', ' '
        $flat | Should -BeLike '*found 2: `[One.psd1, Two.psd1`]*'
    }
}
