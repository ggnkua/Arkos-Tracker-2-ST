@echo off

rmac -fb sndh.s
rln -z -n -a 0 x x sndh.o -o "sndh.sndh"
