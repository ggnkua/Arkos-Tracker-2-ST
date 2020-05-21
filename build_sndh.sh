#set -x
set -e

usage()
{
    echo usage: build.sndh filename.aks "title" "composer" frequency_in_Hz
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
echo     .include \"$no_path_underscore.aky.s\"          >> sndh_filenames.s
echo     .long                                  >> sndh_filenames.s
echo tune_end:                                  >> sndh_filenames.s
echo     .if USE_EVENTS                         >> sndh_filenames.s
echo tune_events:                               >> sndh_filenames.s
echo     .include \"$no_path_underscore.events.words.s\" >> sndh_filenames.s
echo     .even                                  >> sndh_filenames.s
echo tune_events_end:                           >> sndh_filenames.s
echo     .endif                                 >> sndh_filenames.s

echo    dc.b   \'SNDH\'                    > sndh_header.s
echo    dc.b   \'TITL\',\'$2\',0           >> sndh_header.s
echo    dc.b   \'COMM\',\'$3\',0           >> sndh_header.s
echo    dc.b   \'RIPP\',\'Nobody\',0        >> sndh_header.s
echo    dc.b   \'CONV\',\'Arkos2-2-SNDH\',0 >> sndh_header.s
echo    dc.b   \'TC$4\',0                 >> sndh_header.s

bin/rmac_$extension -fr -D_RMAC_=1 -D_VASM_=0 sndh.s -o "$1.sndh"
