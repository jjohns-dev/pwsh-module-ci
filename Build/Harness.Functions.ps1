# ==============================================================================
# Filename: Harness.Functions.ps1
# Version:  0.2.0 | Updated: 2026-11-13
# Author:   johnsarie27
# ==============================================================================
<#
.SYNOPSIS
    Functions behind the build harness: project discovery, environment, settings and dependencies.
.DESCRIPTION
    Dot-sourced by build.ps1 and build.psake.ps1. Keeping the logic in functions lets
    tests/Harness.Tests.ps1 exercise it against fixture modules, with Install-PSResource
    mocked, instead of through a full psake run.
.NOTES
    Spec: docs/specs/centralized-harness/design.md. Q2 decides dependency resolution,
    and the Interfaces table defines the keys Build/harness.psd1 may carry.
#>

function Resolve-HarnessProject {
    <#
    .SYNOPSIS
        Returns the module project at a path: its root, module name and manifest.
    .DESCRIPTION
        The path must be a directory holding exactly one .psd1 at its root. More than
        one is an error rather than a guess: Get-ChildItem would return an array, and
        its BaseName would stringify into a space-joined, silently wrong module name.
    .PARAMETER ProjectPath
        Root of the consumer module's checkout.
    .OUTPUTS
        System.Management.Automation.PSCustomObject with ProjectPath, ModuleName and ManifestPath.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ProjectPath
    )

    if (-not (Test-Path -LiteralPath $ProjectPath -PathType 'Container')) {
        Write-Error -Message ('Project path [{0}] is not a directory.' -f $ProjectPath) -ErrorAction 'Stop'
    }

    $root = (Resolve-Path -LiteralPath $ProjectPath).ProviderPath
    $manifests = @(Get-ChildItem -LiteralPath $root -Filter '*.psd1' -File)
    if ($manifests.Count -ne 1) {
        $found = ($manifests.Name -join ', ')
        $message = 'Expected exactly one module manifest (*.psd1) at [{0}], found {1}: [{2}].' -f $root, $manifests.Count, $found
        Write-Error -Message $message -ErrorAction 'Stop'
    }

    [PSCustomObject] @{
        ProjectPath  = $root
        ModuleName   = $manifests[0].BaseName
        ManifestPath = $manifests[0].FullName
    }
}

function Set-HarnessEnvironment {
    <#
    .SYNOPSIS
        Publishes the project to the build through environment variables.
    .DESCRIPTION
        Sets the HARNESS_* names the harness is written against and the legacy BH* names that
        consumers' own tests still read. Both are kept until no consumer references BH*.
    .PARAMETER Project
        The object returned by Resolve-HarnessProject.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSObject] $Project
    )

    if ($PSCmdlet.ShouldProcess($Project.ProjectPath, 'Set harness environment variables')) {
        $env:HARNESS_PROJECT_PATH = $Project.ProjectPath
        $env:HARNESS_MODULE_NAME = $Project.ModuleName
        $env:HARNESS_MANIFEST_PATH = $Project.ManifestPath
        $env:BHProjectPath = $Project.ProjectPath
        $env:BHProjectName = $Project.ModuleName
        $env:BHPSModuleManifest = $Project.ManifestPath
    }
}

function Get-HarnessSetting {
    <#
    .SYNOPSIS
        Returns the consumer's harness settings, with defaults for anything it does not set.
    .DESCRIPTION
        Reads <ProjectPath>/Build/harness.psd1 when present. The file is optional. An unknown
        key or a wrong type stops the build, so a misspelt setting cannot be silently ignored.
    .PARAMETER ProjectPath
        Root of the consumer module's checkout.
    .OUTPUTS
        System.Collections.Hashtable with PSScriptAnalyzerExcludeRules, PesterExcludeTag and PesterStrictMode.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ProjectPath
    )

    $settings = @{
        PSScriptAnalyzerExcludeRules = [System.String[]] @()
        PesterExcludeTag             = [System.String[]] @()
        PesterStrictMode             = $false
    }

    $path = Join-Path -Path $ProjectPath -ChildPath 'Build' -AdditionalChildPath 'harness.psd1'
    if (-not (Test-Path -LiteralPath $path -PathType 'Leaf')) {
        return $settings
    }

    $data = Import-PowerShellDataFile -LiteralPath $path -ErrorAction 'Stop'
    foreach ($key in $data.Keys) {
        $value = $data[$key]
        switch ($key) {
            { $_ -in 'PSScriptAnalyzerExcludeRules', 'PesterExcludeTag' } {
                $items = @($value)
                if ($items.Where({ $_ -isnot [System.String] -or [System.String]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
                    $message = '{0} in [{1}] must be a string or an array of non-empty strings.' -f $key, $path
                    Write-Error -Message $message -ErrorAction 'Stop'
                }
                $settings[$key] = [System.String[]] $items
            }
            'PesterStrictMode' {
                if ($value -isnot [System.Boolean]) {
                    $message = 'PesterStrictMode in [{0}] must be $true or $false.' -f $path
                    Write-Error -Message $message -ErrorAction 'Stop'
                }
                $settings[$key] = $value
            }
            default {
                $allowed = 'PSScriptAnalyzerExcludeRules, PesterExcludeTag, PesterStrictMode'
                $message = 'Unknown key [{0}] in [{1}]. Allowed keys: {2}.' -f $key, $path, $allowed
                Write-Error -Message $message -ErrorAction 'Stop'
            }
        }
    }

    $settings
}

function Get-HarnessDependency {
    <#
    .SYNOPSIS
        Lists the modules a build needs: the harness's pinned build tools, then the module's runtime dependencies.
    .DESCRIPTION
        Build tools come from the harness's depend.psd1, each with its exact version. Runtime
        modules come from the consumer manifest's RequiredModules and float to the latest
        release unless the manifest declares a RequiredVersion. A ModuleVersion is a minimum,
        which the latest release satisfies. A MaximumVersion stops the build: resolving the
        newest release at or below it needs a version range, and PSResourceGet does not
        resolve a range to its newest member.
    .PARAMETER DependPath
        Path to the harness's depend.psd1.
    .PARAMETER ManifestPath
        Path to the consumer's module manifest.
    .OUTPUTS
        System.Management.Automation.PSCustomObject with Name, Version (null means latest) and Source.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $DependPath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ManifestPath
    )

    $buildTools = Import-PowerShellDataFile -LiteralPath $DependPath -ErrorAction 'Stop'
    foreach ($name in ($buildTools.Keys | Sort-Object)) {
        [PSCustomObject] @{ Name = $name; Version = $buildTools[$name]; Source = 'Build' }
    }

    $manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction 'Stop'
    if (-not $manifest.ContainsKey('RequiredModules')) {
        return
    }

    foreach ($entry in @($manifest['RequiredModules'])) {
        if ($entry -is [System.String]) {
            [PSCustomObject] @{ Name = $entry; Version = $null; Source = 'Manifest' }
            continue
        }

        $name = $entry['ModuleName']
        if ($entry.ContainsKey('MaximumVersion')) {
            $message = 'RequiredModules entry [{0}] declares MaximumVersion, which the harness does not resolve. Use RequiredVersion to pin, or remove it to float.' -f $name
            Write-Error -Message $message -ErrorAction 'Stop'
        }

        $version = if ($entry.ContainsKey('RequiredVersion')) { $entry['RequiredVersion'] } else { $null }
        [PSCustomObject] @{ Name = $name; Version = $version; Source = 'Manifest' }
    }
}

function Install-HarnessDependency {
    <#
    .SYNOPSIS
        Installs each dependency and reports the version that resolved.
    .DESCRIPTION
        A dependency with no version is installed without -Version, the only reliable way to
        get the latest release: a NuGet range resolves to an arbitrary member. Every module
        is then reported as 'Resolved dependency: <name> <version>'. With runtime modules
        floating, that line is the only record of what a build ran against.
    .PARAMETER Dependency
        Objects from Get-HarnessDependency.
    .OUTPUTS
        System.String, one resolved-dependency line per module.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSObject[]] $Dependency
    )

    foreach ($d in $Dependency) {
        # TRUSTREPOSITORY: PSGALLERY REGISTERS AS UNTRUSTED UNDER PSRESOURCEGET, SO THE INSTALL WOULD PROMPT.
        $installParams = @{
            Name            = $d.Name
            Repository      = 'PSGallery'
            TrustRepository = $true
            Scope           = 'CurrentUser'
            ErrorAction     = 'Stop'
        }
        if ($d.Version) {
            $installParams['Version'] = $d.Version
        }
        if ($PSCmdlet.ShouldProcess($d.Name, 'Install-PSResource')) {
            Install-PSResource @installParams
        }

        $installed = @(Get-InstalledPSResource -Name $d.Name -Scope 'CurrentUser' -ErrorAction 'Stop')
        $resolved = if ($d.Version) {
            $installed.Where({ $_.Version -eq [System.Version] $d.Version }, 'First')
        }
        else {
            $installed | Sort-Object -Property 'Version' -Descending | Select-Object -First 1
        }
        if (-not $resolved) {
            $message = 'Dependency [{0}] is not installed after Install-PSResource.' -f $d.Name
            Write-Error -Message $message -ErrorAction 'Stop'
        }
        'Resolved dependency: {0} {1}' -f $d.Name, @($resolved)[0].Version
    }
}

function Get-HarnessAnalyzerSetting {
    <#
    .SYNOPSIS
        Returns the PSScriptAnalyzer settings for a consumer: the shared file plus that repo's exclusions.
    .DESCRIPTION
        Used by the Analyze task and by pssa-sarif.yml, so the build gate and the Security tab
        apply the same rules. A repo's PSScriptAnalyzerExcludeRules never reaches another repo.
    .PARAMETER ProjectPath
        Root of the consumer module's checkout.
    .OUTPUTS
        System.Collections.Hashtable, accepted by Invoke-ScriptAnalyzer -Settings.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ProjectPath
    )

    $settings = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1')
    $exclude = (Get-HarnessSetting -ProjectPath $ProjectPath).PSScriptAnalyzerExcludeRules
    if ($exclude.Count -gt 0) {
        $settings['ExcludeRules'] = $exclude
    }
    $settings
}

function Invoke-HarnessAnalysis {
    <#
    .SYNOPSIS
        Analyses a consumer's whole checkout, as the Security tab reports it, without the harness checkout.
    .DESCRIPTION
        Invoke-ScriptAnalyzer -Recurse descends into dot-folders, so analysing the checkout root
        would also report the harness checked out at .harness/ (measured 2026-11-10). Each
        top-level item is analysed separately instead, skipping .harness and .git.
    .PARAMETER ProjectPath
        Root of the consumer module's checkout.
    .OUTPUTS
        Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ProjectPath
    )

    $settings = Get-HarnessAnalyzerSetting -ProjectPath $ProjectPath
    $items = @(Get-ChildItem -LiteralPath $ProjectPath -Force).Where({ $_.Name -notin '.harness', '.git' })
    foreach ($item in $items) {
        Invoke-ScriptAnalyzer -Path $item.FullName -Recurse -Settings $settings
    }
}

function Test-HarnessShim {
    <#
    .SYNOPSIS
        Returns whether a consumer's Build/build.ps1 matches the reference shim.
    .DESCRIPTION
        The shim must be identical in every consumer, so any difference is drift. Line
        endings are normalised first: with core.autocrlf=true, the Windows default, a
        checkout stores the shim with CRLF and a raw byte comparison would report drift
        that is not there. Returns $true when the consumer has no shim to compare.
    .PARAMETER ShimPath
        Path to the consumer's Build/build.ps1.
    .PARAMETER ReferencePath
        Path to the harness's templates/Build/build.ps1.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ShimPath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ReferencePath
    )

    if (-not (Test-Path -LiteralPath $ShimPath -PathType 'Leaf')) {
        return $true
    }
    $normalised = foreach ($path in $ShimPath, $ReferencePath) {
        (Get-Content -LiteralPath $path -Raw) -replace "`r`n", "`n"
    }
    $normalised[0] -ceq $normalised[1]
}

function Get-HarnessCommit {
    <#
    .SYNOPSIS
        Returns the commit the harness is running from.
    .DESCRIPTION
        Printed at the start of every run, so a CI log or a local run shows which harness
        built it. Returns 'unknown' when the harness directory is not a git checkout.
    .PARAMETER HarnessRoot
        Root of the harness checkout.
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $HarnessRoot
    )

    $sha = git -C $HarnessRoot rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $sha) {
        return 'unknown'
    }
    $sha.Trim()
}

function Get-HarnessSharedContainer {
    <#
    .SYNOPSIS
        Returns one Pester container per shared suite, each carrying the -Data its param block declares.
    .DESCRIPTION
        The shared suites in Build/SharedTests run against the consumer's project in the same
        Invoke-Pester call as its own tests. Each is given only the keys it declares, so a suite
        that takes ProjectPath alone is never handed ModuleName. Containers come back in file
        name order; the Test task appends them after the consumer's, so they run last.
    .PARAMETER SharedTestPath
        Folder holding the shared *.tests.ps1 files. Defaults to SharedTests beside this file.
    .PARAMETER ProjectPath
        Root of the consumer module's checkout.
    .PARAMETER ModuleName
        The consumer module's name.
    .OUTPUTS
        Pester.ContainerInfo, one per shared suite.
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String] $SharedTestPath = (Join-Path -Path $PSScriptRoot -ChildPath 'SharedTests'),
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ProjectPath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ModuleName
    )

    $available = @{ ProjectPath = $ProjectPath; ModuleName = $ModuleName }
    $suites = @(Get-ChildItem -LiteralPath $SharedTestPath -Filter '*.tests.ps1' -File | Sort-Object -Property 'Name')
    if ($suites.Count -eq 0) {
        Write-Error -Message ('No shared suites found in [{0}].' -f $SharedTestPath) -ErrorAction 'Stop'
    }
    foreach ($suite in $suites) {
        $paramBlock = [System.Management.Automation.Language.Parser]::ParseFile($suite.FullName, [ref] $null, [ref] $null).ParamBlock
        $declared = if ($paramBlock) { @($paramBlock.Parameters).ForEach({ $_.Name.VariablePath.UserPath }) } else { @() }
        $data = @{}
        foreach ($name in $declared) {
            if (-not $available.ContainsKey($name)) {
                Write-Error -Message ('Shared suite [{0}] declares [{1}], which the harness does not supply.' -f $suite.Name, $name) -ErrorAction 'Stop'
            }
            $data[$name] = $available[$name]
        }
        New-PesterContainer -Path $suite.FullName -Data $data
    }
}
