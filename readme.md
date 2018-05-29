ST version of Arkos tracker 2 player - http://www.julien-nevo.com/arkostracker/

# How to export

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

You can now use the exported .s file directly with the player example source.

# Flavours

As seen at the top of the main player source (PlayerAky.s) or the example (example.s) there are a lot of options for using the player, which can be overwhelming. So this section will attempt to cover as many cases as possible so the programmer can configure the player to suit his/her needs.

For all switches assume that they are off only when they are assinged the value of 0, otherwise they will be on. The switches that influence the player greatly are the following:

`UNROLLED_CODE` | This will use unrolled code which is faster than the plain code
----------------|----------------------------------------------------------------------------
`SID_VOICES` | This will enable SID voices for all 3 channels. Consumes vastly greater amounts of CPU time
`PC_REL_CODE` | Turns the code into PC relative. Handy if you want to relocate the player in RAM
`AVOID_SMC` | Normally the player uses self-modifying code (*SMC*) to gain performance. However this might cause problems on machines that use caches. This switch will use a different code path that avoids SMC, at the cost of some performance.
`DUMP_SONG` | This will force the player to not output any data to the PSG directly but instead write data to a buffer. See below for more details
`USE_EVENTS` | Turns on event processing. The events are external to the player, check out `example.s` for sample code.
`USE_SID_EVENTS` | Similar to `USE_EVENTS`, the difference being that this can process events that turn SID channels on and off. See below for more details

## `DUMP_SONG` explained further

The player will dump 13 or 14 longwords plus one word each time it's called. The reason for different sizes has to do with whether the hardware envelope is being triggered or not. In more details, the data is presented below.

`flag.w` | If non-zero, the player has dumped 14 YM registers
---------|---------------------------------------------------
`$0000XX00` | First YM register
`$0100XX00` | Second YM register
...         |       ...
`$0C00XX00` | Thirteenth YM register
`$0D00XX00` | **Optional** Fourteenth YM register

This format is used because it's probably the fastest way to write data to the YM. The player code then boils down to something like:
        lea $ffff8800.w,a1
        movem.l (a0)+,d0-d7/a2-a6
        movem.l d0-d7/a2-a6,(a1) 
or (for 14 longwords)
        movem.l (a0)+,d0-d7/a1-a6
        lea $ffff8800.w,a0
        movem.l d0-d7/a1-a6,(a0) 
assuming that `a0` points to the data to be played.

In `example.s` there is sample code to illustrate how to dump and replay a tune. First of all, `DUMP_SONG` has to be set to non-zero. There are two other equates that help fine tune the dumping: `DUMP_SONG_SKIP_FRAMES_FROM_START` that tells the dumping routine to skip as many frames from the beginning of the tune as required, and `DUMP_SONG_FRAMES_AMOUNT` that contains the amount of frames to be dumped. A suitable buffer has to be defined in order to store the data. For simplicity's sake this is allocated as `DUMP_SONG_FRAMES_AMOUNT`\*(14\*4+2) bytes, which means that space is allocated for the worst case. If memory is really tight a trick here would be for the programmer to allocate the RAM, then run the dumping, then inspecting the RAM to actually determine how many bytes are required.

## `USE_SID_EVENTS`

In Arkos Tracker 2, all events starting with F (F0, F1, F2 etc up to FF) are now SID events. The lowest three bits control which channels are SID-enabled. Timers used are ABD (for channels ABC, respectively). The bit pattern is 1111 xABC, which means:
     F0 - No channels use SID - no timers
     F1 - Only channel C uses SID - timer D only
     F2 - Only channel B uses SID - timer B only
     F3 - Channels B and C use SID - timer B and D
     F4 - Only channel A uses SID - timer A only
     F5 - Channels A and C use SID - timer A and D
     F6 - Channels A and B use SID - timer A and B
     F7 - All channels use SID - timers A, B and D

# SNDH

There follows a semi-automatic process to create a SNDH compliant file:

- First, the tune has to be exported as explained above.
- If SID events are required, these also have to be exported (using `conv_aks.bat`)
- Edit `sndh.s`
  - Enable or disable `SID_VOICES`
  - Enable or disable `USE_EVENTS`/`USE_SID_EVENTS`
  - Do **not** change `PC_REL_CODE` or `AVOID_SMC`!
  - Change the `TITL`, `COMM`, `RIPP`, `CONV`, `YEAR` fields
  - Set the replay frequency. Recommended is to use `TCxxx` where `xxx` is the frequency the tune was composed
- Run `sndh.bat`.

If everything went fine then a file called `sndh.sndh` should be created and can be played by any compliant SNDH player.

# Code maturity

As discussed above the player has a few different code paths depending on the switches defined. Not all of them are equally optimised, so the following table will present the situation in detail:

Flavour | Comments
--------|---------
everything off, i.e. vanilla player (common to all flavours) | Optimal, with the exception of "In `PLY_AKYst_RRB_NIS_ManageLoop` there is an auto-even of address happening due to the way the data is exported. This can be fixed by a) Exporting all data as words, b) pre-parsing the tune during init, finding odd addresses, even them and patch all affected offsets."
`SID_VOICES` | When `UNROLLED_CODE` is defined, pretty optimal. With `UNROLLED_CODE` off the writes to the internal table are slow.
`PC_REL_CODE` | Slightly slower than the vanilla player
`AVOID_SMC` | Slower then the vanilla player
`DUMP_SONG` | Same comments for `SID_VOICES` apply

In addition to this, the code in `example.s` for `USE_EVENTS` and `USE_SID_EVENTS` should be treated as reference for now.

Finally the whole code inside `sid.s` should also be treated as reference. There seem to be lots of room for speedups but this will potentially lead to non system friendly code. So this is postponed for now.

# Credits

- Original player source and tracker by Targhan/Arkos
- Conversion by GGN/KUA software productions
- Additional code by Excellence in Art
- SID voices source provided by Grazey of the PHF based on code by Abyss and Tao of Cream
