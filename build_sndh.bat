@echo off
sndh.bat
set steemdir=C:\steem\files
del sndh.prg >NUL 2>&1
del %steemdir%\sndh.prg >NUL 2>&1
bin\rmac -s -px -D_RMAC_=1 -D_VASM_=0 -o sndh.prg example_sndh.s
copy sndh.prg %steemdir% >NUL 2>&1
