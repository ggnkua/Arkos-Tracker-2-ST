echo 	.include \"${1%.*}.s\" > tune_filename.s
./rmac -fb ~Oall sndh.s
./rln -z -n -a 0 x x sndh.o -o "${1%.*}.sndh"