@echo off
set steemdir=c:\steem\files
rem set steemdir=e:\games\steem\files
del example.prg >NUL
del %steemdir%\example.prg >NUL
rem rmac -s -px example.s -o example.prg
rmac -px example.s -o example.prg
copy example.prg %steemdir%
