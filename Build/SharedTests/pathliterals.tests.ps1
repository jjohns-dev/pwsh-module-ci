[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester builds cases in BeforeDiscovery and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester passes -Data to the file and reads the parameter inside BeforeDiscovery.')]
param (
    [System.String] $ProjectPath
)

# ONE CASE PER PUBLIC FILE, BUILT AT DISCOVERY FROM -Data
BeforeDiscovery {
    if ([System.String]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Error -Message 'ProjectPath must be passed with New-PesterContainer -Data.' -ErrorAction 'Stop'
    }
    $publicCases = @(Get-ChildItem -LiteralPath (Join-Path -Path $ProjectPath -ChildPath 'Public') -Filter '*.ps1' -File).ForEach({
            @{ File = $_.Name; FullName = $_.FullName }
        })
}

Describe -Name 'Shared: path literals in Public functions' -Fixture {
    # ON LINUX AND macOS A BACKSLASH IS A FILENAME CHARACTER, NOT A SEPARATOR; ONLY STRINGS ARE SCANNED, SO COMMENTS AND HELP DO NOT COUNT
    It -Name 'has no backslash after $HOME, $PSScriptRoot, $PWD or $TestDrive in a string in <File>' -ForEach $publicCases -Test {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref] $null, [ref] $null)
        $isPathLiteral = {
            param ($node)
            ($node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and
            $node.Extent.Text -match '\$(HOME|PSScriptRoot|PWD|TestDrive)\\'
        }
        # FindAll RETURNS AN IEnumerable, ON WHICH .ForEach() SEES ONE ITEM, SO ENUMERATE WITH foreach
        $offenders = foreach ($node in $ast.FindAll($isPathLiteral, $true)) {
            'line {0}: {1}' -f $node.Extent.StartLineNumber, $node.Extent.Text
        }
        $offenders | Should -BeNullOrEmpty -Because ('use Join-Path instead: {0}' -f ($offenders -join '; '))
    }
}
