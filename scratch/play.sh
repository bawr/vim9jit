#!/bin/bash

set -e
set -u

LRS="${HOME}/.luarocks/share/lua/5.1"
LRL="${HOME}/.luarocks/lib/lua/5.1"

export LUA_PATH=$(tr '\n' ';' <<__
../lua/?.lua
../lua/?/init.lua
${LRS}/?.lua
${LRS}/?/init.lua
__
)

export LUA_CPATH=$(tr '\n' ';' <<__
${LRL}/?.so
__
)

if [[ ( "$#" != '1' ) || ( "$1" != '--watch' ) ]]
then
    exec lua-5.1 ./play.lua "$@"
else
    echo 123
fi