@echo off
set steemdir=.
del example.prg >NUL 2>&1
del %steemdir%\example.prg >NUL 2>&1
rmac -s -px example.s -o example.prg
copy example.prg %steemdir% >NUL 2>&1
