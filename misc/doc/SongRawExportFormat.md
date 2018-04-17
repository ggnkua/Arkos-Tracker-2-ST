# Raw export

This explains how the format of the raw export of a song.


# Purpose

A raw export is especially useful when a third-party wants to take a song from AT2 but use its own player. The simplest way is get the raw data and convert it to any format he requires. Also, as an example, a Digitracker player would use a raw export and directly use it: its non-optimized data are well suited for such player.

It is possible to export:

* Any channel separately.
* Encode reference tables in the header or not.
* All Tracks Index tables (for normal, Speed, Events Tracks) or not.
* Speed Tracks or not.
* Event Tracks or not.
* The Instruments or not (sample instruments are NOT encoded).
* The Arpeggios or not.
* The Pitchs or not.
* Tracks are always present.
* With effects or not.
* Allowing RLE for empty lines, or not, for normal, Speed, Event Tracks.



Before encoding, if RLE is not allowed, the highest Track used becomes a reference to know how many lines to encode.

Only used elements are encoded (useless Tracks, Instrument, Arpeggio etc. are not).

# Header

Two flag bytes are always present:

	db flag1:
		b0: song/subsong metadata encoded?
		b1: reference table encoded?
		b2: speed tracks encoded?
		b3: event tracks encoded?
		b4: instruments encoded?
		b5: arpeggios encoded?
		b6: pitches encoded?
		b7: effects encoded? If not, the effect byte is not encoded in the Tracks, so must be not read.
		
	db flag2:
		b0: RLE for empty lines authorized?
	    b1: transposition in linker?
	    b2: height in linker?

If Song/Subsong Metadata:

```
db songName, 0
db author, 0
db composer, 0
db comments, 0

db subsongName, 0
db initialSpeed
db digichannel
dw replayRate (in Hz, decimal part removed).
db channelCount (>0). May be any number.
db psgCount (>0)
db length (how many Patterns, >0)
db loopToPosition (>=0)

for each PSG:
	dd psgFrequency (4 bytes, 1000000 for a CPC for example).
	dw referenceFrequencey (in Hz, probably always 440).
	dw samplePlayerFrequency (in Hz. 11025 for example).
```

All the PSGs of the Subsongs are encoded, regardless of if the channels are actually encoded.

So there can be 2 channels, but 4 PSGs encoded!

If reference table:

    dw linker
    dw trackIndexes
    dw speedTrackIndexes (or 0 if not encoded)
    dw eventTrackIndexes (or 0 if not encoded)
    dw instrumentIndexes (or 0 if not encoded)
    dw arpeggioIndexes (or 0 if not encoded)
    dw pitchIndexes (or 0 if not encoded)


# Linker
Always present. For each pattern:

    dw trackChannel1, trackChannel2, ...
    dw speedTrack (if wanted)
    dw eventTrack (if wanted)
    
    if height encoded:
    db height (>0).
    
    if transpositions encoded:
    db transpositionChannel1, transpositionChannel2, etc.

To mark the end:

    dw 0, loopToAddressInLinker

# Tracks

All the Cells of a Track are encoded.

The largest expression is:

    db note, instrument, [effect number, effect value]*

"note" can be:

    db 0-119   = note with instrument.
    db 120     = no note, but effect.
    db 128-255 = X empty lines (without effects), where X is (value - 128) (128 = one line empty). Only 128 is encoded if RLE is not authorized.

The "instrument". Always encoded, unless it is an fully empty line. Legato is considered an effect. If Legato is present, the instrument number is meaningless. The only problem is that if a Legato is used but effects are not encoded, then there is no way to detect it. As a solution, 255 is used as an Instrument.

    db instrument number. Only meaningful if there is a note. Instrument 0 is "stop sound". 255 if legato and effect are not encoded (see below).
If effects encoded:
for each effect:

    db effect number (0 = end).
    dw effect value (encoded only if not end).



# Speed/Event Tracks

All the Cells are encoded, No RLE is used. Shouldn't be a problem, not many are used.

For each line:

```
db speed/event, or 0 is empty.
```





# Arpeggios/Pitchs

They are encoded this way:

    db length, endIndex, loopIndex, speed

    db value1, value2, ...


# Instruments

They are encoded this way:

    db length, endIndex, loopIndex, loop?, speed (>=0), retrig? (0 = no)

For every line:

    db link (0 = softOnly, 1 = hardOnly, 2 = softToHard, 3 = hardToSoft, 4 = softAndHard, 5 = noSoftNoHard)
    db volume, noise
    dw softwarePeriod, softwarePitch : db softwareArpeggio
    db ratio
    db hardwareEnvelope
    dw hardwarePeriod, hardwarePitch : db hardwareArpeggio
    db retrig?