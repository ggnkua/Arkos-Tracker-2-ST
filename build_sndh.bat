@echo off
set steemdir=C:\steem\files
call sndh.bat
del sndh.prg >NUL 2>&1
del %steemdir%\sndh.prg >NUL 2>&1
bin\rmac -s -px -D_RMAC_=1 -D_VASM_=0 -o %steemdir%\sndh.prg example_sndh.s
