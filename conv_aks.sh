#!/bin/sh

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

if [ '$1' == '' ]; then
	echo usage: conv_aks source.aks dest_stub
    exit 1
fi
if [ '%2' == '' ]; then
	echo usage: conv_aks source.aks dest_stub
    exit 1
fi


bin/SongToAky -adr 0 -spadr ; --sourceProfile 68000 -sppostlbl ":" -reladr -spomt $1 $2.aky.s
bin/SongToEvents -adr 0 -spadr ; --sourceProfile 68000 -sppostlbl ":" -spomt $1 $2.events.words.s


