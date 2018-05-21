ST version of Arkos tracker 2 player - http://www.julien-nevo.com/arkostracker/

Note: this is the barebones player - it does not feature any fancy features like SID voices or whatever else we come up with. This is included as an example if you want to include Arkos 2 tunes in your production. For a more complete and up-to-date version of the player, visit https://github.com/ggnkua/Arkos-Tracker-2-ST or https://bitbucket.com/ggnkua/Arkos-Tracker-2-ST

To export a track from the tracker for use with these player follow these simple steps: (current for v2 alpha 4)

- Open a command line, type:

SongToAky -reladr --labelPrefix "Main_" -spbyte "dc.b" -spword "dc.w" -sppostlbl ":" -spomt "your_tune.aks" "your_tune.s"

Song will be auto converted to the proper format for you.


Alternatively you can do the same from inside the tracker:

- Open the tune you want to export
- Go to Edit->Song properties, and check the "PSG list" field, the frequency should me 2000000Hz. If not, click "edit" and change the tick box to "2000000 Hz (Atari ST)"
- (One time only setup) Go to File->Setup and click "source properties". Press the "+" button to create a new profile, name it something like "68000, with comments". Then fill in the fields as follows:
  - Current address declaration: ;
  - Comment declaration: ;
  - Asm source file extension (without "."): s
  - Binary source file extension (without "."): bin
  - Encode comments: Check
  - Byte declaration: dc.b
  - Word declaration: dc.w
  - Labels prefix: (leave blank)
  - Labels postfix: :
  - Little endian: check
  - One mnemonic type per line: check
- Go to File->Export->Export as AKY. Check "source file" and leave ASM labels prefix as "Main". Check "Encode to address" and type "0" in the field. Check "Encode all addresses as relative to the song start: check". Press "Export" and choose a filename.

You can now use the exported .s file directly with the player example source, just edit the tune filename and run "build.bat". Notice that the sources were written with the rmac assembler in mind (http://virtualjaguar.kicks-ass.net/builds/ for Windows builds, git clone http://shamusworld.gotdns.org/git/rmac to build from source).
