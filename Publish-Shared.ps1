# Use after verifying the new display on your own hub.
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $config = Get-Content '.\driver\src\display_config.lua' -Raw
    if ($config.Contains('__NEXT_TRANSITION_CAPABILITY_ID__')) { throw 'Run Setup-Display.ps1 first.' }
    & smartthings edge:channels
    if ($LASTEXITCODE -ne 0) { throw 'Could not list channels.' }
    $channelId = (Read-Host 'Paste ONLY the ID of the PUBLIC Shabbos Mode Local channel').Trim()
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($channelId, [ref]$parsedId)) { throw 'That is not a channel UUID. Paste only the ID from the list above.' }
    & smartthings edge:drivers:package '.\driver' --channel $channelId
    if ($LASTEXITCODE -ne 0) { throw 'Public channel publish failed. Inspect the CLI error above.' }
    Write-Host 'Published to the selected channel. The existing invitation URL stays the same.'
}
finally { Pop-Location }
