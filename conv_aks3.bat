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
bin3\SongToEvents -adr 0 --customSourceProfileFile bin3\rmac.xml %1 %2.events.words.s
rem bin3\SongToSamples --customSourceProfileFile bin3\rmac.xml %1 %2.samples.s
rem bin3\SongToRawLinear --customSourceProfileFile bin3\rmac.xml %1 %2.raw.linear.s --labelPrefix "arkos_samples"

rem Since Arkos Tracker 3 removed the functionality to use relative offsets
rem (i.e. Subsong_0_XXX-Subsong0) we'll just do it by hand here. No problem
rem (incidentally, this is the only thing that was stopping Arkos Tracker 3 tunes from
rem working - if we exclude the new xml source profiles)
bin\sed -i -e "/dc.w Subsong/s/$/& - Subsong0/" %2.aky.s

rem fix bug as of Arkos 3.5 tools: an empty label prefix creates a label called ":"
rem bin\sed -i -e "s/^:$//" %2.raw.linear.s

rem Same as above, but for samples. Might not be used eventually (we can convert the dc.ws to dc.ls
rem and be rid of all the relative pointer nonsense
rem bin\sed -i -e "s/\(dc.w Sample_Sample..\)/\1 - SampleDisarkPointerRegionStart0/" %2.samples.s
rem all $ characters should be converted to *
rem bin\sed -i -e "s/\$//" %2.samples.s

rem Convert event values to word size and labels to longwords
bin\sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" %2.events.words.s
echo.
