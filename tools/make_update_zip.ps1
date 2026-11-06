# Builds the client self-update assets for a GitHub release:
#   CyanPro-<ver>-update.zip  (cyanpro.exe, and ocgcore.dll if -CoreDll is given, at the zip root,
#                              plus config/configs.json from tools/release_files/config
#                              the textures in $textures from -TexturesSource,
#                              and the empty expansions/cards.cdb from tools/release_files/expansions)
#   CyanPro-<ver>-update.md5  ("<md5>  <zip name>")
# Upload both to the release next to the full CyanPro-<ver>-win32.zip.
# The updater extracts the zip over the install folder, so it must only
# contain files that are safe to overwrite on every user's machine.
param(
	[Parameter(Mandatory)][string]$TexturesSource,
	[string]$Exe = (Join-Path $PSScriptRoot "..\bin\release\cyanpro.exe"),
	[string]$CoreDll = "",
	[string]$OutDir = "."
)
$ErrorActionPreference = "Stop"

# The 1.0.4-1.0.7 full zips shipped old copies of these textures and a full card DB.
# Both overwrite players' own files on every update, so take them out once 1.0.8 is out.
$textures = "AppIcon.png", "CREDITS.md.txt", "bg.jpg", "bg_deck.jpg", "bg_menu.jpg", "cover.jpg", "cover2.jpg", "negated.png", "unknown.jpg"

$config = Get-Content (Join-Path $PSScriptRoot "..\gframe\config.h") -Raw
$parts = foreach($k in "MAJOR", "MINOR", "PATCH") {
	if($config -notmatch "#define EDOPRO_VERSION_$k (\d+)") { throw "EDOPRO_VERSION_$k not found in config.h" }
	$Matches[1]
}
$ver = $parts -join "."

# Refuse to package an exe that was not built from this config.h
$exeVer = (Get-Item $Exe).VersionInfo.FileVersion
if($exeVer -ne "$ver.0") { throw "$Exe is version $exeVer, config.h says $ver" }

$name = "CyanPro-$ver-update.zip"
$zip = Join-Path (Resolve-Path $OutDir) $name
if(Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, "Create")
try {
	[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Resolve-Path $Exe), "cyanpro.exe")
	# The updater moves the old ocgcore.dll aside and restores it if the zip has none
	if($CoreDll) {
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Resolve-Path $CoreDll), "ocgcore.dll")
	}
	# The shipped repo list; players' own repos live in user_configs.json, which is never overwritten
	[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Resolve-Path (Join-Path $PSScriptRoot "release_files\config\configs.json")), "config/configs.json")
	foreach($t in $textures) {
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Resolve-Path (Join-Path $TexturesSource "textures\$t")), "textures/$t")
	}
	[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Resolve-Path (Join-Path $PSScriptRoot "release_files\expansions\cards.cdb")), "expansions/cards.cdb")
} finally {
	$archive.Dispose()
}

$md5 = (Get-FileHash $zip -Algorithm MD5).Hash.ToLower()
$md5File = Join-Path (Resolve-Path $OutDir) "CyanPro-$ver-update.md5"
[System.IO.File]::WriteAllText($md5File, "$md5  $name`n")
Write-Host "$name  $md5"
