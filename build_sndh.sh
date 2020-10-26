#set -x
set -e

usage()
{
    echo usage: build.sndh filename.aks "title" "composer" frequency_in_Hz [SID_VOICES] [USE_EVENTS] [SID_EVENTS]
    echo '(paramters in brackets are optional)'
    exit 1
}

if [ "$1" == "" ]; then usage; fi
if [ "$2" == "" ]; then usage; fi
if [ "$3" == "" ]; then usage; fi
if [ "$4" == "" ]; then usage; fi

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)    extension="mac";;
    *)          extension="linux";;
esac

underscore="${1// /_}"
no_extension="${1//\.aks/}"
no_path=${no_extension##*/}
no_path_underscore="${no_path// /_}"

./conv_aks.sh "$1" $no_path_underscore

echo tune:                                       > sndh_filenames.s
echo     .include \"$no_path_underscore.aky.s\" >> sndh_filenames.s
echo     .long                                  >> sndh_filenames.s
echo tune_end:                                  >> sndh_filenames.s
echo     .if USE_EVENTS                         >> sndh_filenames.s
echo tune_events:                               >> sndh_filenames.s
echo     .include \"$no_path_underscore.events.words.s\" >> sndh_filenames.s
echo     .even                                  >> sndh_filenames.s
echo tune_events_end:                           >> sndh_filenames.s
echo     .endif                                 >> sndh_filenames.s

echo    dc.b   \'SNDH\'                      > sndh_header.s
echo    dc.b   \'TITL\',\'$2\',0            >> sndh_header.s
echo    dc.b   \'COMM\',\'$3\',0            >> sndh_header.s
echo    dc.b   \'RIPP\',\'Nobody\',0        >> sndh_header.s
echo    dc.b   \'CONV\',\'Arkos2-2-SNDH\',0 >> sndh_header.s
echo    dc.b   \'TC$4\',0                   >> sndh_header.s

# Parse the rest of the paramters, if any
SID_VOICES="0"
USE_EVENTS="0"
SID_EVENTS="0"

# skip first four parameters
filename=$1
shift
shift
shift
shift

while [[ $# -gt 0 ]]; do
    if [ "$1" == "SID_VOICES" ]; then
        SID_VOICES="1"
        SID_EXT=_SID
	elif [ "$1" == "USE_EVENTS" ]; then
		USE_EVENTS=1
        EVENTS_EXT=_EVENTS
	elif [ "$1" == "SID_EVENTS" ]; then
		SID_EVENTS=1
        # this is implied, can't have SID events without events
		USE_EVENTS=1
        SID_EXT=_SID
        SIDEVENTS_EXT=_SIDEVENTS        
	else
		echo Invalid parameter passed! "$1"
        usage
    fi

	shift
done

bin/rmac_$extension -fr -D_RMAC_=1 -D_VASM_=0 -DSID_VOICES=$SID_VOICES -DUSE_EVENTS=$USE_EVENTS -DUSE_SID_EVENTS=$SID_EVENTS no_path_underscore$SID_EXT$EVENTS_EXT$SIDEVENTS_EXT.s -o "$no_path.sndh"
