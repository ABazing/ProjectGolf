#!/usr/bin/env bash
# Builds ProjectGolfVP16.jar (the Viewpoint 0.1.6 bridge) into the ProjectGolf mod. Needs a JDK 17+.
#   ./build.sh /path/to/Viewpoint-0.1.6/42/media/java/client/Viewpoint.jar
# The stubs (ZombieBuddy annotations, LWJGL GL classes) are compile-only: the jar holds projectgolf/vp16 only.
set -e
cd "$(dirname "$0")"
VPJAR=${1:?path to Viewpoint 0.1.6 Viewpoint.jar}
rm -rf build && mkdir -p build/stubs build/classes
javac --release 17 -nowarn -d build/stubs $(find stubs -name '*.java')
javac --release 17 -Xlint:all -encoding UTF-8 -cp "build/stubs:$VPJAR" -d build/classes src/projectgolf/vp16/*.java
OUT=../Contents/mods/ProjectGolf/42/media/java/client
mkdir -p "$OUT"
jar --create --file "$OUT/ProjectGolfVP16.jar" -C build/classes projectgolf
echo "built $OUT/ProjectGolfVP16.jar"
