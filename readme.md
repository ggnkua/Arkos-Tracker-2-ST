ST version of Arkos tracker 2 player - http://www.julien-nevo.com/arkostracker/

To export a track from the tracker for use with these player follow these simple steps (hopefully this will change soon to something that's actually easy!):

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
  - Little endian: uncheck
- Go to File->Export->Export as AKY. Check "source file" and leave ASM labels prefix as "Main". Check "Encode to address" and type "0" in the field. Press "Export" and choose a filename.
- sed -e "s/ : dc/\r\tdc/gI" filename.s >convert1.s
- sed -e "s/\(dc.w Main_Subsong0_.[A-z|0-9|_]*\?\)/\1-Main_Subsong0/gI" convert1.s >convert2.s

You can use convert2.s directly with the player example source