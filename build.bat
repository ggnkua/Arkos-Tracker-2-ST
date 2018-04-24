@echo off
rem set steemdir=c:\steem\files
set steemdir=C:\u-blox\workspaces\gottardo_trial\0\0\files\
rem set steemdir=e:\games\steem\files
del example.prg >NUL
del %steemdir%\example.prg >NUL
rem rmac -s -px example.s -o example.prg
rmac -px example.s -o example.prg
copy example.prg %steemdir%
