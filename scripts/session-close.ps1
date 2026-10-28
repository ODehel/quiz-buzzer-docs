<#
.SYNOPSIS
    Closes a Buzz'O'Live session: generates the handoff file from the real state of the worked repository.
.DESCRIPTION
    Run it from anywhere. It reads the worked repository (read-only) and writes ONE new file in
    docs/sessions/ of quiz-buzzer-docs, built from docs/sessions/TEMPLATE.md:
      - title, start HEAD (HEAD~1: one commit per session) and arrival HEAD (HEAD);
      - the checks of session-open.ps1, run on the worked repository (report embedded);
      - the diff of DEBTS.md over the session commit.
    Lessons, next target and the CA x layers matrix stay as template placeholders: they are written
    by hand after reading the specs. The script never commits.
.PARAMETER Title
    Title of the session commit. It must equal the subject of HEAD in the worked repository.
.PARAMETER Repo
    Folder name of the worked repository, next to quiz-buzzer-docs (e.g. quiz-live-server).
.NOTES
    Exit codes: 0 ok | 20 not a git repository | 21 HEAD subject differs from -Title
                | 22 handoff already exists | 23 template changed (expected field not found)
                | 24 handoff written but the checks are not green
#>
param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Repo
)

$ErrorActionPreference = 'Continue'

# git and the checks write UTF-8: decode it as such instead of the OEM code page (mojibake, false title mismatch).
$previousEncoding = $null
try { $previousEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
function Exit-Script([int]$code) {
    if ($previousEncoding) { try { [Console]::OutputEncoding = $previousEncoding } catch { } }
    exit $code
}
$docsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoPath = Join-Path (Split-Path $docsRoot -Parent) $Repo
$sessionOpen = Join-Path $PSScriptRoot 'session-open.ps1'
$templatePath = Join-Path $docsRoot 'docs/sessions/TEMPLATE.md'

if (-not (Test-Path (Join-Path $repoPath '.git'))) { Write-Output "Not a git repository: $repoPath"; Exit-Script 20 }

$subject = (git -C $repoPath log -1 --format=%s)
if ($subject -ne $Title) {
    Write-Output 'HEAD subject differs from -Title.'
    Write-Output "  HEAD:  $subject"
    Write-Output "  Title: $Title"
    Exit-Script 21
}
$startHead = (git -C $repoPath rev-parse --short HEAD~1 2>$null)
if (-not $startHead) { $startHead = '(no parent commit)' }
$endHead = (git -C $repoPath rev-parse --short HEAD)

$target = Join-Path $docsRoot ("docs/sessions/{0}-{1}.md" -f (Get-Date -Format 'yyyy-MM-dd-HHmm'), $Repo)
if (Test-Path $target) { Write-Output "Handoff already exists: $target"; Exit-Script 22 }

# Checks: session-open.ps1 on the worked repository (read-only).
Push-Location $repoPath
$report = (& $sessionOpen *>&1 | Out-String)
$checksExit = $LASTEXITCODE
Pop-Location
$checks = $report
if ($report -match '(?s)(## Checks.*?)(?=\r?\n## Debts and decisions)') { $checks = $Matches[1].TrimEnd() }
$checks = $checks -replace '(?m)^## Checks', '### Rapport de session-open'
$checks = $checks + "`r`n`r`nCode de sortie de session-open : $checksExit"

$debtsDiff = (git -C $repoPath diff HEAD~1 HEAD -- DEBTS.md 2>$null | Out-String).TrimEnd()
if (-not $debtsDiff) { $debtsDiff = 'aucun changement' }

$e = [char]0xE9
$a = [char]0xE0
$bt = [char]96
$todo = "$a renseigner"
$text = [System.IO.File]::ReadAllText($templatePath)

function Update-Field([string]$pattern, [string]$replacement) {
    if ($script:text -notmatch $pattern) { Write-Output "Template changed, field not found: $pattern"; Exit-Script 23 }
    $script:text = [regex]::Replace($script:text, $pattern, $replacement.Replace('$', '$$'))
}
function Add-Before([string]$pattern, [string]$insertion) {
    $m = [regex]::Match($script:text, $pattern)
    if (-not $m.Success) { Write-Output "Template changed, field not found: $pattern"; Exit-Script 23 }
    $script:text = $script:text.Insert($m.Index, $insertion)
}
function Get-Cell([string]$marker) {
    if ($report -notmatch [regex]::Escape($marker)) { return 'sans objet' }
    if ($checksExit -eq 0) { return 'OK' }
    return "voir rapport (exit $checksExit)"
}

Update-Field '(?m)^# Handoff : <[^>]*>' "# Handoff : $Title"
Update-Field '(?m)^- \*\*Titre\*\*[^\r\n]*' ("- **Titre** (= titre du commit) : " + $bt + $Title + $bt)
Update-Field '(?m)^- \*\*HEAD de d\S+\*\*[^\r\n]*' ("- **HEAD de d${e}part** : " + $bt + $startHead + $bt)
Update-Field '(?m)^- \*\*HEAD d.arriv\S*\*\*[^\r\n]*' ("- **HEAD d'arriv${e}e** : " + $bt + $endHead + $bt)
Update-Field '(?m)^\| Tests \|[^\r\n]*' ("| Tests | " + (Get-Cell '### Tests') + " |")
Update-Field '(?m)^\| Type-check \|[^\r\n]*' ("| Type-check | " + (Get-Cell '### Type-check') + " |")
Update-Field '(?m)^\| Lint \|[^\r\n]*' "| Lint | $todo |"
Update-Field '(?m)^\| Mutations \|[^\r\n]*' "| Mutations | $todo |"
Add-Before '(?m)^## Diff de ' ($checks + "`r`n`r`n")
Update-Field '<diff[^>]*>' $debtsDiff

[System.IO.File]::WriteAllText($target, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Handoff written: $target"
Write-Output "Checks exit code: $checksExit"
Write-Output 'To complete by hand: lessons, next target, CA x layers matrix (and Lint / Mutations).'
if ($checksExit -ne 0) { Exit-Script 24 }
Exit-Script 0
