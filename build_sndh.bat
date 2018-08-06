@echo off
del sndh.o >NUL
bin\rmac -D_RMAC_=1 -D_VASM_=0 -fb sndh.s
bin\rln -z -n -a 0 x x sndh.o -o "sndh.sndh"
