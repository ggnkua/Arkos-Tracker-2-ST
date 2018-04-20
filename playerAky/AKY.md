# Arkos Tracker AKY



# The format

## Header

A small header is encoded for a player to be able to play any songs, but the current player does not take it an account. It can be discarded if the song parameters are known. The current players are channel-count specific anyway.

```
db formatVersion (bit 0-6) + littleEndian? (b7. 1 = little endian, 0 = big endian).
db channelCount (>0). Should be a multiple of 3, but this is not mandatory.
```

For each PSG (count according to the channel count. If one channel is missing, a whole PSG is encoded anyway) :

```
 dd psgFrequency (4 bytes). The PSG frequency, in Hz (1000000 for a CPC).
```



## Linker

The Linker is very simple.

Each Track is considered unique according to its transposition, the Speed track, or ANY effect that would have been triggered before!

```
;Pattern 0
dw duration (in frames. 0 = end of song)
dw Address Track x
dw Address Track y
dw Address Track z

Linker_Loop
;Pattern 1
...
..

;At the end of the song, loops.
dw 0
dw Linker_Loop
```



## Track encoding

Warning, the Block duration can only be 256 max! Blocks may loop.

Also, note than the end of the Track is not managed here at all.

For each block:

```
db duration
dw blockAddress
```



## Block encoding

Data to be possibly encoded:

- Volume (4 bits) (useless if hardware only)
- Noise (5 bits)
- Sound (1 bit)
- Software period (12 bits)
- Hardware period (16 bits) (only useful if hardware sound)
- Hardware envelope (3 bits) (only useful if hardware sound)
- Hardware retrig (1 bit) (only useful if hardware sound)


The Block size can only be **256 max**!

### Structure

One frame for one channel consists of either an "**initial state**", or a "**non-initial state**". Once this state is read and applied, the job is done for this frame on this channel. The next frame will simply read and interpret the following bytes, which will always be a "non-initial state".



There is no header, it aways starts with an "initial state", and at least one or more "non-initial states".



A loop tag is added at the end, obviously as a "non-initial state". It **only loops** on a "non-initial state".

In the (unlikely) event that a block should consist only of one looping frame, it will be doubled so that the loop is performed only on the non-initial state.



### Initial state data

A bit longer because it needs more data to initialize the registers right.

```
76543210
      tt

t = type.
	00 = no software no hardware.
	01 = software only.
	10 = hardware only.
	11 = software and hardware.
```

#### No Software no hardware

```
7  6  5  4  3  2  1  0
0  v  v  v  v  n  t  t

n = noise?
v = volume
```

*Note:* an optimization is made because bit 7 is 0. If changed, watch out for the Z80 code.

Else if noise:

`db noise`

#### Software only

```
7  6  5  4  3  2  1  0
0  v  v  v  v  n  t  t
               
n = noise?
v = volume.
```

*Note:* an optimization is made because bit 7 is 0. If changed, watch out for the Z80 code.

If noise:

`db noise`

In all cases: the software period.

`dw softwarePeriod`



#### Hardware only

```
7  6  5  4  3  2  1  0
e  e  e  e  n  r  t  t

r = retrig?
n = noise?
e = envelope
```

If noise:

`db noise`

In all cases:

`dw hardwarePeriod`



#### Software and hardware

```
7  6  5  4  3  2  1  0
e  e  e  e  n  r  t  t

r = retrig?
n = noise?
e = envelope
```

If noise:

`db noise`

In all cases:

```
dw softwarePeriod
dw hardwarePeriod
```



### Non initial states

These are encoded after the initial state, and are only differences, if possible.

The loop might be encoded in this state.

#### About the loop

A loop may be added so that same lines at the end could be factorized. This works fine BUT only the lines from the end must be looping, else a problem will occur because the sounds are encoded as differences, so artefacts will appear if the loop is generated from anywhere inside the sound. The loop **must** be searched **from the end** of the sound. To simplify the Z80 code and allow better "sound jump", a loop never loops to the initial state.



One important aspect is that it is possible to pass from one state (for example, software only) to any other (for example, software and hardware). So the states must be able to encode these differences.

Important note about noise: it is off by default in the code, so it must be activated. Ideally, if the noise is different, it should be given (>0). However, it is often stored in a different byte, so most of the time it is faster to encode it without the IsNewNoise bit.

```
76543210
      tt

t = type.
	00 = no software no hardware.
	01 = software only.
	10 = hardware only.
	11 = software and hardware.
```



#### Difference - no software no hardware or loop

    7  6  5  4  3  2  1  0
    n  vv vv vv vv v  0  0
                l
                
    v = new volume? If 1, vv is the volume. If 0, the vv flags are used for the possible loop.
    l = loop? Only relevant if v = 0.
    n = noise? Always 0 in case of loop.

If noise:

`db noise (>0)  ` 

If loop: 

`dw addressToLoopToNonInitialState		;Non-initial state only!`

**FIXME A bit sad that the noise is encoded even if the same!**



#### Difference - software only

```
7        6   5  4  3  2  1  0
mspnoise lsp v  v  v  v  0  1

v = volume.
mspnoise = new Most Significant byte of Period AND/OR noise.
lsp = new Most Significant byte of Period?
```

If LSP:

`db period & 0xff`

If MSP:

```
76543210
in  pppp

i = isNoise? If yes, open the noise channel.
n = new Noise? If !isNoise, 0.
p = MSB of period (encoded regardless its usefulness)
```

If new noise:

`db noise  ` 



#### Difference - hardware only

```
7   6   5  4  3  2  1  0
lsp msp nr e  e  e  1  0

e = envelope.
msp = new Most Significant byte of Period?
lsp = new Most Significant byte of Period?
nr = new noise or retrig?
```

If LSP:

`db period & 0xff`

If MSP:

`db period / 256`

If new noise or retrig:

`See structure below`

Same as "software and hardware". The code is probably also shared, so watch out!



#### Difference - software and hardware

```
7  6  5    4    3    2    1  0
rn ne mssp lssp mshp lshp 1  1

lshp = new Less Significant byte of Hardware Period?
mshp = new Most Significant byte of Hardware Period?
lssp = new Less Significant byte of Software Period?
mssp = new Most Significant byte of Software Period?
ne = new envelope?
rn = retrig or noise/new noise?
```

If LSHP:

`db hardwarePeriod & 0xff`

If MSHP:

`db hardwarePeriod / 256`



If LSSP:

`db softwarePeriod & 0xff`

If MSSP:

`db softwarePeriod / 256`



If new envelope:

`db envelope (4 bits)`



If retrig or new noise: NOTE: Same structure as "software and hardware". The code is probably also shared, so watch out!

```
76543210
ooooonir

r = retrig?
i = isNoise? If yes, open the noise channel.
n = new Noise? If !isNoise, 0.
o = noise (>0).
```

