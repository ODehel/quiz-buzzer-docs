<#
.SYNOPSIS
    Read-only opening check for a Buzz'O'Live session. Run it from the root of any of the 4 repos.
.DESCRIPTION
    Prints a markdown report on stdout: git state, type-check/tests/build (by repo type),
    DEBTS.md and DECISIONS.md counts, and the comparison with the latest handoff.
    Modifies nothing in the repository.
    Type-check of a node repository:
      - with angular.json (Angular): ngc -p tsconfig.app.json --noEmit, then ngc -p tsconfig.spec.json --noEmit
        (templates are checked; the root tsconfig.json is a "solution" file that tsc cannot use);
      - otherwise: tsc --noEmit, plus a guard that is RED ("covers 0 project files") when
        tsc --noEmit --listFilesOnly lists no file outside node_modules.
.PARAMETER ExpectedBranch
    Branch the session must open on. Default: main.
.PARAMETER FirmwareEnv
    PlatformIO environment built on a firmware repository (pio run -e <FirmwareEnv>). Default: esp32.
.NOTES
    Exit codes (first failure wins, in this order):
      0 ok | 10 dirty tree | 11 unexpected branch | 12 type-check | 13 tests | 14 build | 15 tool missing
    A handoff gap is reported but does not change the exit code.
#>
param(
    [string]$ExpectedBranch = 'main',
    [string]$FirmwareEnv = 'esp32'
)

$ErrorActionPreference = 'Continue'
$script:ExitCode = 0
$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { Write-Output 'Not inside a git repository.'; exit 1 }
$repoRoot = (Resolve-Path $repoRoot).Path
Set-Location $repoRoot

function Set-Failure([int]$code) {
    if ($script:ExitCode -eq 0) { $script:ExitCode = $code }
}

function Write-Block([string]$text) {
    Write-Output '```'
    if ($text) { Write-Output $text.TrimEnd() }
    Write-Output '```'
}

# Runs a native command, prints the tail of its output, returns its exit code.
# A missing executable is never run: it is reported RED and recorded as failure 15.
function Invoke-Step([string]$title, [string]$exe, [string[]]$arguments) {
    Write-Output "### $title"
    Write-Output ('`' + $exe + ' ' + ($arguments -join ' ') + '`')
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        Write-Output "Result: **RED** (tool not found: $exe)"
        Write-Output ''
        Set-Failure 15
        $script:StepCode = 15
        return
    }
    $output = (& $exe @arguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
    $tail = ($output -split "`r?`n" | Where-Object { $_ -ne '' -and $_ -notmatch '^\{"level"' } | Select-Object -Last 15) -join "`n"
    Write-Block $tail
    if ($code -eq 0) { Write-Output 'Result: OK' } else { Write-Output "Result: **RED** (exit $code)" }
    Write-Output ''
    $script:StepCode = $code
}

$repoName = Split-Path $repoRoot -Leaf
$branch = (git branch --show-current)
$head = (git rev-parse --short HEAD)
$porcelain = (git status --porcelain | Out-String)
$isDirty = [bool]$porcelain.Trim()

if (Test-Path 'platformio.ini') { $kind = 'firmware' }
elseif ((Test-Path 'package.json') -and (Test-Path 'tsconfig.json')) { $kind = 'node' }
else { $kind = 'docs' }

Write-Output "# Session open: $repoName"
Write-Output ''
Write-Output "- Repository type: **$kind**"
Write-Output "- Branch: ``$branch`` (expected ``$ExpectedBranch``)"
Write-Output "- HEAD: ``$head``"
Write-Output ''

Write-Output '## Git'
Write-Output '### git status --short'
Write-Block $porcelain
if ($isDirty) { Write-Output 'Tree: **DIRTY**'; Set-Failure 10 } else { Write-Output 'Tree: clean' }
if ($branch -ne $ExpectedBranch) { Write-Output "Branch: **UNEXPECTED** (``$branch`` instead of ``$ExpectedBranch``)"; Set-Failure 11 }
else { Write-Output 'Branch: as expected' }
Write-Output ''
Write-Output '### git log -5'
Write-Block ((git log -5 --format='%h %s (%ar)') | Out-String)

Write-Output '## Checks'
if ($kind -eq 'node') {
    if (Test-Path 'angular.json') {
        Invoke-Step 'Type-check (app, templates included)' 'npx.cmd' @('ngc', '-p', 'tsconfig.app.json', '--noEmit')
        if ($script:StepCode -ne 0) { Set-Failure 12 }
        Invoke-Step 'Type-check (spec, templates included)' 'npx.cmd' @('ngc', '-p', 'tsconfig.spec.json', '--noEmit')
        if ($script:StepCode -ne 0) { Set-Failure 12 }
    }
    else {
        Invoke-Step 'Type-check' 'npx.cmd' @('tsc', '--noEmit')
        if ($script:StepCode -ne 0) { Set-Failure 12 }
        # A "solution" tsconfig makes tsc green while it checks nothing: require real project files.
        if (Get-Command 'npx.cmd' -ErrorAction SilentlyContinue) {
            Write-Output '### Type-check coverage'
            Write-Output '`npx.cmd tsc --noEmit --listFilesOnly`'
            $covered = @(& npx.cmd tsc --noEmit --listFilesOnly 2>$null |
                Where-Object { $_ -match '\.(ts|tsx|mts|cts)$' -and $_ -notmatch 'node_modules' })
            if ($covered.Count -eq 0) {
                Write-Output 'Result: **RED** (covers 0 project files)'
                Set-Failure 12
            } else { Write-Output "Result: OK ($($covered.Count) project files)" }
            Write-Output ''
        }
    }
    Invoke-Step 'Tests' 'npm.cmd' @('test')
    if ($script:StepCode -ne 0) { Set-Failure 13 }
}
elseif ($kind -eq 'firmware') {
    Invoke-Step 'Tests (native)' 'pio' @('test', '-e', 'native')
    if ($script:StepCode -ne 0) { Set-Failure 13 }
    Invoke-Step "Build ($FirmwareEnv)" 'pio' @('run', '-e', $FirmwareEnv)
    if ($script:StepCode -ne 0) { Set-Failure 14 }
}
else {
    Write-Output 'No code to check (docs repository).'
    Write-Output ''
}

Write-Output '## Debts and decisions'
if (Test-Path 'DEBTS.md') {
    $debts = @(Select-String -Path 'DEBTS.md' -Pattern '^- \*\*' -Encoding UTF8).Count
    Write-Output "- DEBTS.md: $debts entries"
} else { Write-Output '- DEBTS.md: absent' }
$decisionsFile = 'docs/decisions/DECISIONS.md'
if (Test-Path $decisionsFile) {
    $decisions = @(Select-String -Path $decisionsFile -Pattern '^## #\d+' -Encoding UTF8).Count
    Write-Output "- DECISIONS.md: $decisions entries"
} else { Write-Output '- DECISIONS.md: absent' }
Write-Output ''

Write-Output '## Handoff'
$sessionsDir = Join-Path (Split-Path $repoRoot -Parent) 'quiz-buzzer-docs/docs/sessions'
$handoff = $null
if (Test-Path $sessionsDir) {
    $handoff = Get-ChildItem $sessionsDir -Filter '*.md' |
        Where-Object { $_.Name -ne 'TEMPLATE.md' } |
        Sort-Object Name | Select-Object -Last 1
}
if (-not $handoff) {
    Write-Output 'No handoff: first opening.'
}
else {
    Write-Output "- Latest handoff: ``$($handoff.Name)``"
    $text = Get-Content $handoff.FullName -Raw -Encoding UTF8
    if ($text -match "HEAD d.arriv\S*\s*\*\*\s*:\s*``?([0-9a-f]{7,40})``?") {
        $expected = $Matches[1]
        git cat-file -e "$expected^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Output "- Recorded arrival HEAD ``$expected`` is unknown in this repository: no comparison."
        }
        elseif ((git rev-parse HEAD).StartsWith($expected) -or (git rev-parse $expected) -eq (git rev-parse HEAD)) {
            Write-Output "- Arrival HEAD ``$expected`` = real HEAD: no gap."
        }
        else {
            $ahead = (git rev-list --count "$expected..HEAD")
            $behind = (git rev-list --count "HEAD..$expected")
            Write-Output "- **GAP**: handoff says ``$expected``, real HEAD is ``$head`` ($ahead commit(s) ahead, $behind behind). The real state wins."
        }
    }
    else {
        Write-Output "- No readable arrival HEAD in the handoff: no comparison."
    }
}

exit $script:ExitCode
