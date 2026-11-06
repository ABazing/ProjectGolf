#!/usr/bin/env bash
# Offline checks. Needs any Lua 5.1+ interpreter: `lua`, `luajit`, or LuaTeX's `luatex --luaonly`.
set -e
cd "$(dirname "$0")/.."
LUA=${LUA:-lua}
MEDIA=Contents/mods/ProjectGolf/common/media
$LUA tests/syntax.lua $(find Contents -name '*.lua')
$LUA tests/physics_test.lua $MEDIA/lua/shared
$LUA tests/smoke.lua $MEDIA
$LUA tests/vp.lua $MEDIA
$LUA tests/vp16.lua $MEDIA
$LUA tests/maptees.lua $MEDIA
