# Run once as the driver/channel owner. It registers only the display capability;
# it does not install, publish or change the driver running on a hub.
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (-not (Get-Command smartthings -ErrorAction SilentlyContinue)) {
        throw 'Install the SmartThings CLI first, then open a new PowerShell window.'
    }
    $registeredPath = Join-Path $PSScriptRoot 'capabilities\registered-compact-capability.json'
    if (-not (Test-Path -LiteralPath $registeredPath)) {
        & smartthings capabilities:create --input '.\capabilities\next-transition.json' --output $registeredPath --json
        if ($LASTEXITCODE -ne 0) { throw 'Capability registration failed. No driver has been installed or published.' }
    }
    $registered = Get-Content -LiteralPath $registeredPath -Raw | ConvertFrom-Json
    $capabilityId = [string]$registered.id
    if ($capabilityId -notmatch '^[a-zA-Z0-9]+\.[a-zA-Z][a-zA-Z0-9]*$') {
        throw 'The registration response did not contain a valid namespaced capability id. Keep the response file and inspect the CLI output.'
    }
    if ([int]$registered.version -ne 1) { throw 'This driver expects capability version 1.' }
    Write-Host "Compact display capability: $capabilityId"
    # Create and update are distinct API operations. Probe before choosing one,
    # including on reruns after an interrupted registration.
    $hasPresentation = $false
    try {
        & smartthings capabilities:presentation $capabilityId --capability-version 1 --json *> $null
        $hasPresentation = ($LASTEXITCODE -eq 0)
    }
    catch { $hasPresentation = $false }
    $presentationCommand = if ($hasPresentation) { 'capabilities:presentation:update' } else { 'capabilities:presentation:create' }
    & smartthings $presentationCommand $capabilityId --capability-version 1 --input '.\capabilities\next-transition-presentation.json'
    if ($LASTEXITCODE -ne 0) { throw 'Presentation registration failed. Fix the CLI error and run this script again; it will reuse the capability.' }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $configPath = Join-Path $PSScriptRoot 'driver\src\display_config.lua'
    $profilePath = Join-Path $PSScriptRoot 'driver\profiles\shabbos-mode-local.yaml'
    $configText = "-- Registered by Setup-Display.ps1; public capability ID, not a secret.`nreturn { capability_id = `"$capabilityId`" }`n"
    [System.IO.File]::WriteAllText($configPath, $configText, $utf8NoBom)
    $profileText = [System.IO.File]::ReadAllText($profilePath)
    $profileText = $profileText -replace '(?m)^(\s*- id: )(__NEXT_TRANSITION_CAPABILITY_ID__|[a-zA-Z0-9]+\.[a-zA-Z][a-zA-Z0-9]*)(\r?)$', "`${1}$capabilityId`${3}"
    if ($profileText.Contains('__NEXT_TRANSITION_CAPABILITY_ID__')) { throw 'The profile placeholder was not replaced.' }
    if (-not $profileText.Contains($capabilityId)) { throw 'The registered display capability is missing from the profile.' }
    [System.IO.File]::WriteAllText($profilePath, $profileText, $utf8NoBom)
    Write-Host 'Display registration complete. Nothing has been installed or published.'
    Write-Host 'Next: run Install-For-Testing.ps1 to update your own hub through your private channel.'
}
finally { Pop-Location }
