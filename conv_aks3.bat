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
rem ##   #   knightmare.samples.s
rem ##   #   knightmare.raw.linear.s

if '%1'=='' goto :USAGE
if not '%2'=='' goto :PARAMS_OK
:USAGE
echo usage: conv_aks source.aks dest_stub
exit /b
:PARAMS_OK

bin3\SongToAky --subsong 1 -adr 0 --customSourceProfileFile bin3\rmac.xml %1 %2.aky.s
bin3\SongToEvents -adr 0 --customSourceProfileFile bin3\rmac.xml %1 %2.events.words.s
bin3\SongToSamples --customSourceProfileFile bin3\rmac.xml --sampleExportOffset 0 --sampleExportAmplitude 16 %1 %2.samples.s
bin3\SongToRawLinear --customSourceProfileFile bin3\rmac.xml %1 %2.raw.linear.s --labelPrefix "arkos_samples"

rem Since Arkos Tracker 3 removed the functionality to use relative offsets
rem (i.e. Subsong_0_XXX-Subsong0) we'll just do it by hand here. No problem
rem (incidentally, this is the only thing that was stopping Arkos Tracker 3 tunes from
rem working - if we exclude the new xml source profiles)
bin\sed -i -e "/dc.w Subsong/s/$/& - Subsong0/" %2.aky.s

rem Arkos Tracker 3 also started bombing the tune source with hundreds of
rem labels (used for converting source if memory serves).
rem This makes the symbol table explode in size and debuggers having a
rem real hard time loading the symbol table. We can't have that as
rem we would like to debug stuff from time to time, so let's trim out
rem those (otherwise) redundant labels
bin\sed -i -e "/Subsong0Disark/d" %2.aky.s
bin\sed -i -e "/Subsong0Disark/d" %2.events.words.s
bin\sed -i -e "/Subsong0Disark/d" %2.samples.s
bin\sed -i -e "/Subsong0Disark/d" %2.raw.linear.s

rem Convert event values to word size and labels to longwords
bin\sed -i -e "s/dc\.b/dc.w/gI" -e "s/dc\.w Events_/dc.l Events_/gI" %2.events.words.s

rem Strip out all effects from raw linear
bin\sed -i -e "/Effect/d" %2.raw.linear.s
bin\sed -i -e "/effects/d" %2.raw.linear.s
rem fix bug as of Arkos 3.5 tools: an empty label prefix creates a label called ":"
bin\sed -i -e "s/^:$//" %2.raw.linear.s
rem fix loop point (which is a .w. Could be a bug in AT3, but let's move on for now)
bin\sed -i -e "s/dc.w arkos_samplesloop/dc.w arkos_samplesloop-arkos_samples/gI" %2.raw.linear.s

rem Same as above, but for samples. Might not be used eventually (we can convert the dc.ws to dc.ls
rem and be rid of all the relative pointer nonsense)
bin\sed -i -e "s/\(dc.w Sample_Sample..\)/\1 - SampleDisarkPointerRegionStart0/" %2.samples.s
rem all $ characters should be converted to *
bin\sed -i -e "s/\$//" %2.samples.s

echo.
