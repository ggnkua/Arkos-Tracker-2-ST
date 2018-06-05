@echo off
set steemdir=c:\steem\files
del example.prg >NUL 2>&1
del %steemdir%\example.prg >NUL 2>&1
bin\vasm -nowarn=58 -align -spaces -noesc -no-opt -D_VASM_=1 -D_RMAC_=0 -Ftos example.s -o example.prg
rem -maxerrors=100 
copy example.prg %steemdir% >NUL 2>&1
