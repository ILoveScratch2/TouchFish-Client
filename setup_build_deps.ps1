# setup_build_deps.ps1
# Prepares cached native dependencies for the Windows build to avoid slow
# GitHub downloads during CMake configure:
#   - copies ANGLE.7z and mpv-dev-*.7z into build/windows/x64/
#   - pre-extracts them into build/windows/x64/ANGLE and build/windows/x64/libmpv
#     so that media_kit's CMake "check_directory_exists_and_not_empty" skips
#     both the download AND the extraction step (which would otherwise fail
#     because libarchive cannot decode LZMA-compressed 7z files).
#
# Run this BEFORE `flutter run -v --debug` (after `flutter clean`).

param(
  [string]$DesktopPath = "$env:USERPROFILE\Desktop"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildDir = Join-Path $root 'build\windows\x64'
$sevenZip = 'C:\Program Files (x86)\7-Zip\7z.exe'
if (-not (Test-Path $sevenZip)) { $sevenZip = 'C:\Program Files\7-Zip\7z.exe' }
if (-not (Test-Path $sevenZip)) { throw "7-Zip not found. Install it via: winget install 7zip.7zip" }


# ---------------------------------------------------------------------------
# 0. Patch super_native_extensions resolve_symlinks.ps1 so Get-Item works with
#    the hidden C:\Users\<user>\AppData directory (PowerShell quirk). Without
#    this, CMake configure logs a noisy non-fatal error for every build.
# ---------------------------------------------------------------------------
$symlinkScript = Join-Path $env:LOCALAPPDATA 'Pub\Cache\hosted\pub.dev\super_native_extensions-0.8.24\cargokit\cmake\resolve_symlinks.ps1'
if (Test-Path $symlinkScript) {
  $scriptContent = Get-Content $symlinkScript -Raw
  if ($scriptContent -match 'Get-Item \$realPath\b' -and $scriptContent -notmatch 'Get-Item \$realPath\s+-Force') {
    Write-Host "[setup] Patching resolve_symlinks.ps1 (add -Force for hidden AppData)..."
    $scriptContent = $scriptContent.Replace('Get-Item $realPath', 'Get-Item $realPath -Force')
    Set-Content -Path $symlinkScript -Value $scriptContent -NoNewline
  } else {
    Write-Host "[setup] resolve_symlinks.ps1 already patched - skipping"
  }
} else {
  Write-Host "[setup] WARN: resolve_symlinks.ps1 not found, skipping patch"
}

$angleArc = Join-Path $DesktopPath 'ANGLE.7z'
$mpvArc   = Join-Path $DesktopPath 'mpv-dev-x86_64-20230924-git-652a1dd.7z'

foreach ($f in @($angleArc, $mpvArc)) {
  if (-not (Test-Path $f)) { throw "Missing cached archive: $f" }
}

Write-Host "[setup] Ensuring build dir: $buildDir"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

# 1. Copy archives so media_kit's download_and_verify() skips the download
#    (MD5 matches the expected values).
Write-Host "[setup] Copying cached archives..."
Copy-Item -Force $angleArc (Join-Path $buildDir 'ANGLE.7z')
Copy-Item -Force $mpvArc   (Join-Path $buildDir 'mpv-dev-x86_64-20230924-git-652a1dd.7z')

# 2. ANGLE - extract to build/windows/x64/ANGLE
$angleDir = Join-Path $buildDir 'ANGLE'
if (-not (Get-ChildItem $angleDir -ErrorAction SilentlyContinue)) {
  Write-Host "[setup] Extracting ANGLE.7z -> $angleDir"
  New-Item -ItemType Directory -Force -Path $angleDir | Out-Null
  & $sevenZip x -y $angleArc "-o$angleDir" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'ANGLE extraction failed' }
} else {
  Write-Host "[setup] ANGLE already extracted - skipping"
}

# 3. mpv - extract to build/windows/x64/libmpv and re-organize include/mpv -> include
#    (mirrors the custom_command in media_kit_libs_windows_video CMakeLists.txt)
$mpvDir = Join-Path $buildDir 'libmpv'
if (-not (Get-ChildItem $mpvDir -ErrorAction SilentlyContinue)) {
  Write-Host "[setup] Extracting mpv archive -> $mpvDir"
  New-Item -ItemType Directory -Force -Path $mpvDir | Out-Null
  & $sevenZip x -y $mpvArc "-o$mpvDir" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'mpv extraction failed' }

  # Re-organize headers: include/mpv -> include
  $incMpv = Join-Path $mpvDir 'include\mpv'
  $incTmp = Join-Path $mpvDir 'mpv'
  if (Test-Path $incMpv) {
    Move-Item $incMpv $incTmp
    Remove-Item (Join-Path $mpvDir 'include') -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item $incTmp (Join-Path $mpvDir 'include')
  }
} else {
  Write-Host "[setup] libmpv already extracted - skipping"
}

# 4. Verify required files exist.
Write-Host "[setup] Verifying..."
$required = @(
  (Join-Path $angleDir 'libEGL.dll'),
  (Join-Path $angleDir 'libGLESv2.dll'),
  (Join-Path $angleDir 'd3dcompiler_47.dll'),
  (Join-Path $angleDir 'vk_swiftshader.dll'),
  (Join-Path $angleDir 'vulkan-1.dll'),
  (Join-Path $angleDir 'zlib.dll'),
  (Join-Path $mpvDir 'libmpv-2.dll'),
  (Join-Path $mpvDir 'include\client.h')
)
foreach ($r in $required) {
  if (-not (Test-Path $r)) { throw "Missing required file: $r" }
}
Write-Host "[setup] DONE - build deps are ready."
