@echo off

rem TODO wth is up with caret not joining lines properly??
set TUNES="UltraSyd - YM Type.s" ^
"UltraSyd - Fractal.s" "test001.s" "Targhan - Midline Process - Molusk.s" "Targhan - Midline Process - Carpet.s" "Targhan - DemoIzArt - End Part.s" "Pachelbel's Canon in D major 004.s" "Pachelbel's Canon in D major 003.s" "song001_009.s" "Interleave THIS! 014.s"

set regressiondir=%cd%
set sc=%cd%\sc68

del sc68.log >NUL 2>&1

for %%I in (%TUNES%) do (
	rem echo plain filename:               %%I
	rem echo without quotes:               %%~I
	rem echo without quotes and extension: %%~nI

	if not exist "%%~nI.wav" %sc% "%%~nI.sndh" -q -w -o "%%~nI.wav" >> %regressiondir%\sc68.log
	cd ..
	call sndh %%I
	%sc% "%%~nI.sndh" -q -w -o "%%~nI.wav" >> %regressiondir%\sc68.log

	fc /b "%%~nI.wav" "%regressiondir%\%%~nI.wav"

	cd %regressiondir%
)


