# Song generic format (AKG)

This explains the format of a Song, when exported to AKG/"generic" format. The input song is supposed to be already optimized (only the useful tracks, instruments, arpeggio, pitch, etc.), but it is not mandatory.

As there can be several Subsongs per Song, the Song only holds the common data: Arpeggios, Pitches, Instruments (FM, samples) and EffectBlocks.

Subsongs may be encoded in different files.



**Note:** All pitches are encoded as inverted compared to the one displayed in AT2: it is more user friendly to have a positive pitch going "higher". However, the period must decrease.



## Song

### Song metadata

	db "AT20"           ;ID tag
	dw ArpeggioTable
	dw PitchTable
	dw FMInstrumentTable
	dw EffectBlockTable

For each subsong:

	dw subsongAddress

​	
### Arpeggios

List of all the Arpeggios, excluding the 0 (the "empty" Arpeggio). The list may be empty.

	dw Arpeggio1
	dw Arpeggio2
	dw ...

#### Arpeggio

First, a header:

	db speed (from 1 to 256 (0)).
Then, the values:


	db value (-127 : 127)
		if -128 (unreachable value), Loop:
			dw addressOfLoop



### Pitches

List of all the Pitches, excluding the 0 (the "empty" Pitch). The list may be empty.

	dw Pitch1
	dw Pitch2
	dw ...

#### Pitch

First, a header:

	db speed (from 1 to 256 (0)).
Then, the values:


	dw value (-4095 : 4095).
	dw nextValue ($ + 2 to go the next step, or the Pitch looping address).
	dw value...

Warning, the values for the Pitches are inverted compared to the editor. In the player, negative pitch are for positive value in the editor.



### FM Instruments

#### FM Instruments metadata

	db speed (from 1 to 256 (0)).
Note that the "retrig?" flag that was present in AT1 and STarKos is no more encoded here: if present, to simplify the code as it is seldomly used, the first line is set a retrig flag, and all the other lines added. If the loop starts at line 0, the original cell is added at the end, and the loop loops at index 1.

Then are encoded the Instrument Cells, one after the other. One flag indicates the looping, directly to one cell of this instrument, or to the "empty" instrument if the sound stops

	76543210
	     ttt
	     
	t = type
		 000 = No soft no hard
		 001 = Soft only
		 010 = Soft to Hard
		 011 = Hard only
		 100 = Hard to Soft
		 101 = Soft and Hard
		 110 = End without Loop
		 111 = End with loop
		 
	IDEA (NOT USED):
	rrrrr111 = Reference: only for encoded that takes more than 2 bytes
	
	If reference:
		db lsb Offset to cell
		Cell address = rrrrr * 256 + lsb
	Only 8kb addressable.

#### InstrumentCell

Possible columns to encode:

	* type (3 bits)

	* volume (4)
	* noise (5)
	* software period (15)
	* software arpeggio (7)
	* software pitch (15)
	
	* ratio (3)
	* envelope (4)
	* retrig? (1)
	
	* hardware period (16)
	* hardware arpeggio (7)
	* hardware pitch (16)

The encoding of each cell depends on the type.

	76543210
	xxxxxttt
	
	t = type
	   000 = no soft no hard
	   001 = soft only
	   010 = soft to hard
	   011 = hard only
	   100 = hard to soft
	   101 = soft and hard
	   110 = end without loop
	   111 = end with loop
	x = data



##### NoSoftNoHard

To encode: volume, noise?.

	76543210
	vvvvn000
	
	v = volume
	n = noise?

If noise:

	000nnnnn

Possible optimization: if volume = 0, noise not encoded. BUT this could has some influence on rare occasions (noise on channel 1, noise on channel 3 with volume 0: channel 1 should be heard with the noise of channel 3).


##### SoftOnly

To encode: volume (>0), noise?, [period + arpeggio? + pitch?] / forced period.

	76543210
	ovvvv001
	
	o = simple? (if 1, no need to read the other bytes)
	v = volume

Optimization: if volume = 0, encode as a NoSoftNoHard link.

If !volume only:

	76543210
	fapnnnnn
	
	n = noise (0 if not present)
	p = pitch?
	a = arpeggio?
	f = forced software period? (0=auto)

**Warning! The "fap" bits are in a common order as in the other states. ** 

If !auto period:

	dw softwarePeriod

else

if arpeggio:

	db arpeggio

if pitch:

	dw pitch


##### SoftToHard

To encode: noise?, [soft period + arpeggio? + pitch?] / forced soft period, ratio, envelope, retrig?, hardware pitch.

**Warning:** it is the exact same format as HardToSoft, but symmetrical (invert software/hardware).

First byte:

	76543210
	neeer010
	
	n = noise?
	e = envelope (8-15)
	r = retrig?

If noise:

```
db noise
```

Second or third byte:

	76543210
	sfaphrrr
	
	r = inverted ratio (7 - ratio)
	h = hardware pitch shift?
	p = software pitch?
	a = software arpeggio?
	f = forced software period?
	s = simple? (=no need to test the other bits)


if simple, no need to read anything else. Else:

		if forced soft:
			dw softwarePeriod
	    else
	        if arpeggio:
	            db arpeggio
	
	        if pitch:
	            dw pitch
	
	    if hardware pitch shift:
	        dw hardware pitch

##### HardOnly

To encode: noise? [hardware period + arpeggio? + pitch?] / forced hardware period, envelope, retrig?.

First byte:

	76543210
	seeer011
	
	r = retrig?
	e = envelope (8-15)
	s = simple?

If simple, stop. Simple means "no arpeggio, no noise, no pitch, auto period".

Second byte:

	76543210
	fapnnnnn
	
	n = noise (0 if not)
	p = hardware pitch?
	a = hardware arpeggio?
	f = forced hardware period?

**Warning! The "fap" bits are in a common order as in the other states. ** 

if forced hardware period

	dw hardwarePeriod

else
if hardware arpeggio:

	db hardwareArpeggio

if hardware pitch:

	dw hardwarePitch


##### HardToSoft

To encode: noise? [hardware period + arpeggio? + pitch?] / forced hardware period, envelope, retrig?, software pitch.

**Warning:** it is the exact same format as SoftToHard, but symmetrical (invert software/hardware).

First byte:

	76543210
	neeer100
	
	r = retrig?
	e = envelope (8-15)
	n = noise?

if noise:

	db noise
Second and third byte:

	76543210
	sfapirrr
	
	r = inverted ratio (7 - ratio)
	i = software pitch shift?
	p = hardware pitch?
	a = hardware arpeggio?
	f = forced hardware period?
	s = simple?

if simple, nothing else to read.
if forced hardware period

	dw hardwarePeriod

else
if hardware arpeggio:

	db hardwareArpeggio

if hardware pitch:

	dw hardwarePitch
endif

if software pitch shift:

	dw softwarePitch

##### SoftAndHard

To encode: noise? [soft period + arpeggio? + pitch?] / forced soft period, envelope, retrig?, [hard period + arpeggio? + pitch?] / hard period.

First byte:

	76543210
	neeer101
	
	n = noise?
	r = retrig?
	e = envelope (8-15)

If (noise?):

`db noise`



Second byte:

	7  6  5  4  3  2  1  0
	sh fh ha hp ss fs sa sp 
	---hard---- ---soft----
	
	sh = simple hardware part?
		fh = forced hardware period?
		ha = hardware arpeggio?
		hp = hardware pitch?
	ss = simple software part?
		fs = forced software period?
		sa = software arpeggio?
		sp = software pitch?




if simple hardware part, the 4 less significant bits can be skipped.
if forced hardware period

	dw hardwarePeriod

else
if hardware arpeggio:

	db hardwareArpeggio

if hardware pitch:

	dw hardwarePitch
endif



if simple sofware part, the 4 most significant bits can be skipped.
if forced software period

```
dw softwarePeriod
```

else
if software arpeggio:

```
db softwareArpeggio
```

if software pitch:

```
dw softwarePitch
```

endif



##### End

```
76543210
-----110
```


This stops the sounds (actually makes the instrument pointer jumps to the Instrument 0).

##### End with loop

```
76543210
-----111

dw instrumentCellWhereToLoop
```

Note that "end without loop" and "end with loop" could be put in the same Type, but since we have enough left, it is faster to do so, instead of testing a bit.



#### EffectBlock Index Table

The effect blocks are common to the whole song. It can only contain 127 entries. Entries beyond that are addressed directly, but only relative to the first EffectBlock, through a 15 bits range. This means the EffectBlocks can not grow beyond 64k (should never happen though!).

```
dw effectBlock0
dw effectBlock1
...
```

May be empty.



#### EffectBlock

For each effect:

```
76543210
nnnnnnnm

n = effectNumber
m = more effect?

+ effect data (the format is effect related)
```

If more effect, encode the next effect, and so on.

#### Effects

##### Reset full volume (0)

```
No data. This is an optimization of the Reset effect, as it will surely be often used with a 0 value to get the full volume.

```

##### Reset (1)

```
db invertedVolume (0 = full volume, 15 = min volume).
```

##### Volume (2)

```
db invertedVolume (0 = full volume, 15 = min volume).
```

##### Arpeggio table (3)

```
db arpeggio table - 1 (>=0)
```

**Arpeggio table stop (4)**

**Pitch table (5)**

```
db pitch table - 1 (>=0)
```

**Pitch table stop (6)**

**Volume slide (7)**

```
dw inverted volume pitch (negative for a fade in, positive for a fade out).
```

**Volume slide stop (8)**



**Pitch up (9)**

```
dw pitch (>0).
```

The period goes down, so that frequency goes up.

**Pitch down (10)**

```
dw pitch (>0).
```

The period goes up, so that frequency goes down.

**Pitch stop (11)**

Also used for "Glide Stop".



**Glide with note (12)**

```
db note (>=0, <128)
dw speed (>=0)
```

A speed if 0 is tolerated, though it has no interest. It shouldn't appear in the encoding.



**Glide speed (13)**

```
dw speed (>0)
```

Glide Stop is encoded as a Pitch Stop, so the Speed encoded here is always >0.



##### Legato (14) 

```
db note
```

​	

##### Force Instrument speed (15) 

```
db speed + 1 (>0, 0 for 256)
```



##### Force Arpeggio Table speed (16) 

```
db speed + 1 (>0, 0 for 256)
```



##### Force Pitch Table speed (17) 

```
db speed + 1 (>0, 0 for 256)
```






## Subsong

The subsong contains data that is not shared with any other subsong.

## Subsong metadata

    db replayFrequency  ;0=12.5hz, 1=25, 2=50, 3=100, 4=150, 5=300
    db digiChannel		;0-2
    db psgCount			;>=1. How many PSGs are encoded.
    db loopStartIndex   ;>=0
    db endIndex         ;>=0
    db initialSpeed     ;>=0
    db baseNoteIndex    ;Note that is consider "within range" when encoded any optimized note. This note till the +55 note are "optimized". Other notes are escaped. This baseNoteIndex is determined by checking what are the most used notes and finding the most efficient "window".




### Linker

For every position:

	dw track1Address, or end if 0.
		if end: dw loop in linker. End of linker.
	dw track2Address
	dw track3Address
	if more than one PSG:
	dw track4Address
	dw track5Address
	dw track6Address
	...
	
	dw linkerBlockAddress		;Simple, fast.

This prevents a track1 from being stored at 0, but this should not be a problem, it will never happen.

### LinkerBlocks

This consists in a list of unique LinkerBlocks. No need for a table, they are addressed directly.

#### LinkerBlock

	db height
	db transposition1
	db transposition2
	db transposition3
	if more than one PSG:
	db transposition4
	db transposition5
	db transposition6
	...
	
	dw speedTrackAddress
	dw eventTrackAddress



### Tracks

A Track can be up to 128 Cells.

The Cells look like this:

		Note  Inst  (Fx1   Fx2   Fx3   Fx4
	1   C#2   01    (A1234 B---- C---- Z12--
	2   C#2   --    (...)
	3   ---   --    (...)

The case 2 is called a *legato* (a note, but no instrument: it is not restarted, only the note changes) but as it is rarely used, and in order to optimize the format on the most used cases, it is managed as an effect.

There are only 4 effects in the UI, but the format and the player allow an unlimited amount, so the generator can actually create as many effects as necessary.

#### TrackCell

A note should be from 0 to 95 at least, but this requires 7 bits. In order to optimize, only the most used octaves are encoded by default: from 2 to 6: 0-59: 6 bits only, plus 4 possibilities. To reach the other octaves, escape codes are used.

	76543210
	nedddddd
	ww
	
	d = note or data
	e = effects?
	n = if note, new instrument?
	w = wait?
	
	76543210
	ne( 0-55)	Note (from note X to X + 55), maybe effects. X is determined by the generator.
	   + if "n": db newInstrumentNumber
	?1(  60 )	No note, maybe effects. Also the fast wait to encode 1 wait.
	??(  61 )	Wait for lines.
	   + db lineCount (>=0) (0 = 1 line to wait, 127 = 128 lines to wait).
	ww(  62 )	Wait for (w + 2) lines (w = 0-3). 0 -> 2 lines to wait. 2 -> 5.
	ne(  63 )	Escape code for note (is note is out of the optimized range).
	   + db full note
	   + if "n": db newInstrumentNumber

If effects:

	76543210
	rddddddd
	
	r = index(0) or relativeAddress(1)?
	d = index or MSB relative address from the EffectBlockIndexTable (7 bits instead of 8).

if relativeAddress:

```EffectBlock
db lsbRelativeAddressFromEffectBlockIndexTable
```




### SpeedTracks

	76543210
	sssssssw
	
	w = wait? (0: s = data, 1: s = (line count to wait - 1))
	s = wait or data (if data: >0 for normal value, 0 for escape value)

If data = 0:

	db escape value.
'Wait' can thus reach value 128 (encoded as 127). But if data, the value 0 is reserved.

### EventTracks

Exactly the same as Speed Track.

**Note:** As they have the same format, the Speed/Event Tracks **binary** output could be shared.