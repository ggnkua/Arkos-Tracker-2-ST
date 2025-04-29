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

bin3\SongToAky --subsong 1 -adr 0 --customSourceProfileFile bin3\rmac.xml %1 %2.aky.s
bin3\SongToEvents -adr 0 --customSourceProfileFile bin3\rmac.xml  %1 %2.events.words.s

rem Since Arkos Tracker 3 removed the functionality to use relative offsets
rem (i.e. Subsong_0_XXX-Subsong0) we'll just do it by hand here. No problem
rem (incidentally, this is the only thing that was stopping Arkos Tracker 3 tunes from
rem working - if we exclude the new xml source profiles)
bin\sed -i -e "/dc.w Subsong/s/$/& - Subsong0/" %2.aky.s

rem Convert event values to word size and labels to longwords
bin\sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" %2.events.words.s
echo.
