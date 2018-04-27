@echo off

if [%1] == [] (
	echo usage: sndh.bat ^<filename of tune.s^>
	exit /b
)

echo 	.include "%~1">tune_filename.s
rmac -fb ~Oall sndh.s
rln -z -n -a 0 x x sndh.o -o "%~n1.sndh"