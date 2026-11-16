# Repairs the first v1.1 download in place. Does not contact SmartThings or change
# your registered capability ID, scheduling engine, or saved hub preferences.
param([string]$ProjectRoot = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$profilePath = Join-Path $ProjectRoot 'driver\profiles\shabbos-mode-local.yaml'
$displayPath = Join-Path $ProjectRoot 'driver\src\next_display.lua'
if (-not (Test-Path -LiteralPath $profilePath) -or -not (Test-Path -LiteralPath $displayPath)) {
    throw 'Run this script from the existing shabbos-next-display project, or supply its path with -ProjectRoot.'
}
$zones = @('America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles',
    'America/Phoenix', 'America/Anchorage', 'Pacific/Honolulu', 'Europe/London',
    'Europe/Paris', 'Asia/Jerusalem', 'Australia/Sydney')
$profile = [System.IO.File]::ReadAllText($profilePath)
foreach ($zone in $zones) { $profile = $profile.Replace($zone, $zone.Replace('/', '_')) }
$profile = $profile.Replace('automatic DST', 'auto DST')
# Validate enumeration keys/labels against the constraints returned by SmartThings.
foreach ($match in [regex]::Matches($profile, '(?m)^\s{6}([\w/]+):\s+([^\r\n]+)\r?$')) {
    if ($match.Groups[1].Value -notmatch '^\w+$') { throw 'A preference option key still contains invalid characters.' }
    if ($match.Groups[2].Value.Trim().Length -gt 36) { throw 'A preference option label still exceeds 36 characters.' }
}
$display = [System.IO.File]::ReadAllText($displayPath)
$marker = '-- Map API-safe preference keys'
if (-not $display.Contains($marker)) {
    $old = '  local zone = assert(data.zones[name], "Unsupported display timezone: " .. tostring(name))'
    $new = @'
  -- Map API-safe preference keys (America_New_York) to IANA zone names.
  local zone = data.zones[name]
  if not zone then
    for zone_name, rows in pairs(data.zones) do
      if zone_name:gsub("/", "_") == name then zone = rows; break end
    end
  end
  assert(zone, "Unsupported display timezone: " .. tostring(name))
'@
    if (-not $display.Contains($old)) { throw 'The expected original display code was not found. No files have been changed.' }
    $display = $display.Replace($old, $new)
}
# Keep backups outside driver/ so they cannot be mistaken for profile/source files.
$backupDirectory = Join-Path $ProjectRoot '.enum-fix-backup'
if (-not (Test-Path -LiteralPath $backupDirectory)) {
    New-Item -ItemType Directory -Path $backupDirectory | Out-Null
}
foreach ($path in @($profilePath, $displayPath)) {
    $backup = Join-Path $backupDirectory ([System.IO.Path]::GetFileName($path))
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $path -Destination $backup }
}
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($profilePath, $profile, $encoding)
[System.IO.File]::WriteAllText($displayPath, $display, $encoding)
Write-Host 'Fixed the timezone option keys/labels and display lookup.'
Write-Host 'Your registered capability ID is preserved. Do not rerun Setup-Display.ps1.'
Write-Host 'Now rerun Install-For-Testing.ps1.'
