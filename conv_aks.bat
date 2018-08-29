@echo off
rem ####################################################################
rem ## Convert script
rem ##
rem ## Usage:
rem ##   conv_aks source.aks dest_stub
rem ##
rem ## Example:
rem ##   conv_aks knightmare.aks tunes\knightmare
rem ##   # outputs:
rem ##   #   knightmare.aky.s
rem ##   #   knightmare.events.words.s

if '%1'=='' (
	echo usage: conv_aks source.aks dest_stub
    exit /b
)
if '%2'=='' (
	echo usage: conv_aks source.aks dest_stub
    exit /b
)


bin\SongToAky -adr 0 -spadr ; --sourceProfile 68000 -sppostlbl ":" -reladr -spomt %1 %2.aky.s
bin\SongToEvents -adr 0 -spadr ; --sourceProfile 68000 -sppostlbl ":" -spomt %1 %2.events.words.s
bin\sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" %2.events.words.s
