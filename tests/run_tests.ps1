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
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($configPath, $configLines, $utf8NoBom)

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

Run-Test 'commit when file changed' {
    $dir = Join-Path $algoBase 'boj\1016'
    $algoPosix = To-PosixPath $algoBase
    
    # 1. cpp 파일 생성
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1016 cpp --no-git --no-open"
    Assert-FileExists (Join-Path $dir 'boj_1016.cpp')
    
    # 2. Git 저장소 초기화 및 첫 커밋
    Invoke-Bash "cd '$algoPosix' && git init -q && git config user.email 'test@test.com' && git config user.name 'Test User' && git add . && git commit -q -m 'initial'"
    
    # 3. 파일 수정
    Add-Content -Path (Join-Path $dir 'boj_1016.cpp') -Value '// solution'
    
    # 4. al 실행 (git 활성화)
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1016 --no-open"
    
    # 5. 커밋 확인
    $lastCommit = & $script:bashExe -lc "cd '$algoPosix' && git log -1 --pretty=%B 2>/dev/null"
    if ($lastCommit -notlike '*solve*') {
        throw "expected commit with 'solve' prefix, got: $lastCommit"
    }
}

Run-Test 'explicit py creates py when cpp exists' {
    $dir = Join-Path $algoBase 'boj\1017'
    
    # 1. cpp 파일 먼저 생성
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1017 cpp --no-git --no-open"
    Assert-FileExists (Join-Path $dir 'boj_1017.cpp')
    Assert-FileNotExists (Join-Path $dir 'boj_1017.py')
    
    # 2. 명시적으로 py 지정하여 실행
    Invoke-Bash "export HOME='$homePosix'; source '$scriptPosix'; al b 1017 py --no-git --no-open"
    
    # 3. 이제 둘 다 존재해야 함
    Assert-FileExists (Join-Path $dir 'boj_1017.cpp')
    Assert-FileExists (Join-Path $dir 'boj_1017.py')
}

Write-Host ""
Write-Host "Tests: $passCount passed, $failCount failed"
if ($failCount -ne 0) {
    exit 1
}

Remove-Item -Recurse -Force $testRoot
