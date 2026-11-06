<#
.SYNOPSIS
    Verifies the "Verify Pester results" step shipped in the reusable workflows.
.DESCRIPTION
    Extracts the step body directly out of the workflow YAML and runs it against
    fixture result files, so the code under test is the code that ships rather
    than a copy that can drift away from it.
    The step guards against a build reporting green after collecting a fraction
    of its suite. Its failure mode is silently never firing, which is
    indistinguishable from passing, so each fixture asserts a direction: some
    must fail the step and some must leave it quiet.
    Exits non-zero if any case disagrees with its expectation, or if the two
    workflows have drifted apart.
.NOTES
    Cannot cover the step's `if:` condition, which is workflow orchestration
    rather than script logic. That requires a real run with an earlier step
    failing.
    The powershell-yaml dependency is imported rather than declared with
    `#Requires -Modules`, which would be the house convention. Under
    `pwsh -File`, a script carrying `#Requires -Modules` always exits 0 even
    when it calls `exit 1`, which would make this test permanently green --
    the exact failure mode it exists to catch. Verified on PowerShell 7.6.6.
#>

$ErrorActionPreference = 'Stop'

#region - CONFIGURATION ========================================================
# SEE .NOTES: DO NOT REPLACE THIS WITH #Requires -Modules
Import-Module -Name 'powershell-yaml' -ErrorAction Stop

# WORKFLOWS CARRYING THE STEP, AND THE FIXTURES THAT EXERCISE IT
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$workflowRoot = Join-Path -Path $repoRoot -ChildPath '.github/workflows'
$fixtureRoot = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures'
$stepName = 'Verify Pester results'
$workflowNames = @('ci.yml', 'release.yml')

# SHOULDFAIL IS THE POINT OF EACH CASE: A CHECK THAT NEVER FIRES LOOKS LIKE A PASS
$cases = @(
    @{ Description = 'container error with FailedCount 0'; Fixture = 'Test-FalseGreen.xml'; ShouldFail = $true }
    @{ Description = 'healthy run'; Fixture = 'Test-Healthy.xml'; ShouldFail = $false }
    @{ Description = 'no tests collected'; Fixture = 'Test-ZeroTests.xml'; ShouldFail = $true }
    @{ Description = 'genuine assertion failures'; Fixture = 'Test-Failures.xml'; ShouldFail = $false }
    @{ Description = 'NUnit root element'; Fixture = 'Test-NUnitRoot.xml'; ShouldFail = $true }
    @{ Description = 'malformed count attributes'; Fixture = 'Test-MalformedCounts.xml'; ShouldFail = $true }
    @{ Description = 'no result file at all'; Fixture = $null; ShouldFail = $true }
    @{ Description = 'below min-tests floor'; Fixture = 'Test-Healthy.xml'; MinTests = 433; ShouldFail = $true }
    @{ Description = 'exactly at min-tests floor'; Fixture = 'Test-Healthy.xml'; MinTests = 432; ShouldFail = $false }
    @{ Description = 'min-tests 0 disables the floor'; Fixture = 'Test-Healthy.xml'; MinTests = 0; ShouldFail = $false }
    # THE REGRESSION THIS STEP EXISTS TO CATCH: 'tests' IS UNCHANGED, THE SUITE STOPPED RUNNING
    @{ Description = 'mass skip: collected meets the floor but executed does not'; Fixture = 'Test-MassSkip.xml'; MinTests = 432; ShouldFail = $true }
    @{ Description = 'mass skip: executed exactly at the floor'; Fixture = 'Test-MassSkip.xml'; MinTests = 332; ShouldFail = $false }
    @{ Description = 'some skips, executed still clears the floor'; Fixture = 'Test-SomeSkipped.xml'; MinTests = 400; ShouldFail = $false }
    @{ Description = 'some skips, executed falls below the floor'; Fixture = 'Test-SomeSkipped.xml'; MinTests = 425; ShouldFail = $true }
)

#endregion ====================================================================


#region - EXTRACT THE STEP BODY FROM EACH WORKFLOW =============================
# PULLING THE RUN BLOCK OUT OF THE YAML IS WHAT MAKES DRIFT IMPOSSIBLE
$stepBodies = [System.Collections.Specialized.OrderedDictionary]::new()

foreach ($workflowName in $workflowNames) {
    $workflowPath = Join-Path -Path $workflowRoot -ChildPath $workflowName
    $document = ConvertFrom-Yaml -Yaml (Get-Content -Path $workflowPath -Raw)
    $body = $null

    foreach ($job in $document['jobs'].Values) {
        foreach ($step in $job['steps']) {
            if ($step['name'] -eq $stepName) {
                $body = $step['run']
            }
        }
    }

    if ([System.String]::IsNullOrWhiteSpace($body)) {
        Write-Error -Message ('No step named [{0}] found in [{1}].' -f $stepName, $workflowName) -ErrorAction Stop
    }

    $stepBodies[$workflowName] = $body
}

#endregion ====================================================================


#region - DRIFT CHECK ==========================================================
# THE TWO WORKFLOWS CARRY THE SAME CHECK; SILENT DIVERGENCE IS THE HAZARD
$reference = $stepBodies[$workflowNames[0]]

foreach ($workflowName in $workflowNames) {
    if ($stepBodies[$workflowName] -cne $reference) {
        $message = 'The [{0}] step body in [{1}] has drifted from [{2}]. Keep them identical.'
        Write-Error -Message ($message -f $stepName, $workflowName, $workflowNames[0]) -ErrorAction Stop
    }
}

Write-Output ('Step body is identical across: {0}' -f ($workflowNames -join ', '))

#endregion ====================================================================


#region - RUN EACH FIXTURE THROUGH THE EXTRACTED STEP ==========================
# THE STEP RESOLVES ARTIFACTS RELATIVE TO THE WORKING DIRECTORY, SO EACH CASE
# GETS ITS OWN SANDBOX
$workingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('verify-step-{0}' -f [System.Guid]::NewGuid())
$stepScript = Join-Path -Path $workingRoot -ChildPath 'Verify-PesterResult.ps1'
New-Item -Path $workingRoot -ItemType 'Directory' -Force | Out-Null
Set-Content -Path $stepScript -Value $reference -Encoding 'utf8'

# A NATIVE NON-ZERO EXIT IS THE RESULT BEING MEASURED, NOT AN ERROR TO RETHROW
$PSNativeCommandUseErrorActionPreference = $false
$failures = [System.Collections.Generic.List[System.String]]::new()

try {
    foreach ($case in $cases) {
        $caseRoot = Join-Path -Path $workingRoot -ChildPath ([System.Guid]::NewGuid())
        $artifactRoot = Join-Path -Path $caseRoot -ChildPath 'Artifacts'
        New-Item -Path $artifactRoot -ItemType 'Directory' -Force | Out-Null

        if ($case.Fixture) {
            $copyParams = @{
                Path        = Join-Path -Path $fixtureRoot -ChildPath $case.Fixture
                Destination = Join-Path -Path $artifactRoot -ChildPath $case.Fixture
            }
            Copy-Item @copyParams
        }

        # STANDS IN FOR THE STEP'S env: BLOCK, WHICH THIS HARNESS DOES NOT PARSE;
        # A CASE WITHOUT MinTests LEAVES IT UNSET
        $env:MIN_TESTS = $case.MinTests
        Push-Location -Path $caseRoot
        try {
            $output = & pwsh -NoProfile -File $stepScript 2>&1 | Out-String
            $stepFailed = ($LASTEXITCODE -ne 0)
        }
        finally {
            Pop-Location
            $env:MIN_TESTS = $null
        }

        if ($stepFailed -eq $case.ShouldFail) {
            $verdict = if ($case.ShouldFail) { 'fails as expected' } else { 'stays quiet as expected' }
            Write-Output ('  PASS  {0} -- {1}' -f $case.Description, $verdict)
        }
        else {
            $expectation = if ($case.ShouldFail) { 'fail' } else { 'pass' }
            $failures.Add(('{0}: expected the step to {1}' -f $case.Description, $expectation))
            Write-Output ('  FAIL  {0} -- expected to {1}' -f $case.Description, $expectation)
            Write-Output ($output.Trim())
        }
    }
}
finally {
    Remove-Item -Path $workingRoot -Recurse -Force -ErrorAction 'SilentlyContinue'
}

#endregion ====================================================================


#region - THE TEST STEP'S SCOPE BRANCH =========================================
# ci.yml's Test step is the second run: block in this repo carrying real logic.
# The branch matters because passing @{ PesterScope = '' } would override a
# consumer's psake default with nothing -- and no CI run can tell that apart
# from working, because a repo with no PesterScope property behaves identically
# either way. A stub build.ps1 records how it was actually called.
$ciDocument = ConvertFrom-Yaml -Yaml (Get-Content -Path (Join-Path -Path $workflowRoot -ChildPath 'ci.yml') -Raw)
$testStepBody = $null

foreach ($job in $ciDocument['jobs'].Values) {
    foreach ($step in $job['steps']) {
        if ($step['id'] -eq 'pester') {
            $testStepBody = $step['run']
        }
    }
}

if ([System.String]::IsNullOrWhiteSpace($testStepBody)) {
    Write-Error -Message 'No step with id [pester] found in [ci.yml].' -ErrorAction Stop
}

$scopeCases = @(
    @{ Description = 'no scope supplied'; Scope = $null; ExpectProperties = $false }
    @{ Description = 'whitespace-only scope'; Scope = '   '; ExpectProperties = $false }
    @{ Description = 'scope supplied'; Scope = 'CrossPlatform'; ExpectProperties = $true }
)

# ContainsKey is the whole point: it separates "omitted" from "passed empty".
$stubBuild = @(
    'param('
    '    [System.String] $TaskList,'
    '    [System.Collections.Hashtable] $Properties,'
    '    [System.Management.Automation.SwitchParameter] $ResolveDependency'
    ')'
    '$record = [ordered] @{'
    '    TaskList      = $TaskList'
    '    HasProperties = $PSBoundParameters.ContainsKey(''Properties'')'
    '    PesterScope   = if ($Properties) { $Properties[''PesterScope''] } else { $null }'
    '}'
    '$record | ConvertTo-Json -Compress | Set-Content -Path ''invocation.json'' -Encoding ''utf8'''
) -join [System.Environment]::NewLine

$scopeRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('test-step-{0}' -f [System.Guid]::NewGuid())

try {
    foreach ($case in $scopeCases) {
        $caseRoot = Join-Path -Path $scopeRoot -ChildPath ([System.Guid]::NewGuid())
        New-Item -Path (Join-Path -Path $caseRoot -ChildPath 'Build') -ItemType 'Directory' -Force | Out-Null
        Set-Content -Path (Join-Path -Path $caseRoot -ChildPath 'Build/build.ps1') -Value $stubBuild -Encoding 'utf8'

        $caseScript = Join-Path -Path $caseRoot -ChildPath 'Invoke-TestStep.ps1'
        Set-Content -Path $caseScript -Value $testStepBody -Encoding 'utf8'

        $env:PESTER_SCOPE = $case.Scope
        Push-Location -Path $caseRoot
        try {
            & pwsh -NoProfile -File $caseScript 2>&1 | Out-Null
        }
        finally {
            Pop-Location
            $env:PESTER_SCOPE = $null
        }

        $recordPath = Join-Path -Path $caseRoot -ChildPath 'invocation.json'

        if (-not (Test-Path -LiteralPath $recordPath)) {
            $failures.Add(('scope branch, {0}: build.ps1 was never invoked' -f $case.Description))
            Write-Output ('  FAIL  scope branch, {0} -- build.ps1 was never invoked' -f $case.Description)
            continue
        }

        $record = Get-Content -Path $recordPath -Raw | ConvertFrom-Json
        $matched = ($record.HasProperties -eq $case.ExpectProperties)

        if ($matched -and $case.ExpectProperties) {
            $matched = ($record.PesterScope -ceq $case.Scope)
        }

        if ($matched) {
            $verdict = if ($case.ExpectProperties) { 'passes -Properties carrying the scope' } else { 'omits -Properties entirely' }
            Write-Output ('  PASS  scope branch, {0} -- {1}' -f $case.Description, $verdict)
        }
        else {
            $detail = 'HasProperties={0} PesterScope=[{1}]' -f $record.HasProperties, $record.PesterScope
            $failures.Add(('scope branch, {0}: {1}' -f $case.Description, $detail))
            Write-Output ('  FAIL  scope branch, {0} -- {1}' -f $case.Description, $detail)
        }
    }
}
finally {
    Remove-Item -Path $scopeRoot -Recurse -Force -ErrorAction 'SilentlyContinue'
}

#endregion ====================================================================


#region - THE NORMALIZE STEP ===================================================
# The third run: block in this repo carrying real logic. The single-entry case
# matters most: PS.Log passes '["ubuntu-latest"]', and PowerShell is known to
# unwrap one-element arrays, which would emit an object where GitHub needs a
# JSON array and break that consumer's matrix.
$normalizeBody = $null

foreach ($job in $ciDocument['jobs'].Values) {
    foreach ($step in $job['steps']) {
        if ($step['id'] -eq 'norm') {
            $normalizeBody = $step['run']
        }
    }
}

if ([System.String]::IsNullOrWhiteSpace($normalizeBody)) {
    Write-Error -Message 'No step with id [norm] found in [ci.yml].' -ErrorAction Stop
}

$normalizeCases = @(
    @{ Description = 'single OS string, the PS.Log shape'; Input = '["ubuntu-latest"]'; ExpectOs = @('ubuntu-latest') }
    @{ Description = 'three OS strings, the default'; Input = '["ubuntu-latest", "windows-latest", "macos-latest"]'; ExpectOs = @('ubuntu-latest', 'windows-latest', 'macos-latest') }
    @{ Description = 'objects keep their per-leg values'; Input = '[{"os":"ubuntu-latest","pesterScope":"CrossPlatform","minTests":986}]'; ExpectOs = @('ubuntu-latest'); ExpectMinTests = 986 }
    @{ Description = 'invalid JSON'; Input = 'not json at all'; ShouldFail = $true }
    @{ Description = 'empty array'; Input = '[]'; ShouldFail = $true }
    @{ Description = 'object with no os key'; Input = '[{"pesterScope":"CrossPlatform"}]'; ShouldFail = $true }
)

$normalizeRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('normalize-{0}' -f [System.Guid]::NewGuid())
$normalizeScript = Join-Path -Path $normalizeRoot -ChildPath 'Invoke-Normalize.ps1'
New-Item -Path $normalizeRoot -ItemType 'Directory' -Force | Out-Null
Set-Content -Path $normalizeScript -Value $normalizeBody -Encoding 'utf8'

try {
    foreach ($case in $normalizeCases) {
        $outputFile = Join-Path -Path $normalizeRoot -ChildPath ('{0}.txt' -f [System.Guid]::NewGuid())
        New-Item -Path $outputFile -ItemType 'File' -Force | Out-Null

        $env:OS_MATRIX = $case.Input
        $env:GITHUB_OUTPUT = $outputFile
        try {
            & pwsh -NoProfile -File $normalizeScript 2>&1 | Out-Null
            $stepFailed = ($LASTEXITCODE -ne 0)
        }
        finally {
            $env:OS_MATRIX = $null
            $env:GITHUB_OUTPUT = $null
        }

        if ($case.ShouldFail) {
            if ($stepFailed) {
                Write-Output ('  PASS  normalize, {0} -- rejected as expected' -f $case.Description)
            }
            else {
                $failures.Add(('normalize, {0}: expected the step to fail' -f $case.Description))
                Write-Output ('  FAIL  normalize, {0} -- expected rejection' -f $case.Description)
            }
            continue
        }

        $emitted = (Get-Content -Path $outputFile -Raw) -replace '^matrix=', ''
        $emitted = $emitted.Trim()

        # A one-element array that collapsed to an object is the regression this
        # case exists to catch, so assert the shape before the contents.
        if (-not $emitted.StartsWith('[')) {
            $failures.Add(('normalize, {0}: emitted an object, not an array: {1}' -f $case.Description, $emitted))
            Write-Output ('  FAIL  normalize, {0} -- not a JSON array: {1}' -f $case.Description, $emitted)
            continue
        }

        $entries = @($emitted | ConvertFrom-Json)
        $actualOs = @($entries | ForEach-Object { $_.os })
        $matched = (($actualOs -join ',') -ceq ($case.ExpectOs -join ','))

        if ($matched -and $case.ContainsKey('ExpectMinTests')) {
            $matched = ([int] $entries[0].minTests -eq [int] $case.ExpectMinTests)
        }

        if ($matched) {
            Write-Output ('  PASS  normalize, {0} -- {1} leg(s), values intact' -f $case.Description, $entries.Count)
        }
        else {
            $failures.Add(('normalize, {0}: got {1}' -f $case.Description, $emitted))
            Write-Output ('  FAIL  normalize, {0} -- got {1}' -f $case.Description, $emitted)
        }
    }
}
finally {
    Remove-Item -Path $normalizeRoot -Recurse -Force -ErrorAction 'SilentlyContinue'
}

#endregion ====================================================================


#region - REPORT ===============================================================
# NON-ZERO EXIT IS WHAT FAILS THE WORKFLOW JOB
$caseCount = $cases.Count + $scopeCases.Count + $normalizeCases.Count

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output ('::error::{0}' -f $failure)
    }
    Write-Output ('{0} of {1} case(s) disagreed with expectation.' -f $failures.Count, $caseCount)
    exit 1
}

Write-Output ('All {0} cases behaved as expected.' -f $caseCount)

# EXPLICIT: $LASTEXITCODE STILL HOLDS THE LAST FIXTURE'S NON-ZERO EXIT, AND
# shell: pwsh EXITS WITH IT UNLESS THE SCRIPT SAYS OTHERWISE
exit 0

#endregion ====================================================================
