# ==============================================================================
# Filename: build.psake.ps1
# Version:  2.0.0 | Updated: 2026-11-09
# Author:   johnsarie27
# ==============================================================================
<#
.SYNOPSIS
    psake tasks for building, analysing, testing and packaging a consumer module.
.DESCRIPTION
    Run by Build/build.ps1, which resolves the project and publishes it through the
    HARNESS_* environment variables. Per-repo variation comes only from the consumer's
    optional Build/harness.psd1 and from -Properties (PesterScope).
.NOTES
    Strict mode is set here, at the top of the build file, because that is where it
    reaches psake task bodies; set in build.ps1 it does not (measured 2026-11-09,
    psake 5.0.4). The Test task turns it off around Invoke-Pester unless the consumer
    opts in with PesterStrictMode.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'psake shares Properties variables with every task; PSScriptAnalyzer cannot follow that scope.')]
param ()

Set-StrictMode -Version Latest
. (Join-Path -Path $PSScriptRoot -ChildPath 'Harness.Functions.ps1')


#region - PROPERTIES ===========================================================
# PSAKE EXPOSES THESE TO EVERY TASK; -Properties OVERRIDES THEM
Properties {
    $ProjectRoot = $env:HARNESS_PROJECT_PATH
    $ModuleName = $env:HARNESS_MODULE_NAME
    if (-not $ProjectRoot -or -not $ModuleName) {
        Write-Error -Message 'HARNESS_PROJECT_PATH and HARNESS_MODULE_NAME are not set. Run the harness through Build/build.ps1.' -ErrorAction 'Stop'
    }

    $HarnessSettings = Get-HarnessSetting -ProjectPath $ProjectRoot
    $lines = '----------------------------------------------------------------------'
    $TestFile = 'Test-Unit_{0}.xml' -f (Get-Date -UFormat '%Y%m%d-%H%M%S')

    # ALL, CROSSPLATFORM OR WINDOWSONLY; RESOLVED IN THE TEST TASK SO AN OVERRIDE TAKES EFFECT
    $PesterScope = 'All'

    [ValidateSet('Error', 'Warning', 'Any', 'None')]
    $ScriptAnalysisFailBuildOnSeverityLevel = 'Error'
    $ScriptAnalyzerSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'

    $ArtifactFolder = Join-Path -Path $ProjectRoot -ChildPath 'Artifacts'
    $StagingFolder = Join-Path -Path $ProjectRoot -ChildPath 'Staging'
    $StagingModulePath = Join-Path -Path $StagingFolder -ChildPath $ModuleName
    $StagingModuleManifestPath = Join-Path -Path $StagingModulePath -ChildPath ('{0}.psd1' -f $ModuleName)
}

#endregion =====================================================================


#region - PREPARE ==============================================================
# SHOW WHAT IS BEING BUILT, THEN RESET THE OUTPUT FOLDERS
Task 'Default' -depends 'Test'

Task 'Init' {
    $lines
    Set-Location -Path $ProjectRoot
    Write-Output -InputObject 'Build System Details:'
    Get-Item -Path 'Env:HARNESS_*'
}

Task 'Setup' -depends 'Init' {
    $lines
    foreach ($folderPath in @($ArtifactFolder, $StagingFolder)) {
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction 'SilentlyContinue'
        New-Item -Path $folderPath -ItemType 'Directory' -Force | Out-Null
    }
}

# STAGES ONLY; THE NAME IS KEPT SO CONSUMERS' DOCUMENTED COMMANDS KEEP WORKING
Task 'CombineFunctionsAndStage' -depends 'Setup' {
    $lines
    New-Item -Path $StagingModulePath -ItemType 'Directory' -Force | Out-Null

    # AN EMPTY REQUIRED DIRECTORY USUALLY MEANS LOST FILES OR A BAD CHECKOUT, SO IT FAILS LIKE A MISSING ONE
    $requiredPaths = @(
        Join-Path -Path $ProjectRoot -ChildPath 'Public'
        Join-Path -Path $ProjectRoot -ChildPath 'README.md'
        Join-Path -Path $ProjectRoot -ChildPath ('{0}.psd1' -f $ModuleName)
        Join-Path -Path $ProjectRoot -ChildPath ('{0}.psm1' -f $ModuleName)
    )
    foreach ($p in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Error -Message ('Required build input not found: [{0}]' -f $p) -ErrorAction 'Stop'
        }
        $isEmptyFolder = (Test-Path -LiteralPath $p -PathType 'Container') -and -not (Get-ChildItem -LiteralPath $p -File -Recurse)
        if ($isEmptyFolder) {
            Write-Error -Message ('Required build input directory is empty: [{0}]' -f $p) -ErrorAction 'Stop'
        }
    }

    $privatePath = Join-Path -Path $ProjectRoot -ChildPath 'Private'
    $pathsToCopy = $requiredPaths
    if (Test-Path -LiteralPath $privatePath -PathType 'Container') {
        $pathsToCopy += $privatePath
    }
    Copy-Item -Path $pathsToCopy -Destination $StagingModulePath -Recurse
}

Task 'ImportStagingModule' -depends 'Init', 'CombineFunctionsAndStage' {
    $lines
    Write-Output -InputObject ('Reloading staged module from path: [{0}]' -f $StagingModulePath)
    Remove-Module -Name $ModuleName -Force -ErrorAction 'SilentlyContinue'
    Import-Module -Name $StagingModulePath -Force -ErrorAction 'Stop'
}

#endregion =====================================================================


#region - VERIFY ===============================================================
# ANALYSE AND TEST THE STAGED MODULE
Task 'Analyze' -depends 'ImportStagingModule' {
    $lines
    Write-Output -InputObject ('Running PSScriptAnalyzer on path: [{0}]' -f $StagingModulePath)

    # THE SHARED SETTINGS PLUS ONLY THIS REPO'S EXCLUSIONS, SO ONE REPO'S EXCLUSION NEVER HIDES ANOTHER'S FINDING
    $analyzerSettings = Import-PowerShellDataFile -LiteralPath $ScriptAnalyzerSettingsPath
    if ($HarnessSettings.PSScriptAnalyzerExcludeRules.Count -gt 0) {
        $analyzerSettings['ExcludeRules'] = $HarnessSettings.PSScriptAnalyzerExcludeRules
        Write-Output -InputObject ('Excluding rules from Build/harness.psd1: {0}' -f ($HarnessSettings.PSScriptAnalyzerExcludeRules -join ', '))
    }
    $analyzeParams = @{
        Path     = $StagingModulePath
        Recurse  = $true
        Settings = $analyzerSettings
    }
    $results = @(Invoke-ScriptAnalyzer @analyzeParams)
    $results | Select-Object -Property 'RuleName', 'Severity', 'ScriptName', 'Line', 'Message' | Format-List

    $failing = switch ($ScriptAnalysisFailBuildOnSeverityLevel) {
        'None' { @() }
        'Error' { $results.Where({ $_.Severity -eq 'Error' }) }
        'Warning' { $results.Where({ $_.Severity -in 'Error', 'Warning' }) }
        'Any' { $results }
    }
    $failCount = @($failing).Count
    if ($failCount -gt 0) {
        $message = '{0} PSScriptAnalyzer finding(s) at or above [{1}]. Build cannot continue.' -f $failCount, $ScriptAnalysisFailBuildOnSeverityLevel
        Write-Error -Message $message -ErrorAction 'Stop'
    }
}

Task 'Test' -depends 'ImportStagingModule' {
    $lines

    # ONE FOLDER BELOW Tests/, AS EVERY REPO USES; NAMES MATCHED WITH -match, WHICH IGNORES CASE ON EVERY OS
    $testRoot = Join-Path -Path $ProjectRoot -ChildPath 'Tests'
    $candidates = @(Get-ChildItem -LiteralPath $testRoot -Directory -ErrorAction 'SilentlyContinue' | Get-ChildItem -File)
    $crossPlatform = $candidates.Where({ $_.Name -match '\.tests\.ps1$' })
    $windowsOnly = $candidates.Where({ $_.Name -match '\.tests\.windows\.ps1$' })

    $selected = switch ($PesterScope) {
        'All' { if ($IsWindows) { @($crossPlatform) + @($windowsOnly) } else { $crossPlatform } }
        'CrossPlatform' { $crossPlatform }
        'WindowsOnly' { $windowsOnly }
        default {
            Write-Error -Message ('Unknown PesterScope [{0}]. Expected All, CrossPlatform or WindowsOnly.' -f $PesterScope) -ErrorAction 'Stop'
        }
    }

    # RUN.PATH IS TYPED String[]; A SINGLE FileInfo FAILS COERCION, SO PASS AN ARRAY OF PATHS
    $testScripts = [System.String[]] @(@($selected).ForEach({ $_.FullName }))
    if ($testScripts.Count -eq 0) {
        Write-Error -Message ('No test files selected under [{0}] for PesterScope [{1}].' -f $testRoot, $PesterScope) -ErrorAction 'Stop'
    }
    Write-Output -InputObject ('PesterScope [{0}]: {1} test file(s)' -f $PesterScope, $testScripts.Count)

    $pesterConfig = New-PesterConfiguration
    $pesterConfig.TestResult.OutputFormat = 'JUnitXml'
    $pesterConfig.TestResult.OutputPath = Join-Path -Path $ArtifactFolder -ChildPath $TestFile
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Run.Path = $testScripts
    if ($HarnessSettings.PesterExcludeTag.Count -gt 0) {
        $pesterConfig.Filter.ExcludeTag = $HarnessSettings.PesterExcludeTag
        Write-Output -InputObject ('Excluding Pester tags from Build/harness.psd1: {0}' -f ($HarnessSettings.PesterExcludeTag -join ', '))
    }

    # THE HARNESS'S STRICT MODE WOULD OTHERWISE REACH THE CONSUMER'S TESTS
    if (-not $HarnessSettings.PesterStrictMode) {
        Set-StrictMode -Off
    }
    $testResults = Invoke-Pester -Configuration $pesterConfig
    Set-StrictMode -Version Latest

    # DISCOVERY ERRORS ATTACH TO THE CONTAINER, NOT A TEST, SO GATE ON THE RESULT RATHER THAN FailedCount
    if ($testResults.Result -ne 'Passed') {
        $message = 'Pester result [{0}] with [{1}] failed test(s). Build failed.' -f $testResults.Result, $testResults.FailedCount
        Write-Error -Message $message -ErrorAction 'Stop'
    }
}

#endregion =====================================================================


#region - PACKAGE ==============================================================
# ZIP THE STAGED MODULE; DEPENDS ON INIT ONLY, SO RESULTS FROM AN EARLIER TEST RUN SURVIVE
Task 'CreateBuildArtifact' -depends 'Init' {
    $lines
    New-Item -Path $ArtifactFolder -ItemType 'Directory' -Force | Out-Null

    $manifestVersion = (Test-ModuleManifest -Path $StagingModuleManifestPath -ErrorAction 'Stop').Version
    $releasePath = Join-Path -Path $ArtifactFolder -ChildPath ('{0}-v{1}.zip' -f $ModuleName, $manifestVersion)
    Write-Output -InputObject ('Creating release artifact [{0}] using manifest version [{1}]' -f $releasePath, $manifestVersion)

    $compressParams = @{
        Path            = Join-Path -Path $StagingFolder -ChildPath '*'
        DestinationPath = $releasePath
        Force           = $true
        ErrorAction     = 'Stop'
    }
    Compress-Archive @compressParams
}

Task 'Cleanup' {
    $lines
    Write-Output -InputObject 'Cleaning leftover/unneeded artifacts'
    Remove-Item -Path $ArtifactFolder -Recurse -Force -ErrorAction 'SilentlyContinue'
    Remove-Item -Path $StagingFolder -Recurse -Force -ErrorAction 'SilentlyContinue'
}

#endregion =====================================================================
