@echo off

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)    extension="mac";;
    *)          extension="linux";;
esac

rm -f example.prg
rm -f example.prg

bin\vasm_$extension -nowarn=58 -align -spaces -noesc -no-opt -d_vasm_=1 -d_rmac_=0 -ftos example.s -o example.prg
