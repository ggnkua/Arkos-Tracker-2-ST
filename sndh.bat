@echo off

bin\rmac -fb sndh.s
bin\rln -z -n -a 0 x x sndh.o -o "sndh.sndh"
