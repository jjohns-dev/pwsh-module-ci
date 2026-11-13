[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester assigns fixtures in BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Pester passes -Data to the file and reads the parameter inside BeforeAll.')]
param (
    [System.String] $ProjectPath
)

# ONE TEST PER CHECK, NOT PER FILE, SO THE COUNT IS FIXED AND THE min-tests FLOOR DOES NOT TRACK FILE COUNT
BeforeAll {
    if ([System.String]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Error -Message 'ProjectPath must be passed with New-PesterContainer -Data.' -ErrorAction 'Stop'
    }
    # THE TYPES THE CONSUMERS' MetaFixers Get-TextFilesList CHECKED; .gitignore AND .gitattributes ARE THEIR OWN EXTENSION
    $textExtensions = '.ps1', '.psm1', '.psd1', '.json', '.xml', '.cmd', '.mof', '.gitignore', '.gitattributes'
    # -Force SO DOT-FOLDERS ARE SCANNED ON EVERY OS; WITHOUT IT ONLY WINDOWS LISTS THEM
    $candidates = @(Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Force).Where({ $_.Extension -in $textExtensions })
    $sourceFiles = @($candidates.Where({ [System.IO.Path]::GetRelativePath($ProjectPath, $_.FullName) -notmatch '(^|[\\/])(\.git|Staging|Artifacts)([\\/]|$)' }))
    if ($sourceFiles.Count -eq 0) {
        Write-Error -Message ('No {0} files found under [{1}].' -f ($textExtensions -join ', '), $ProjectPath) -ErrorAction 'Stop'
    }
    $bom = [System.Collections.Generic.List[System.String]]::new()
    $tab = [System.Collections.Generic.List[System.String]]::new()
    $nul = [System.Collections.Generic.List[System.String]]::new()
    foreach ($file in $sourceFiles) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $relative = [System.IO.Path]::GetRelativePath($ProjectPath, $file.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $bom.Add($relative)
        }
        if ([System.Array]::IndexOf($bytes, [System.Byte] 9) -ge 0) {
            $tab.Add($relative)
        }
        if ([System.Array]::IndexOf($bytes, [System.Byte] 0) -ge 0) {
            $nul.Add($relative)
        }
    }
}

Describe -Name 'Shared: text file encoding' -Fixture {
    It -Name 'has no UTF-8 byte order mark in any text file' -Test {
        $bom | Should -BeNullOrEmpty -Because ('these files start with EF BB BF: {0}' -f ($bom -join ', '))
    }
    It -Name 'has no tab character in any text file' -Test {
        $tab | Should -BeNullOrEmpty -Because ('these files contain a tab; indent with spaces: {0}' -f ($tab -join ', '))
    }
    It -Name 'has no 0x00 byte in any text file' -Test {
        $nul | Should -BeNullOrEmpty -Because ('these files contain 0x00, usually UTF-16; save as UTF-8: {0}' -f ($nul -join ', '))
    }
}
