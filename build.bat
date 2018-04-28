@echo off
set steemdir=c:\steem\files
rem set steemdir=e:\games\steem\files
del example.prg >NUL 2>&1
del %steemdir%\example.prg >NUL 2>&1
rem rmac -s -px example.s -o example.prg
rmac -px example.s -o example.prg
copy example.prg %steemdir%
