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
$texturesInstall = "D:\CyanPro-1.0.0-win32"
$out = Join-Path $root "release-out\$ver"
Step "파일 모으기 → $out"
if(Test-Path $out) {
	# 업로드 중이거나 열려 있는 파일이 있으면 아무것도 지우기 전에 멈춘다
	foreach($f in Get-ChildItem $out -File) {
		try { $f.Open("Open", "ReadWrite", "None").Dispose() }
		catch { throw "$($f.Name) 이(가) 다른 프로그램에서 사용 중. 업로드나 탐색기를 닫고 다시 실행할 것" }
	}
	Remove-Item $out -Recurse -Force
}
New-Item -ItemType Directory -Force $out | Out-Null

# 릴리스 노트: tools\release_notes\template.md + <버전>.md + 실제 커밋
$changesFile = Join-Path $PSScriptRoot "release_notes\$ver.md"
if(Test-Path $changesFile) {
	$changes = (Get-Content $changesFile -Raw -Encoding UTF8).Trim()
} else {
	Warn "tools\release_notes\$ver.md 가 없음 (변경 사항 칸이 비어서 나감)"
	$changes = "- (작성 안 됨)"
}
$notesText = (Get-Content (Join-Path $PSScriptRoot "release_notes\template.md") -Raw -Encoding UTF8).
	Replace("{VERSION}", $ver).Replace("{CODENAME}", $codename).Replace("{CHANGES}", $changes).
	Replace("{CYANPRO_COMMIT}", (git rev-parse --short=8 HEAD)).
	Replace("{CYANCORE_COMMIT}", (git -C ocgcore rev-parse --short=7 HEAD))
# 업로드 폴더에는 올릴 파일만 두고, 본문용 노트는 옆에 둔다
$notesFile = Join-Path $root "release-out\$ver-notes.md"
[IO.File]::WriteAllText($notesFile, $notesText, (New-Object Text.UTF8Encoding $false))

& (Join-Path $PSScriptRoot "make_update_zip.ps1") -TexturesSource $texturesInstall -Exe $exe -CoreDll $dll -OutDir $out
& (Join-Path $PSScriptRoot "make_full_zip.ps1") -Source $install -TexturesSource $texturesInstall -Exe $exe -CoreDll $dll -Notes $notesFile -Version $ver -OutDir $out
Copy-Item $exe $out -Force

Step "끝. GitHub 릴리스 v$ver 에 올릴 것"
Write-Host "  제목: v$ver `"$codename`""
Write-Host "  본문: release-out\$ver-notes.md 내용을 붙여넣기"
Write-Host "  파일: $out 안의 것 전부"
Get-ChildItem $out | ForEach-Object { Write-Host "  - $($_.Name)" }
Write-Host "`n  업데이트 zip 과 md5 가 빠지면 자동 업데이트가 뜨지 않는다."
if($warnings) { Write-Host "`n[주의] $warnings 건 — 위 노란 줄 확인" -ForegroundColor Yellow }
Invoke-Item $out
