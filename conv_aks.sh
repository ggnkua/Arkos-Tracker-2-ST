#!/bin/bash

####################################################################
## Convert script
##
## Usage:
##   conv_aks source.aks dest_stub
##
## Example:
##   conv_aks knightmare.aks tunes\knightmare
##   # outputs:
##   #   knightmare.aky.s
##   #   knightmare.events.words.s

usage()
{
    echo usage: conv_aks source.aks dest_stub
    exit 1
}

if [ "$1" == "" ]; then usage; fi
if [ "$2" == "" ]; then usage; fi

set -e

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)    extension="mac";;
    *)          extension="linux";;
esac

bin/SongToAky_$extension -spbig -adr 0 -spadr ";" --sourceProfile 68000 -sppostlbl ":" -reladr -spomt "$1" $2.aky.s
bin/SongToEvents_$extension -spbig -adr 0 -spadr ";" --sourceProfile 68000 -sppostlbl ":" -spomt "$1" $2.events.words.s

# Take care of endianess swap. Seems to be required for versions at least 2.0.0a8 and later
# Do not use for earlier versions!
# TODO: does osx require gsed here?
sed -i -e "s/\( *dc.b \)\([[:digit:]]\+\), \([[:digit:]]\+\)/\1\3,\2/gI" $2.aky.s

# Take care of endianess swap. Seems to be required for versions at least 2.0.0a8 and later
# Do not use for earlier versions!
# TODO: does osx require gsed here?
sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" $2.events.words.s
echo

