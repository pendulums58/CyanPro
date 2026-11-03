# Builds the full distribution zip CyanPro-<ver>-win32.zip.
# Content comes from an allowlist over a working install (-Source), plus the
# freshly built cyanpro.exe / ocgcore.dll. Anything not listed stays out:
# repositories, WindBot and expansions-2 (the client clones them on first launch;
# a WindBot folder without .git is deleted and recloned anyway),
# script, replay, screenshots, puzzles, decks, logs.
# config/configs.json and user_configs.json come from tools/release_files/config.
# config/system.conf is shipped with the personal fields reset to defaults,
# and RELEASE_NOTES.md is the generated -Notes file, not the install's copy.
param(
	[Parameter(Mandatory)][string]$Source,
	[Parameter(Mandatory)][string]$Exe,
	[Parameter(Mandatory)][string]$CoreDll,
	[Parameter(Mandatory)][string]$Notes,
	[Parameter(Mandatory)][string]$Version,
	[string]$OutDir = "."
)
$ErrorActionPreference = "Stop"
$Source = (Resolve-Path $Source).Path

$rootFiles = "COPYING.txt", "LICENSE.txt", "README.md.txt", "cacert.pem", "init.lua"
$trees = "config", "fonts", "notices", "skin", "sound", "textures"
# Repo lists come from tools/release_files/config, not the install, which may point at test repos
$fixedConfigs = "configs.json", "user_configs.json"
$skip = { param($rel) $rel -like "*.log" -or $rel -eq "config/system.conf" -or ($fixedConfigs | ForEach-Object { "config/$_" }) -contains $rel }
$emptyDirs = "deck/", "pics/cover/", "pics/field/", "pics/temp/"
# system.conf keys that hold the packager's own data, reset to game_config.inl defaults
$resetKeys = [ordered]@{
	nickname = "Player"; gamename = "Game"; lastdeck = ""; lasthost = "127.0.0.1"; lastport = "7911"
	lastBot = "0"; lastServer = ""; windowStruct = ""; showConsole = "0"
}

$entries = New-Object System.Collections.Generic.List[object]
function Add-File($full, $rel) { $entries.Add([pscustomobject]@{ Full = $full; Rel = $rel }) }
foreach($f in $rootFiles) {
	$p = Join-Path $Source $f
	if(!(Test-Path $p)) { throw "missing $p" }
	Add-File $p $f
}
foreach($t in $trees) {
	$base = Join-Path $Source $t
	if(!(Test-Path $base)) { throw "missing $base" }
	Get-ChildItem $base -Recurse -File -Force | ForEach-Object {
		$rel = $_.FullName.Substring($Source.Length + 1).Replace("\", "/")
		if($rel -match "/\.git/" -or (& $skip $rel)) { return }
		Add-File $_.FullName $rel
	}
}
foreach($f in $fixedConfigs) {
	Add-File (Resolve-Path (Join-Path $PSScriptRoot "release_files\config\$f")).Path "config/$f"
}
Add-File (Resolve-Path $Notes).Path "RELEASE_NOTES.md"
Add-File (Join-Path $Source "expansions\cards.cdb") "expansions/cards.cdb"
Add-File (Resolve-Path $Exe).Path "cyanpro.exe"
Add-File (Resolve-Path $CoreDll).Path "ocgcore.dll"

$conf = Get-Content (Join-Path $Source "config\system.conf") -Encoding UTF8
foreach($k in $resetKeys.Keys) {
	$i = [array]::FindIndex([string[]]$conf, [Predicate[string]]{ param($l) $l -match "^$k\s*=" })
	if($i -lt 0) { throw "system.conf has no $k" }
	$conf[$i] = "$k = $($resetKeys[$k])"
}

$name = "CyanPro-$Version-win32.zip"
$zip = Join-Path (Resolve-Path $OutDir) $name
if(Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, "Create")
try {
	foreach($e in $entries) {
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $e.Full, $e.Rel)
	}
	$w = New-Object IO.StreamWriter($archive.CreateEntry("config/system.conf").Open(), (New-Object Text.UTF8Encoding $false))
	$w.NewLine = "`n"
	$conf | ForEach-Object { $w.WriteLine($_) }
	$w.Dispose()
	foreach($d in $emptyDirs) { [void]$archive.CreateEntry($d) }
} finally {
	$archive.Dispose()
}
Write-Host "$name  $($entries.Count + 1) files, $([math]::Round((Get-Item $zip).Length / 1MB)) MB"
