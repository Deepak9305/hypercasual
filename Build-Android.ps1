$ErrorActionPreference = 'Stop'
$enginePath = 'C:\Users\rv941\Tools\Godot\4.7.2\godot_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $engineCommand = Get-Command godot -ErrorAction Stop
    $enginePath = $engineCommand.Source
}
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'build') | Out-Null
& $enginePath --headless --path $PSScriptRoot --export-debug Android (Join-Path $PSScriptRoot 'build\FreezeFrame-debug.apk')
exit $LASTEXITCODE

