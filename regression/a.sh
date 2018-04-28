TUNES=("UltraSyd - YM Type.s" "UltraSyd - Fractal.s" "test001.s" "Targhan - Midline Process - Molusk.s" "Targhan - Midline Process - Carpet.s" "Targhan - DemoIzArt - End Part.s" "Pachelbel's Canon in D major 004.s" "Pachelbel's Canon in D major 003.s" "song001_009.s" "Interleave THIS! 014.s")

regressiondir=$PWD
sc=$PWD/sc68

rm -f sc68.log


for I in "${TUNES[@]}"; do 
	echo ------------------------------------------$I;
	#echo ${I%.*}
	if [ ! -f "${I%.*}.wav" ]; then
 		$sc "${I%.*}.sndh" -q -w -o "${I%.*}.wav" >> $regressiondir/sc68.log
	fi
	cd ..
	./sndh.sh "$I"
	$sc "${I%.*}.sndh" -q -w -o "${I%.*}.wav" >> $regressiondir/sc68.log
	diff -q "${I%.*}.wav" "$regressiondir/${I%.*}.wav"
	cd $regressiondir
done


