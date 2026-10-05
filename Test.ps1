param([switch]$Visual)
$ErrorActionPreference = 'Stop'
$enginePath = 'C:\Users\rv941\Tools\Godot\4.7.2\godot_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $engineCommand = Get-Command godot -ErrorAction Stop
    $enginePath = $engineCommand.Source
}
if ($Visual) {
    & $enginePath --path $PSScriptRoot --resolution 390x844 --audio-driver Dummy --max-fps 60 --scene tests/visual_runner.tscn -- --test
} else {
    & $enginePath --headless --path $PSScriptRoot --scene tests/runner.tscn --fixed-fps 60 -- --test
}
exit $LASTEXITCODE

