# ST version of Arkos tracker 2 player 

Get the tracker from http://www.julien-nevo.com/arkostracker/

## Summary of attractive features (i.e. why should one use this thing?)

- Compose on PC/Mac/Linux with all the comforts of modern UIs and resolutions, then export and play the tune on a ST
- SID voices support that can be turned on and off using song events, so CPU usage can be controlled easier
- Fairly fast replay routine:
  - The vanilla version takes less than 3 scanlines on a plain Atari ST
  - The moderately optimised version takes about 2 scanlines (on a plain Atari ST)
  - The "register dump" version takes about 1/2 scanline

# How to export

To export a track from the tracker for use with these player follow these simple steps: (current for v2 alpha 4)

- Open a command line, type:

`SongToAky -reladr --labelPrefix "Main_" -spbyte "dc.b" -spword "dc.w" -sppostlbl ":" -spomt "your_tune.aks" "your_tune.s"`

Song will be auto converted to the proper format for you.


Alternatively you can do the same from inside the tracker:

- Open the tune you want to export
- Go to Edit->Song properties, and check the "PSG list" field, the frequency should be 2000000Hz. If not, click "edit" and change the tick box to "2000000 Hz (Atari ST)"
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
- Go to File->Export->Export as AKY. Check "source file" and leave ASM labels prefix as "Main".
- Check "Encode to address" and type "0" in the field.
- Check "Encode all addresses as relative to the song start: check". *Note* this is present on versions 2.0.0a3 and later! Please update your tracker if this option is not available!
- Press "Export" and choose a filename.

You can now use the exported .s file directly with the player example source.

# How to use it in your projects

The files that the player uses are the following:

File | Description
-----|------------
PlayerAky.s | The main player code
sid.s | (*optional*) The SID player code
example.s | (*optional*) Example code on how to call the player in various ways
example_sndh.s | (*optional*) Example code on how to play a SNDH file
build.bat | Windows batch script to assemble example.s using the **rmac** assembler (also `build_vasm.bat` for **vasm** assembler)
sndh.s | Skeleton code for creating a SNDH file
build_sndh.bat | Windows batch script to generate a SNDH file
build_sndh_prg.bat | Windows batch script to generate a program which plays a SNDH file
vasm.s | (*optional*) extra macros when you assemble with **vasm** assembler

In its simplest form, you can simple include `PlayerAky.s` in your project. Initialise the player by calling `PLY_AKYst_Start` with `a0` pointing to the song data you have exported. Then, every tick of your replay frequency (50Hz, 200Hz etc) simply call `PLY_AKYst_Start+2` again with `a0` pointing to the song data. Instead of `PLY_AKYst_Start+0/+2` you can also use `PLY_AKYst_Init`/`PLY_AKYst_Play`.

If you plan to use SID voices you also have to include `sid.s`. In addition to the initialisation above you also have to call `sid_ini`. Finally each timer tick you need to call `sid_play` after the player itself.

To restore the system to its initial state, call `sid_exit` (if applicable) and zero YM registers 0 to 13.

# Flavours

As seen at the top of the main player source (PlayerAky.s) or the example (example.s) there are a lot of options for using the player, which can be overwhelming. So this section will attempt to cover as many cases as possible so the programmer can configure the player to suit his/her needs.

For all switches assume that they are off only when they are assinged the value of 0, otherwise they will be on. The switches that influence the player greatly are the following:

Equate | Description
-------|------------
`UNROLLED_CODE` | This will use unrolled code which is faster than the plain code
`SID_VOICES` | This will enable SID voices for all 3 channels. Consumes vastly greater amounts of CPU time
`PC_REL_CODE` | Turns the code into PC relative. Handy if you want to relocate the player in RAM
`AVOID_SMC` | Normally the player uses self-modifying code (*SMC*) to gain performance. However this might cause problems on machines that use caches. This switch will use a different code path that avoids SMC, at the cost of some performance.
`DUMP_SONG` | This will force the player to not output any data to the PSG directly but instead write data to a buffer. See below for more details
`USE_EVENTS` | Turns on event processing. The events are external to the player, check out `example.s` for sample code.
`USE_SID_EVENTS` | Similar to `USE_EVENTS`, the difference being that this can process events that turn SID channels on and off. See below for more details

# Derivative versions

It can be quite daunting to read the player source with all the different codepaths in the same file, so a few convenience versions of the player are generated. These are inside the `generated_players` and can be included in your projects instead of the main player. They can also be used as a base to create your own custom or optimised versions. The filename of each version contains the "on" switches it was generated with.

Because of the way these sources are generated, they are not supported, nor any optimisations/fixes for them will be accepted. Please incorporate any changes to the main player source and submit that.

## `DUMP_SONG` explained further

The player will dump 13 or 14 longwords plus one word each time it's called. The reason for different sizes has to do with whether the hardware envelope is being triggered or not. In more details, the data is presented below.

Value | Comment
------|--------
`flag.w` | If non-zero, the player has dumped 14 YM registers
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
     F0 - [unused]
     F1 - set channel C to SID off
     F2 - set channel B to SID off
     F3 - set channels B and C to SID off
     F4 - set channel A to SID off
     F5 - set channels A and C to SID off
     F6 - set channels A and B to SID off
     F7 - all channels SID off
     F8 - [unused]
     F9 - set channel C to SID on
     FA - set channel B to SID on
     FB - set channels B and C to SID on
     FC - set channel A to SID on
     FD - set channels A and C to SID on
     FE - set channels A and B to SID on
     FF - all channels SID on

Note that SID voices are _not_ supported inside the trakcer, so the only way to listen to them is to create a SNDH or assemble the tune as a ST prg.

# SNDH

Note that in order to create SNDH files you *must* have rmac and rln inside the `bin` folder. The Windows versions are supplied inside the repository. Windows, Mac etc users should get and compile rmac and rln from http://shamusworld.gotdns.org/git/rmac and http://shamusworld.gotdns.org/git/rln (just CDing to the directories and typing `make` should be all that's needed provided a sane build system)

There follows a semi-automatic process to create a SNDH compliant file:

- First, the tune has to be exported as explained above.
- If SID events are required, these also have to be exported (using `conv_aks.bat`)
- Edit `sndh.s`
  - Enable or disable `SID_VOICES`
  - Enable or disable `USE_EVENTS`/`USE_SID_EVENTS`
  - Do **not** change `PC_REL_CODE` or `AVOID_SMC`!
  - Change the `TITL`, `COMM`, `RIPP`, `CONV`, `YEAR` fields
  - Set the replay frequency. Recommended is to use `TCxxx` where `xxx` is the frequency the tune was composed
- Run `build_sndh.bat`.

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
- Conversion by GGN/KÜA software productions
- Additional code by Excellence in Art
- SID voices source provided by Grazey of the PHF based on code by Abyss and Tao of Cream
- Some vasm help from @realmml
- Falcon tips and testing by Evil/DHS and Grazey/PHF
