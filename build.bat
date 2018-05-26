@echo off
set steemdir=c:\steem\files
del example.prg >NUL 2>&1
del %steemdir%\example.prg >NUL 2>&1
rmac -s -px -D_RMAC_=1 -D_VASM_=0 -o example.prg example.s
copy example.prg %steemdir% >NUL 2>&1
