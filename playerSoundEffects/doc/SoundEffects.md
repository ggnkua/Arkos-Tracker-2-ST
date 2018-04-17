# Sound effects

Contrary to AT1, the sound effects are not encoded within an exported Song. They are created inside a Song in AT2, but a special export needs to be done: "export sound effects". The desired sound effects are exported as a kind of YM list, which can then be played at will in the players that support sound effects. This is more handy and also more efficient, since the same sound effects can be used throughout a whole game regardless of the music and player used.



Once the sound effects are exported from AT2, use one of the player that supports them. They offer the same interface, but warning, the labels may be slightly different according to the player (different prefix: PLY_LW, PLY_AKG, etc.).

#### Initialization

```
	ld hl,soundEffects
	call PLY_InitSoundEffects
```



#### Play a sound effect

```
	ld a,soundEffectNumber			;As seen in Arkos Tracker (>0).
	ld c,channel 					;The channel where to play the sound effect: 0, 1, 2.
	ld b,invertedVolume 			;0 = full volume, 16 = no sound.
	call PLY_PlaySoundEffect
```



#### Stop a sound effect from a channel

	ld a,channel						;The channel where to stop the sound effect: 0, 1, 2.
	call PLY_StopSoundEffectFromChannel





## Format

### Header

The header simply consists of the address of each sound effect:

```
	dw Sound Effect 1
	dw Sound Effect 2
	dw Sound Effect 3
	...
```



### Sound effect format

A sound effect is composed of any number of line of Cells, which can be of various types:

- No software, no hardware.
- Software only.
- Hardware only.
- Software and hardware.

The end and loop are encoded in the "no software, no hardware" Cell.



#### No Software, no hardware

This cell is for noise effects with no sound, except maybe noise.

It also manages the loop and the end of sound.

```
76543210
nvvvve00
----l---

e = end? If 1, the remaining bits are ignored, except the third (l).
n = noise?
v = volume

if noise:
	db noise (>0)

if end:
l = loop?

if loop:
	dw loopCell
```



#### Software only

```
76543210
n-vvvv01

v = volume
n = noise?

if noise:
	db noise (>0)

in all cases:
	dw softwarePeriod
```





#### Hardware only

```
76543210
n-eeer10

r = retrig?
n = noise?
e = hardware envelope (8-15)

if noise:
	db noise (>0)

in all cases:
	dw hardwarePeriod
```

**Warning**: this is the **exact** same format as the "software and hardware", minus the software period.



#### Software and hardware

```
76543210
n-eeer11

r = retrig?
e = hardware envelope (8-15)
n = noise?

if noise:
	db noise (>0)

in all cases:
	dw hardwarePeriod
	dw softwarePeriod	
```

**Warning:** this is the **exact** same format as the "hardware only", except that it has the software period encoded after.