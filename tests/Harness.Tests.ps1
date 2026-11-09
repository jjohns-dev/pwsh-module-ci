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
