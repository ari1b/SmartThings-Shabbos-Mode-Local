$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $config = Get-Content '.\driver\src\display_config.lua' -Raw
    if ($config.Contains('__NEXT_TRANSITION_CAPABILITY_ID__')) { throw 'Run Setup-Display.ps1 first.' }
    & smartthings edge:channels
    if ($LASTEXITCODE -ne 0) { throw 'Could not list channels.' }
    $channelId = (Read-Host 'Paste ONLY the ID of your PRIVATE test channel, not the public channel').Trim()
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($channelId, [ref]$parsedId)) { throw 'That is not a channel UUID. Paste only the ID from the list above.' }
    & smartthings edge:drivers:package '.\driver' --channel $channelId --install
    if ($LASTEXITCODE -ne 0) { throw 'Driver install failed. Inspect the CLI error above.' }
    Write-Host 'Keep the existing switch. Open it and refresh; allow time for the new profile and app display to load.'
}
finally { Pop-Location }
