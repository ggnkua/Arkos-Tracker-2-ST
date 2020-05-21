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

bin/SongToAky_linux -spbig -adr 0 -spadr ";" --sourceProfile 68000 -sppostlbl ":" -reladr -spomt "$1" $2.aky.s
bin/SongToEvents_linux -spbig -adr 0 -spadr ";" --sourceProfile 68000 -sppostlbl ":" -spomt "$1" $2.events.words.s
sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" $2.events.words.s
echo

