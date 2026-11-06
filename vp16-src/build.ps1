# Builds ProjectGolfVP16.jar (the Viewpoint 0.1.6 bridge) into the ProjectGolf mod. Needs a JDK 17+.
#   .\build.ps1 "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3809306528\mods\Viewpoint\42\media\java\client\Viewpoint.jar"
# The stubs (ZombieBuddy annotations, LWJGL GL classes) are compile-only: the jar holds projectgolf/vp16 only.
param([Parameter(Mandatory = $true)][string]$ViewpointJar)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force build/stubs, build/classes | Out-Null
javac --release 17 -nowarn -d build/stubs (Get-ChildItem -Recurse stubs -Filter *.java).FullName
javac --release 17 -Xlint:all -encoding UTF-8 -cp "build/stubs;$ViewpointJar" -d build/classes (Get-ChildItem src/projectgolf/vp16 -Filter *.java).FullName
$out = "..\Contents\mods\ProjectGolf\42\media\java\client"
New-Item -ItemType Directory -Force $out | Out-Null
jar --create --file "$out\ProjectGolfVP16.jar" -C build/classes projectgolf
Write-Host "built $out\ProjectGolfVP16.jar"
