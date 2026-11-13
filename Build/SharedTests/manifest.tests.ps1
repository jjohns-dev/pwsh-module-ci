[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester passes -Data to the file and reads the parameters inside BeforeAll and It blocks.')]
param (
    [System.String] $ProjectPath,
    [System.String] $ModuleName
)

# RUN BY THE HARNESS'S Test TASK WITH New-PesterContainer -Data; NOT MANDATORY, WHICH WOULD PROMPT INSTEAD OF FAILING
BeforeAll {
    if ([System.String]::IsNullOrWhiteSpace($ProjectPath) -or [System.String]::IsNullOrWhiteSpace($ModuleName)) {
        Write-Error -Message 'ProjectPath and ModuleName must be passed with New-PesterContainer -Data.' -ErrorAction 'Stop'
    }
    $manifestPath = Join-Path -Path $ProjectPath -ChildPath ('{0}.psd1' -f $ModuleName)
    $declared = Import-PowerShellDataFile -LiteralPath $manifestPath
    $publicFiles = @(Get-ChildItem -LiteralPath (Join-Path -Path $ProjectPath -ChildPath 'Public') -Filter '*.ps1' -File)
    # JOINED SO AN EMPTY SIDE CANNOT PASS VACUOUSLY
    $publicNames = (@($publicFiles.ForEach({ $_.BaseName })) | Sort-Object) -join ','
}

Describe -Name 'Shared: module manifest' -Fixture {
    It -Name 'passes Test-ModuleManifest' -Test {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction 'Stop' -WarningAction 'SilentlyContinue' } | Should -Not -Throw
    }
    It -Name 'names the module''s .psm1 as RootModule' -Test {
        $declared['RootModule'] | Should -Be ('{0}.psm1' -f $ModuleName)
    }
    It -Name 'declares a non-empty <_>' -ForEach @('Description', 'Author', 'Copyright') -Test {
        [System.String]::IsNullOrWhiteSpace([System.String] $declared[$_]) | Should -BeFalse
    }
    It -Name 'declares at least one function in FunctionsToExport' -Test {
        @(@($declared['FunctionsToExport']).Where({ -not [System.String]::IsNullOrWhiteSpace($_) })).Count | Should -BeGreaterThan 0
    }
    It -Name 'declares exactly the functions backed by a Public/ file' -Test {
        (@($declared['FunctionsToExport']) | Sort-Object) -join ',' | Should -Be $publicNames
    }
    It -Name 'declares no wildcard in any export field' -Test {
        $fields = 'FunctionsToExport', 'CmdletsToExport', 'VariablesToExport', 'AliasesToExport'
        $wildcards = foreach ($field in $fields) {
            foreach ($entry in @($declared[$field]).Where({ ([System.String] $_).Contains('*') })) {
                '{0} = {1}' -f $field, $entry
            }
        }
        $wildcards | Should -BeNullOrEmpty -Because 'a wildcard export makes PowerShell load the module to resolve its surface and can export private helpers'
    }
    It -Name 'declares a ProjectUri in PrivateData.PSData' -Test {
        $projectUri = $null
        $privateData = $declared['PrivateData']
        if ($privateData -is [System.Collections.IDictionary] -and $privateData['PSData'] -is [System.Collections.IDictionary]) {
            $projectUri = $privateData['PSData']['ProjectUri']
        }
        [System.String]::IsNullOrWhiteSpace([System.String] $projectUri) | Should -BeFalse
    }
    It -Name 'declares a PowerShellVersion of 5.1, or from 7.0 up to the running PowerShell' -Test {
        $declaredVersion = [System.String] $declared['PowerShellVersion']
        $parsed = $null
        $isVersion = [System.Version]::TryParse($declaredVersion, [ref] $parsed)
        $running = [System.Version]::new($PSVersionTable.PSVersion.Major, $PSVersionTable.PSVersion.Minor, $PSVersionTable.PSVersion.Patch)
        $isValid = $isVersion -and (($parsed.Major -eq 5 -and $parsed.Minor -eq 1) -or ($parsed -ge [System.Version] '7.0' -and $parsed -le $running))
        $isValid | Should -BeTrue -Because ('PowerShellVersion [{0}] must be 5.1, or 7.0 to {1}' -f $declaredVersion, $running)
    }
    It -Name 'exports every Public/ function once the staged module is imported' -Test {
        # A Public/ FILE WHOSE FUNCTION IS MISNAMED IMPORTS CLEANLY AND EXPORTS NOTHING; ONLY A REAL IMPORT SHOWS IT
        $stagedPath = Join-Path -Path $ProjectPath -ChildPath 'Staging' -AdditionalChildPath $ModuleName
        $module = Import-Module -Name $stagedPath -Force -PassThru -ErrorAction 'Stop'
        (@($module.ExportedFunctions.Keys) | Sort-Object) -join ',' | Should -Be $publicNames
    }
}
