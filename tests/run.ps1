# Offline checks on Windows. Needs a Lua 5.1+ interpreter named `lua` on PATH, or set $env:LUA.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$lua = if ($env:LUA) { $env:LUA } else { 'lua' }
if (-not (Get-Command $lua -ErrorAction SilentlyContinue)) {
    Write-Host "No Lua interpreter found. Install one (winget install DEVCOM.Lua) or set `$env:LUA." -ForegroundColor Yellow
    exit 1
}
$media = 'Contents/mods/ProjectGolf/common/media'
$files = Get-ChildItem -Recurse -Path Contents -Filter *.lua | ForEach-Object { $_.FullName }
& $lua tests/syntax.lua @files
& $lua tests/physics_test.lua "$media/lua/shared"
& $lua tests/smoke.lua $media
& $lua tests/vp.lua $media
& $lua tests/vp16.lua $media
& $lua tests/maptees.lua $media
