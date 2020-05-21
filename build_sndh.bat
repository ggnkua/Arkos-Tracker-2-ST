@echo off
rem build_sndh filename.aks "title" "composer" frequency_in_Hz

if '%1'=='' goto :USAGE
if '%2'=='' goto :USAGE
if '%3'=='' goto :USAGE
if '%4'=='' goto :USAGE

set str=%~n1
set underscore=%str: =_%
call conv_aks %1 %underscore%

echo tune:                                       > sndh_filenames.s
echo     .include "%underscore%.aky.s"          >> sndh_filenames.s
echo     .long                                  >> sndh_filenames.s
echo tune_end:                                  >> sndh_filenames.s
echo     .if USE_EVENTS                         >> sndh_filenames.s
echo tune_events:                               >> sndh_filenames.s
echo     .include "%underscore%.events.words.s" >> sndh_filenames.s
echo     .even                                  >> sndh_filenames.s
echo tune_events_end:                           >> sndh_filenames.s
echo     .endif                                 >> sndh_filenames.s

echo    dc.b   'SNDH'                    > sndh_header.s
echo    dc.b   'TITL','%~2',0           >> sndh_header.s
echo    dc.b   'COMM','%~3',0           >> sndh_header.s
echo    dc.b   'RIPP','Nobody',0        >> sndh_header.s
echo    dc.b   'CONV','Arkos2-2-SNDH',0 >> sndh_header.s
echo    dc.b   'TC%4',0                 >> sndh_header.s

bin\rmac -fr -D_RMAC_=1 -D_VASM_=0 sndh.s -o "%~n1.sndh"

goto GOODBYE

:USAGE
echo usage: build.sndh filename.aks "title" "composer" frequency_in_Hz

:GOODBYE
set str=
set underscore=
