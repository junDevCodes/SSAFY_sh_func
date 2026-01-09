Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $RootDir 'algo_functions.sh'

function Get-BashPath {
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    $gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    if (Test-Path $gitBash) {
        return $gitBash
    }
    throw 'bash not found. Install Git for Windows or add bash to PATH.'
}

function To-PosixPath([string]$path) {
    $p = $path -replace '\\','/'
    if ($p -match '^([A-Za-z]):') {
        $drive = $Matches[1].ToLower()
        $p = $p -replace '^[A-Za-z]:', "/$drive"
    }
    return $p
}

function Invoke-Bash([string]$command) {
    & $script:bashExe -lc $command
    if ($LASTEXITCODE -ne 0) {
        throw "bash command failed: $command"
    }
}

function Assert-FileExists([string]$path) {
    if (-not (Test-Path $path)) {
        throw "expected file not found: $path"
    }
}

function Assert-FileNotExists([string]$path) {
    if (Test-Path $path) {
        throw "unexpected file exists: $path"
    }
}

function Run-Test([string]$name, [scriptblock]$block) {
    try {
        & $block
        Write-Host "PASS: $name"
        $script:passCount++
    } catch {
        Write-Host "FAIL: $name"
        Write-Host "  $_"
        $script:failCount++
    }
}

$script:bashExe = Get-BashPath

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("algo_func_test_" + [Guid]::NewGuid().ToString('N'))
$homeDir = Join-Path $testRoot 'home'
New-Item -ItemType Directory -Path $homeDir | Out-Null

$configPath = Join-Path $homeDir '.algo_config'
$configLines = @(
    'ALGO_BASE_DIR="$HOME/algos"',
    'GIT_DEFAULT_BRANCH="main"',
    'GIT_COMMIT_PREFIX="solve"',
    'GIT_AUTO_PUSH=false',
    'IDE_PRIORITY="code"',
    'SSAFY_BASE_URL="https://lab.ssafy.com"',
    'SSAFY_USER_ID="testuser"'
)
Set-Content -Encoding UTF8 -Path $configPath -Value $configLines

$algoBase = Join-Path $homeDir 'algos'
New-Item -ItemType Directory -Path $algoBase | Out-Null

$homePosix = To-PosixPath $homeDir
$scriptPosix = To-PosixPath $ScriptPath

$script:passCount = 0
$script:failCount = 0

Run-Test 'cpp only creates cpp' {
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1012 cpp --no-git --no-open"
    $dir = Join-Path $algoBase 'boj\1012'
    Assert-FileExists (Join-Path $dir 'boj_1012.cpp')
    Assert-FileNotExists (Join-Path $dir 'boj_1012.py')
    Assert-FileExists (Join-Path $dir 'sample_input.txt')
}

Run-Test 'py default creates py' {
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1013 --no-git --no-open"
    $dir = Join-Path $algoBase 'boj\1013'
    Assert-FileExists (Join-Path $dir 'boj_1013.py')
    Assert-FileNotExists (Join-Path $dir 'boj_1013.cpp')
    Assert-FileExists (Join-Path $dir 'sample_input.txt')
}

Run-Test 'cpp exists without lang keeps cpp only' {
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1014 cpp --no-git --no-open"
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1014 --no-git --no-open"
    $dir = Join-Path $algoBase 'boj\1014'
    Assert-FileExists (Join-Path $dir 'boj_1014.cpp')
    Assert-FileNotExists (Join-Path $dir 'boj_1014.py')
}

Run-Test 'cpp with msg flag creates cpp' {
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1015 cpp --msg 'feat: test' --no-git --no-open"
    $dir = Join-Path $algoBase 'boj\1015'
    Assert-FileExists (Join-Path $dir 'boj_1015.cpp')
    Assert-FileNotExists (Join-Path $dir 'boj_1015.py')
}

Write-Host ""
Write-Host "Tests: $passCount passed, $failCount failed"
if ($failCount -ne 0) {
    exit 1
}

Remove-Item -Recurse -Force $testRoot
