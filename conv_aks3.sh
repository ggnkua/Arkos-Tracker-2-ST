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
    Darwin*)    extension="mac";SED=gsed;;
    *)          extension="linux";SED=sed;;
esac

bin/SongToAky_$extension -spbig -adr 0 -spadr ";" --sourceProfile 68000 -sppostlbl ":" -reladr -spomt "$1" $2.aky.s
bin/SongToEvents_$extension -spbig -adr 0 -spadr ";" --sourceProfile 68000 -sppostlbl ":" -spomt "$1" $2.events.words.s

# Since Arkos Tracker 3 removed the functionality to use relative offsets
# (i.e. Subsong_0_XXX-Subsong0) we'll just do it by hand here. No problem
# (incidentally, this is the only thing that was stopping Arkos Tracker 3 tunes from
# working - if we exclude the new xml source profiles)
$SED -i -e "/dc.w Subsong/s/$/& - Subsong0/" $2.aky.s

# Convert event values to word size and labels to longwords
$SED -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" $2.events.words.s
echo

