# Builds the client self-update assets for a GitHub release:
#   CyanPro-<ver>-update.zip  (cyanpro.exe at the zip root)
#   CyanPro-<ver>-update.md5  ("<md5>  <zip name>")
# Upload both to the release next to the full CyanPro-<ver>-win32.zip.
# The updater extracts the zip over the install folder, so it must only
# contain files that are safe to overwrite on every user's machine.
param(
	[string]$Exe = (Join-Path $PSScriptRoot "..\bin\release\cyanpro.exe"),
	[string]$OutDir = "."
)
$ErrorActionPreference = "Stop"

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
} finally {
	$archive.Dispose()
}

$md5 = (Get-FileHash $zip -Algorithm MD5).Hash.ToLower()
$md5File = Join-Path (Resolve-Path $OutDir) "CyanPro-$ver-update.md5"
[System.IO.File]::WriteAllText($md5File, "$md5  $name`n")
Write-Host "$name  $md5"
