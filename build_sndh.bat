@echo off
rem build_sndh filename.aks "title" "composer" frequency_in_Hz [SID_VOICES] [USE_EVENTS] [SID_EVENTS]

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

echo    dc.b   "SNDH"                    > sndh_header.s
echo    dc.b   "TITL","%~2",0           >> sndh_header.s
echo    dc.b   "COMM","%~3",0           >> sndh_header.s
echo    dc.b   "RIPP","Nobody",0        >> sndh_header.s
echo    dc.b   "CONV","Arkos2-2-SNDH",0 >> sndh_header.s
echo    dc.b   "TC%4",0                 >> sndh_header.s

rem Parse the rest of the paramters, if any
set SID_VOICES=0
set USE_EVENTS=0
set SID_EVENTS=0

rem skip first four parameters
set filename=%~n1
shift
shift
shift
shift

:parseloop
if not "%1"=="" (

	if /i "%1"=="SID_VOICES" (
        set SID_VOICES=1
        set SID_EXT=_SID
	) else if /i "%1"=="USE_EVENTS" (
		set USE_EVENTS=1
        set EVENTS_EXT=_EVENTS
	) else if /i "%1"=="SID_EVENTS" (
		set USE_EVENTS=1
        rem this is implied, can't have SID events without events
		set SID_EVENTS=1
        set SID_EXT=_SID
        set SIDEVENTS_EXT=_SIDEVENTS
	) else (
		echo Invalid parameter passed! "%1"
		goto :USAGE
	)

	shift
	goto :parseloop
)

bin\rmac -fr -D_RMAC_=1 -D_VASM_=0 -DSID_VOICES=%SID_VOICES% -DUSE_EVENTS=%USE_EVENTS% -DUSE_SID_EVENTS=%SID_EVENTS% -o "%filename%%SID_EXT%%EVENTS_EXT%%SIDEVENTS_EXT%.sndh" sndh.s

goto GOODBYE

:USAGE
echo usage: build_sndh.bat filename.aks "title" "composer" frequency_in_Hz [SID_VOICES] [USE_EVENTS] [SID_EVENTS]
echo (paramters in brackets are optional)

:GOODBYE
set str=
set underscore=
set SID_VOICES=
set USE_EVENTS=
set SID_EVENTS=
set SID_EXT=
set EVENTS_EXT=
set SIDEVENTS_EXT=

