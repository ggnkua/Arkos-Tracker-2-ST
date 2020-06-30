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

if '%1'=='' goto :USAGE
if not '%2'=='' goto :PARAMS_OK
:USAGE
echo usage: conv_aks source.aks dest_stub
exit /b
:PARAMS_OK

bin\SongToAky -adr 0 -spadr ; --sourceProfile 68000 -sppostlbl ":" -reladr -spomt %1 %2.aky.s
bin\SongToEvents -adr 0 -spadr ; --sourceProfile 68000 -sppostlbl ":" -spomt %1 %2.events.words.s

rem Take care of endianess swap. Seems to be required for versions at least 2.0.0a8 and later
rem Do not use for earlier versions!
bin\sed -i -e "s/\( *dc.b \)\([[:digit:]]\+\), \([[:digit:]]\+\)/\1\3,\2/gI" %2.aky.s

rem Convert event values to word size and labels to longwords
bin\sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" %2.events.words.s
echo.
