# 릴리스 준비를 한 번에: 빌드 → 버전 확인 → 업데이트 zip/md5 → 올릴 파일 모으기
# release.bat 을 더블클릭하면 이 스크립트가 돈다. 푸시·태그·릴리스 발행은 하지 않는다.
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "[주의] $msg" -ForegroundColor Yellow; $script:warnings++ }
$warnings = 0

# 1. 버전
$config = Get-Content "gframe\config.h" -Raw
$parts = foreach($k in "MAJOR", "MINOR", "PATCH") {
	if($config -notmatch "#define EDOPRO_VERSION_$k (\d+)") { throw "config.h 에서 EDOPRO_VERSION_$k 를 못 찾음" }
	$Matches[1]
}
$ver = $parts -join "."
if($config -notmatch '#define EDOPRO_VERSION_CODENAME "([^"]*)"') { throw "config.h 에서 CODENAME 을 못 찾음" }
$codename = $Matches[1]
Step "버전 $ver `"$codename`""

# 2. 커밋 안 된 변경
$dirty = git status --porcelain --ignore-submodules=untracked | Where-Object { $_ -notmatch '^\?\?' }
if($dirty) { Warn "커밋 안 된 변경이 있음:`n$($dirty -join "`n")" }

# 3. CyanCore 배포 DLL 이 소스보다 오래됐는지
#    클라이언트는 CyanCore 저장소의 bin/ocgcore.dll 을 받아 쓰므로 소스만 바뀌면 반영이 안 된다
$dllCommit = git -C ocgcore log -1 --format=%H -- bin/ocgcore.dll
$srcCommit = git -C ocgcore log -1 --format=%H -- . ":(exclude)bin"
if(-not $dllCommit) {
	Warn "ocgcore 에 bin/ocgcore.dll 커밋이 없음"
} elseif($srcCommit -and $srcCommit -ne $dllCommit) {
	git -C ocgcore merge-base --is-ancestor $srcCommit $dllCommit
	if($LASTEXITCODE -ne 0) {
		Warn "코어 소스($($srcCommit.Substring(0,7)))가 배포 DLL($($dllCommit.Substring(0,7)))보다 새로움. DLL 을 다시 빌드해서 CyanCore 에 커밋할 것"
	}
}

# 4. 빌드
Step "빌드 (Release Win32)"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msbuild = & $vswhere -latest -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
if(-not $msbuild) { throw "MSBuild 를 못 찾음" }
& $msbuild "build\ygo.sln" /p:Configuration=Release /p:Platform=Win32 /p:WholeProgramOptimization=false /m /v:minimal /nologo
if($LASTEXITCODE -ne 0) { throw "빌드 실패" }

# 5. exe 버전이 config.h 와 같은지
$exe = Join-Path $root "bin\release\cyanpro.exe"
$exeVer = (Get-Item $exe).VersionInfo.FileVersion
if($exeVer -ne "$ver.0") { throw "cyanpro.exe 버전이 $exeVer, config.h 는 $ver" }

# 6. 올릴 파일 모으기
$dll = Join-Path $root "ocgcore\bin\release\shared\ocgcore.dll"
$install = Join-Path $root "..\CyanPro-Release"
$notes = Get-Content (Join-Path $install "RELEASE_NOTES.md") -Raw -Encoding UTF8
if($notes -notmatch [regex]::Escape($ver)) { Warn "CyanPro-Release\RELEASE_NOTES.md 에 $ver 이 없음 (예전 노트가 그대로 들어감)" }
$out = Join-Path $root "release-out\$ver"
Step "파일 모으기 → $out"
if(Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item $exe $out -Force
& (Join-Path $PSScriptRoot "make_update_zip.ps1") -Exe $exe -CoreDll $dll -OutDir $out
& (Join-Path $PSScriptRoot "make_full_zip.ps1") -Source $install -Exe $exe -CoreDll $dll -Version $ver -OutDir $out

Step "끝. GitHub 릴리스 v$ver 에 올릴 것"
Write-Host "  제목: v$ver `"$codename`""
Get-ChildItem $out | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host "`n  업데이트 zip 과 md5 가 빠지면 자동 업데이트가 뜨지 않는다."
if($warnings) { Write-Host "`n[주의] $warnings 건 — 위 노란 줄 확인" -ForegroundColor Yellow }
Invoke-Item $out
