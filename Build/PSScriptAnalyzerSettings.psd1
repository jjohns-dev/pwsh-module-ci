@{
    # SHARED BY EVERY CONSUMER. A REPO THAT NEEDS A RULE EXCLUDED SETS PSScriptAnalyzerExcludeRules IN ITS
    # OWN Build/harness.psd1, SO AN EXCLUSION NEVER HIDES A FINDING IN THE OTHER REPOS.
    Severity = @('Error', 'Warning')
}
