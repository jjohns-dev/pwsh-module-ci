[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester builds cases in BeforeDiscovery and assigns fixtures in BeforeAll for use in It blocks; PSScriptAnalyzer cannot follow that scope.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester passes -Data to the file and reads the parameters inside BeforeDiscovery and BeforeAll.')]
param (
    [System.String] $ProjectPath,
    [System.String] $ModuleName
)

# ONE CASE PER EXPORTED FUNCTION, BY NAME: BeforeDiscovery VARIABLES DO NOT REACH THE RUN PHASE
BeforeDiscovery {
    if ([System.String]::IsNullOrWhiteSpace($ProjectPath) -or [System.String]::IsNullOrWhiteSpace($ModuleName)) {
        Write-Error -Message 'ProjectPath and ModuleName must be passed with New-PesterContainer -Data.' -ErrorAction 'Stop'
    }
    $stagedPath = Join-Path -Path $ProjectPath -ChildPath 'Staging' -AdditionalChildPath $ModuleName
    $discovered = Import-Module -Name $stagedPath -Force -PassThru -ErrorAction 'Stop'
    $functionCases = @(@($discovered.ExportedFunctions.PSBase.Keys) | Sort-Object).ForEach({ @{ Name = $_ } })
}

BeforeAll {
    if ([System.String]::IsNullOrWhiteSpace($ProjectPath) -or [System.String]::IsNullOrWhiteSpace($ModuleName)) {
        Write-Error -Message 'ProjectPath and ModuleName must be passed with New-PesterContainer -Data.' -ErrorAction 'Stop'
    }
    # THE RETURNED MODULE, NOT A NAME LOOKUP: A CONSUMER TEST MAY HAVE REMOVED IT, AND ANOTHER COMMAND COULD SHADOW A NAME
    $stagedPath = Join-Path -Path $ProjectPath -ChildPath 'Staging' -AdditionalChildPath $ModuleName
    $module = Import-Module -Name $stagedPath -Force -PassThru -ErrorAction 'Stop'
    $commonParameters = @([System.Management.Automation.PSCmdlet]::CommonParameters) + @([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)

    # THE AST, NOT Get-Help: Get-Help INVENTS AN ENTRY FOR AN UNDOCUMENTED PARAMETER AND DROPS ONE NAMING NO PARAMETER
    function Get-SharedHelpContent ([System.String] $Name) {
        $module.ExportedFunctions[$Name].ScriptBlock.Ast.GetHelpContent()
    }
}

Describe -Name 'Shared: comment-based help' -Fixture {
    It -Name '<Name> has a synopsis' -ForEach $functionCases -AllowNullOrEmptyForEach -Test {
        $help = Get-SharedHelpContent -Name $Name
        $help | Should -Not -BeNullOrEmpty -Because ('{0} has no comment-based help' -f $Name)
        [System.String]::IsNullOrWhiteSpace($help.Synopsis) | Should -BeFalse -Because ('{0} has an empty .SYNOPSIS' -f $Name)
    }
    It -Name '<Name> has a description' -ForEach $functionCases -AllowNullOrEmptyForEach -Test {
        $help = Get-SharedHelpContent -Name $Name
        $help | Should -Not -BeNullOrEmpty -Because ('{0} has no comment-based help' -f $Name)
        [System.String]::IsNullOrWhiteSpace($help.Description) | Should -BeFalse -Because ('{0} has an empty .DESCRIPTION' -f $Name)
    }
    It -Name '<Name> has an example' -ForEach $functionCases -AllowNullOrEmptyForEach -Test {
        $help = Get-SharedHelpContent -Name $Name
        $help | Should -Not -BeNullOrEmpty -Because ('{0} has no comment-based help' -f $Name)
        $examples = @($help.Examples).Where({ -not [System.String]::IsNullOrWhiteSpace($_) })
        $examples | Should -Not -BeNullOrEmpty -Because ('{0} has no .EXAMPLE' -f $Name)
    }
    It -Name '<Name> documents exactly its parameters' -ForEach $functionCases -AllowNullOrEmptyForEach -Test {
        $help = Get-SharedHelpContent -Name $Name
        $help | Should -Not -BeNullOrEmpty -Because ('{0} has no comment-based help' -f $Name)
        $command = $module.ExportedFunctions[$Name]
        # .PSBase: A PARAMETER NAMED Keys WOULD OTHERWISE BE RETURNED IN PLACE OF THE KEY LIST
        $declared = @($command.Parameters.PSBase.Keys).Where({ $_ -notin $commonParameters })
        $documented = @($help.Parameters.PSBase.Keys)
        # A DynamicParam BLOCK EMITS ITS PARAMETERS ONLY WHEN THE COMMAND IS BOUND, SO THEY CANNOT BE LISTED HERE
        $hasDynamic = $null -ne $command.ScriptBlock.Ast.Body.DynamicParamBlock
        $problems = @(
            foreach ($p in $declared) {
                $entry = @($documented).Where({ $_ -eq $p }, 'First')
                if (-not $entry) {
                    'parameter [{0}] has no .PARAMETER entry' -f $p
                }
                elseif ([System.String]::IsNullOrWhiteSpace($help.Parameters[$entry[0]])) {
                    'parameter [{0}] has an empty .PARAMETER entry' -f $p
                }
            }
            if (-not $hasDynamic) {
                foreach ($d in $documented) {
                    if ($d -notin $declared) {
                        '.PARAMETER [{0}] names no declared parameter' -f $d
                    }
                }
            }
        )
        $problems | Should -BeNullOrEmpty -Because ('{0}: {1}' -f $Name, ($problems -join '; '))
    }
    It -Name 'has a well-formed absolute http or https URI in every .LINK' -Test {
        # A .LINK NAMING A COMMAND OR TOPIC HAS NO SCHEME AND IS NOT A URI; ONLY THE FORM IS CHECKED, NEVER REQUESTED
        $offenders = foreach ($name in @(@($module.ExportedFunctions.PSBase.Keys) | Sort-Object)) {
            $help = Get-SharedHelpContent -Name $name
            if (-not $help) {
                continue
            }
            foreach ($link in @($help.Links).ForEach({ ([System.String] $_).Trim() })) {
                if ($link -notmatch '^[A-Za-z][A-Za-z0-9+.-]*:') {
                    continue
                }
                # BOTH: THE PATTERN REJECTS htp:/x AND ftp://x, WHICH IsWellFormedUriString ACCEPTS, AND VICE VERSA FOR https://x/a^b
                $isHttp = $link -match '^https?://'
                $isWellFormed = [System.Uri]::IsWellFormedUriString($link, [System.UriKind]::Absolute)
                if (-not ($isHttp -and $isWellFormed)) {
                    '{0}: {1}' -f $name, $link
                }
            }
        }
        $offenders | Should -BeNullOrEmpty -Because ('each .LINK URI must be a well-formed absolute http or https URI: {0}' -f ($offenders -join '; '))
    }
}
