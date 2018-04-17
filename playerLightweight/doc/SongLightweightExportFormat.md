# Song lightweight format (AKL)

This explains the format of a Song, when exported to AKL/"lightweight". This is useful for productions such as 4k, which require tiny player and music, but it is powerful enough to support actually most music, or with very little modifications.

There are the limitions:

- Only one PSG per Subsong is encoded.

- Instrument:

  - Only software, noSoftNoHard, SoftToHard, SoftAndHard (limited).
  - No forced software period.
  - Only 128 instruments max.
  - Instrument Arpeggio is present.
  - Instrument Pitch is present.
  - Hardware envelope: only 8 or 0xa.
  - No retrig.
  - Length = 128. Only to be sure it is not encoded on more than 256 bytes.
  - No noise for hardware sound (who uses those?).
  - No shift pitch for hardware envelope in SoftToHard.
  - SoftAndHard is limited: The hardware part is only a forced period, to allow "ben daglish" effect.


- Arpeggio (in tracks):

  - No speed managed by the player, so each step is duplicated.
  - Limited to 7 bits signed values.
  - Only 64 arpeggios max.
  - Limited to 128 in length.
- Pitch (in tracks):

  - No speed managed by the player, so each step is duplicated.
  - Limited to 7 bits signed values.
  - Only 64 pitches max.
  - Limited to 128 in length.
- No event track.
- No speed track, but the first speed of each SpeedTracks encoded, so each Pattern can have its own speed nonetheless.
- No legato.
- One effect column. But two specific ones can be combined:
  - Volume + Pitch up/down.
  - Volume + Arpeggio.
  - Reset + Arpeggio.
- Limited effects: (fast) pitch up/down, reset with volume, volume, arpeggio table, pitch table.


## Song

### Header of the Song

	db "ATLW"           ;ID tag
	db 0				;Format version.
	dw FMInstrumentTable
	dw ArpeggioTable
	dw PitchTable

Then follow the addresses of the Subsongs.

```
dw subsong0
dw subsong1
dw subsong2
...
```



The following data are shared among the Subsongs of the Song.

### Arpeggios

List of all the Arpeggios, including the 0 (the "empty" Arpeggio).

```
ArpeggioTable:
dw 0 ("empty" Arpeggio, not encoded)
dw Arpeggio1
dw Arpeggio2
dw ...
```

#### Arpeggio

They have no speed. Their range is more limited than the generic format.

For each Arpeggio:

```
76543210
vvvvvvvf

f = end?

if f = 0
	v = signed value (-64 : 63).
if f = 1,
	v is offsetOfLoop (>=0).
```

### Pitches

List of all the Pitches, including the 0 (the "empty" Pitch).

```
PitchTable:
dw 0 ("empty" Pitch, not encoded)
dw Pitch1
dw Pitch2
dw ...
```

#### Pitch

They have are the exact same as Arpeggio, encoded to 7 bits signed, however the encoded values are **inverted**: a pitch of 1 is encoded as -1. This is because a pitch of 1, for the user, means "higher", so the period is actually decrease. This is already done inside the Arkos Tracker 2 player. The Z80 player can thus simply read the value and add it.



### FM Instruments

List of all the FM instruments, including the 0 (the "empty" one), which is always present.

```
dw Instrument0 (the "empty" sound, encoded)
dw Instrument1
dw Instrument2
dw ...
```



### FM Instrument

Header

```
db speed (>=0, 0 is fastest)
```

For every Cell:

Possible columns to encode:

```
type
00 = No software, no Hardware, or end.
01 = Software.
10 = Software to Hardware.
11 = Software and Hardware.

volume (4)
noise (5)
software pitch (15)

ratio (3)
envelope bit (1) (for 8 or 0xa)
```

The encoding of each cell depends on the type.

```
76543210
xxxxxxtt

t = type
x = data
```

##### NoSoftNoHard or end

To encode: volume, noise?.

Also used to mark the end/loop of a sound. If a sound stops, it loops to the "empty" sound.

```
76543210
nvvvve00

e = end of sound? If yes,
	dw InstrumentCell to go to (may be empty sound if the sound stops).
n = noise?
v = volume
```

If noise:

```
db noise
```

Possible optimization: if volume = 0, noise not encoded. BUT this could has some influence on rare occasions (noise on channel 1, noise on channel 3 with volume 0: channel 1 should be heard with the noise of channel 3).

##### SoftOnly

To encode: volume (>0), noise?, pitch?, arpeggio?.

```
76543210
epvvvv01

v = volume
p = pitch?
e = noise and/or arpeggio?
```

Optimization: if volume = 0, encode as NoSoftNoHard.

If noise but no arpeggio, one byte is lost... Choices have to be made!

```
76543210
aaaaaaan

n = noise?
a = signed arpeggio, or 0 if not used.

If noise:
db noise
```

If pitch:

```
dw pitch
```



##### SoftToHard

To encode: arpeggio?, pitch?, ratio, envelope bit (0 = 8, 1 = 0xa).

First byte:

```
76543210
arrrep10

p = pitch?
e = envelope bit.
r = inverted ratio (7 - desired ratio).
a = arpeggio?
```

If arpeggio:

```
db arpeggio
```

If pitch:

```
dw pitch
```

**Warning**, the apeggio/envelope/pitch structure is shared with SoftwareAndHardware! Don't change it!



##### Software and Hardware

Only present to allow "Ben Daglish" type of sound, that is, a software sound with a hardware sound which is only a forced period.

To encode: arpeggio?, pitch?, envelope bit (0 = 8, 1 = 0xa).

First byte:

```
76543210
a---ep11

p = pitch?
e = envelope bit.
a = arpeggio?
```

If arpeggio:

```
db arpeggio
```

If pitch:

```
dw pitch
```

In any case:

```
dw hardwarePeriod (>0).
```

**Warning**, the apeggio/envelope/pitch structure is shared with SoftwareToHardware! Don't change it!







## Subsong

There is at least one Subsong, but there can be many.

For each Subsong, duplicates the following structures, one per Subsong.

### Linker

For every position:

```
76543210
----thsp

p = pattern or end of song? 0 if end of song.
	If end of song, the other bits are 0, so the byte is 0. Then:
    dw loopAddress
s = speed change?
h = height change?
t = transposition change?

if speed change:
	db speed (>0).

if height change:
	db lineCount (0-127)

if new transposition:
	db transp1, transp2, transp3
```

Warning when encoding! If the transpositions at the end of the song are not the same as at the beginning/the loop, the latter must be encoded.



In any case:

```
dw track1Address
dw track2Address
dw track3Address
```



### Tracks

A Track can be up to 128 Cells.

The Cells look like this:

		Note  Inst  (Fx1  
	1   C#2   01    (A1234
	2   ---   --    (...)

#### TrackCell

A note can be from 0 to 119, but this requires 7 bits. In order to optimize, only the most used octaves are encoded by default: from 2 to 6: 0-59: 6 bits only, plus 4 possibilities. To reach the other octaves, escape codes are used.

	76543210
	nedddddd
	ww
	
	d = note or data
	e = effect?
	n = if note, new instrument?
	w = wait?
	
	76543210
	ne(0-59)	Note (from octave 2 to 5 only), maybe effect.
	   + if "n": db newInstrumentNumber * 2
	--( 60 )	No note, effect (present, else it would be Wait).
	--( 61 )	Long wait for lines.
	   + db lineCount (>=0) (0 = 1 line to wait, 127 = 128 lines to wait).
	ww( 62 )	Short wait for (w + 1) lines (w = 0-3).
	ne( 63 )	Escape code for note (is note is octave <2 or >6).
	   + db full note
	   + if "n": db newInstrumentNumber * 2

If effect, it is encoded right after.




#### EffectBlock

Encoding of the effect:

	76543210
	nnnxxxxx
	
	n = effect number
	x = effect data
	
	Effects:
	000 = Reset, xxxx = invertedVolume (0 = full volume, 15 = min volume).
	001 = Arpeggio table, xxxxx = Arpeggio number. 0 = stop Arpeggio Table.
	010 = Pitch table, xxxxx = Pitch number. 0 = stop Pitch Table.
	011 = Pitch up/down, xxxxx = 0 = stop Pitch, 1 = Pitch used.
	      if pitch used:
		  	dw positive pitch, bit 15 is sign (1 for negative).
	100 = Volume + possible Pitch up/down.
		  zxxxx. x = invertedVolume (0 = full volume, 15 = min volume).
		  z = pitch? If yes,
		  	dw positive pitch (0 = stop pitch), bit 15 is sign (1 for negative). Same encoding as above.
	101 = Volume + Arpeggio Table.
		  xxxx = invertedVolume (0 = full volume, 15 = min volume).
		  db Arpeggio number. 0 = stop Arpeggio Table.
	110 = Reset + Arpeggio Table.
		  xxxx = invertedVolume (0 = full volume, 15 = min volume).
		  db Arpeggio number. 0 = stop Arpeggio Table.
	111 = Unused

Watch out for the Pitch encoding : the encoding is **always** positive, but the bit 15 indicates the sign (0 for positive, 1 for negative). Thus, except the bit 15, #1ff and -#1ff will be encoded the same way.

