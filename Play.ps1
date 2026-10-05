$ErrorActionPreference = 'Stop'
$enginePath = 'C:\Users\rv941\Tools\Godot\4.7.2\godot.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $engineCommand = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $engineCommand) { throw 'Install Godot 4.7.2 or open project.godot in Godot.' }
    $enginePath = $engineCommand.Source
}
& $enginePath --path $PSScriptRoot

