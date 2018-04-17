;       AKY music player, for 9 channels songs, using the PlayCity hardware for 6 channels - V1.0.
;       By Julien Névo a.k.a. Targhan/Arkos.
;       December 2016.

;       PSG sending optimization trick by Madram/Overlanders.

;       More data about PlayCity: http://www.cpcwiki.eu/index.php/PlayCity

;       Terminology:
;       PSG1 is the internal CPC PSG, considered as the "middle" PSG by PlayCity.
;       PSG2 is the "left" PlayCity PSG.
;       PSG3 is the "right" PlayCity PSGs.

;       On initialization, the PlayCity is reset and its frequency sets according to the first frequency found in the header (PSG2), as
;       PSG2 and PSG3 shares the same frequency on the PlayCity.

;       Possible optimizations:
;       SIZE: The JP hooks at the beginning can be removed if you include this code in yours directly.
;       SIZE: If you don't play a song twice, all the code in PLY_AKY_Init can be removed, except the first lines that skip the header.
;       SIZE: The header is only needed for players that want to load any song. Most of the time, you don't need it. Erase both the init code and the header bytes in the song.
;       CPU:  Retrigs are quite seldomly used. If you don't use them, you can remove all the tests (keep the bit shifts though!). Will save a dozen cycles per frame.
;       CPU:  We *could* save 3 NOPS by removing the first "jp PLY_AKY_ReadRegisterBlock" and stucking the whole code instead. But it would make the whole really ugly.

PLY_AKY_OPCODE_OR_A: equ #b7                                ;Opcode for "or a".
PLY_AKY_OPCODE_SCF: equ #37                                 ;Opcode for "scf".

PLY_AKY_PLAYCITY_SELECTWRITE_PORT_LSB_RIGHT: equ #84        ;The LSB of the PlayCity SELECT/WRITE port, for the right PSG.
PLY_AKY_PLAYCITY_SELECTWRITE_PORT_LSB_LEFT: equ #88         ;The LSB of the PlayCity SELECT/WRITE port, for the left PSG.
PLY_AKY_PLAYCITY_WRITE_PORT_MSB: equ #f8                    ;The MSB of the PlayCity WRITE port.
PLY_AKY_PLAYCITY_SELECT_PORT_MSB: equ #f9                   ;The MSB of the PlayCity SELECT port.

PLY_AKY_Start:
        ;Hooks for external calls. Can be removed if not needed.
        jp PLY_AKY_Init             ;Player + 0.
        jp PLY_AKY_Play             ;Player + 3.


;Initializes the player, sets up the PlayCity (but does not check its presence).
;IN:    HL = music address.
;OUT:   A = Carry = ok.
;MOD:   Most primary registers, but also A'.
PLY_AKY_Init:
        ;Skips the header.
        ex de,hl
        inc de                          ;Skips the format version.
        ld a,(de)                       ;Channel count.
        cp 9
        jr z,PLY_AKY_Init_NoError
        or a                            ;Error! There must be 9 channels.
        ret
PLY_AKY_Init_NoError:
        inc de

        ;Reads the first frequency, apply it to both PlayCity YMZ.
        call PLY_AKY_FindFrequencyAndSetYMZ

        ;Skips the 3 frequencies (encoded on 32 bits).
        ld hl,3 * 4
        add hl,de

        ld (PLY_AKY_PtLinker + 1),hl        ;HL now points on the Linker.

        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel4_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel5_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel6_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel7_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel8_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel9_RegisterBlockLineState_Opcode),a
        ld hl,1
        ld (PLY_AKY_PatternFrameCounter + 1),hl

        scf                     ;No error.
        ret

;Sets the YMZ frequency according to the one given. If not found, nothing is done (Atari ST is set by default, which is good, as it is the only way to select it).
;In all cases, the PlayCity is reset.
;IN:    DE = Points on the 32 bits little-endian PSG frequency that we want to set to the PlayCity.
;MOD:   DE is preserved.
PLY_AKY_FindFrequencyAndSetYMZ:
        ;Resets the PlayCity (= sets the frequencies to 2Mhz (Atari ST)).
        ld bc,PLY_AKY_PLAYCITY_WRITE_PORT_MSB * 256 + #ff
        out (c),c

        ld a,PLY_AKY_PSGFrequenciesToYMZFlag_Count
        ex af,af'

        ;IX points on the frequency of the song.
        ld ixl,e
        ld ixh,d

        ;IY points on the frequency look-up table.
        ld iy,PLY_AKY_PSGFrequenciesToYMZFlag
PLY_AKY_FindFrequencyAndSetYMZ_Loop:
        ld a,(ix + 0)
        cp (iy + 0)
        jr nz,PLY_AKY_FindFrequencyAndSetYMZ_Next
        ld a,(ix + 1)
        cp (iy + 1)
        jr nz,PLY_AKY_FindFrequencyAndSetYMZ_Next
        ld a,(ix + 2)
        cp (iy + 2)
        jr nz,PLY_AKY_FindFrequencyAndSetYMZ_Next
        ld a,(ix + 3)
        cp (iy + 3)
        jr nz,PLY_AKY_FindFrequencyAndSetYMZ_Next
        ;Match!
        ld a,(iy + 4)           ;Gets the frequency index.
        ld bc,PLY_AKY_PLAYCITY_WRITE_PORT_MSB * 256 + #80   ;#f880
        ld h,#7f
        out (c),h                                       ;Clock generator.
        out (c),a                                       ;Sends frequency index.

        ret

PLY_AKY_FindFrequencyAndSetYMZ_Next
        ex af,af'
        dec a
        ret z                                           ;No match! Returns (default to Atari ST).

        ex af,af'

        ;Next frequency!
        ld bc,5
        add iy,bc
        jr PLY_AKY_FindFrequencyAndSetYMZ_Loop

;The frequencies (hz) to YMZ flag (index).
PLY_AKY_PSGFrequenciesToYMZFlag:
        db #40, #42, #f, 0,             1               ;1000000        CPC
        db #60, #e3, #16, #0,           2               ;1500000
        db #70, #7b, #19, #0,           3               ;1670000
        db #f0, #b3, #1a, #0,           4               ;1750000        ZX
        db #40, #77, #1b, #0,           5               ;1800000        ~MSX
        db #70, #ec, #1b, #0,           6               ;1830000
        db #a0, #61, #1c, #0,           7               ;1860000
        db #c0, #af, #1c, #0,           8               ;1880000
        db #d0, #d6, #1c, #0,           9               ;1890000
        db #e0, #fd, #1c, #0,           10              ;1900000
        db #f0, #24, #1d, #0,           11              ;1910000
        db #00, #4c, #1d, #0,           12              ;1920000
        db #00, #4c, #1d, #0,           13              ;1920000        ;No change
        db #10, #73, #1d, #0,           14              ;1930000
        db #10, #73, #1d, #0,           15              ;1930000        ;No change
        db #70, #5d, #1e, #0,           0               ;1990000        ;~ST
PLY_AKY_PSGFrequenciesToYMZFlag_End:

PLY_AKY_PSGFrequenciesToYMZFlag_Count: equ (PLY_AKY_PSGFrequenciesToYMZFlag_End - PLY_AKY_PSGFrequenciesToYMZFlag) / 5

;       Plays the music. It must have been initialized before.
;       The interruption MUST be disabled (DI), as the stack is heavily used.
PLY_AKY_Play:
        ld (PLY_AKY_Exit + 1),sp

;Linker.
;----------------------------------------
PLY_AKY_PatternFrameCounter: ld hl,1                ;How many frames left before reading the next Pattern.
        dec hl
        ld a,l
        or h
        jr z,PLY_AKY_PatternFrameCounter_Over
        ld (PLY_AKY_PatternFrameCounter + 1),hl
        ;The pattern is not over.
        jr PLY_AKY_Channel1_WaitBeforeNextRegisterBlock

PLY_AKY_PatternFrameCounter_Over:

;The pattern is over. Reads the next one.
PLY_AKY_PtLinker: ld sp,0                                   ;Points on the Pattern of the linker.
        pop hl                                          ;Gets the duration of the Pattern, or 0 if end of the song.
        ld a,l
        or h
        jr nz,PLY_AKY_LinkerNotEndSong
        ;End of the song. Where to loop?
        pop hl
        ;We directly point on the frame counter of the pattern to loop to.
        ld sp,hl
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
        pop hl
PLY_AKY_LinkerNotEndSong:
        ld (PLY_AKY_PatternFrameCounter + 1),hl

        ;First, reads the tracks of the "PSG1" (internal YM) using the middle tracks.
        pop hl
        ld (PLY_AKY_Channel4_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel5_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel6_PtTrack + 1),hl
        ;Reads the tracks of the "PSG2" (right).
        pop hl
        ld (PLY_AKY_Channel1_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel2_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel3_PtTrack + 1),hl
        ;Reads the tracks of the "PSG3" (left).
        pop hl
        ld (PLY_AKY_Channel7_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel8_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel9_PtTrack + 1),hl

        ld (PLY_AKY_PtLinker + 1),sp

        ;Resets the RegisterBlocks of the channel 2 and 3. The first one is skipped so there is no need to do so.
        ld a,1
        ld (PLY_AKY_Channel2_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel3_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel4_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel5_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel6_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel7_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel8_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel9_WaitBeforeNextRegisterBlock + 1),a
        jr PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Over



;----------------------------------------------------------------------------------------------
;PSG 1.
;----------------------------------------------------------------------------------------------

;Reading the Track - channel 1.
;----------------------------------------
PLY_AKY_Channel1_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel1_RegisterBlock_Process
PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Over:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel1_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration.
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel1_PtTrack + 1),sp
        ld (PLY_AKY_Channel1_PtRegisterBlock + 1),hl

        ;A is the duration of the block.
PLY_AKY_Channel1_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel1_WaitBeforeNextRegisterBlock + 1),a


;Reading the Track - channel 2.
;----------------------------------------
PLY_AKY_Channel2_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel2_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel2_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel2_PtTrack + 1),sp
        ld (PLY_AKY_Channel2_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel2_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel2_WaitBeforeNextRegisterBlock + 1),a


;Reading the Track - channel 3.
;----------------------------------------
PLY_AKY_Channel3_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel3_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel3_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel3_PtTrack + 1),sp
        ld (PLY_AKY_Channel3_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel3_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel3_WaitBeforeNextRegisterBlock + 1),a







;----------------------------------------------------------------------------------------------
;PSG 2.
;----------------------------------------------------------------------------------------------


;Reading the Track - channel 4.
;----------------------------------------
PLY_AKY_Channel4_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel4_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel4_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel4_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel4_PtTrack + 1),sp
        ld (PLY_AKY_Channel4_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel4_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel4_WaitBeforeNextRegisterBlock + 1),a




;Reading the Track - channel 5.
;----------------------------------------
PLY_AKY_Channel5_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel5_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel5_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel5_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel5_PtTrack + 1),sp
        ld (PLY_AKY_Channel5_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel5_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel5_WaitBeforeNextRegisterBlock + 1),a




;Reading the Track - channel 6.
;----------------------------------------
PLY_AKY_Channel6_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel6_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel6_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel6_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel6_PtTrack + 1),sp
        ld (PLY_AKY_Channel6_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel6_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel6_WaitBeforeNextRegisterBlock + 1),a






;----------------------------------------------------------------------------------------------
;PSG 3.
;----------------------------------------------------------------------------------------------



;Reading the Track - channel 7.
;----------------------------------------
PLY_AKY_Channel7_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel7_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel7_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel7_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel7_PtTrack + 1),sp
        ld (PLY_AKY_Channel7_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel7_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel7_WaitBeforeNextRegisterBlock + 1),a




;Reading the Track - channel 8.
;----------------------------------------
PLY_AKY_Channel8_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel8_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel8_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel8_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel8_PtTrack + 1),sp
        ld (PLY_AKY_Channel8_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel8_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel8_WaitBeforeNextRegisterBlock + 1),a




;Reading the Track - channel 9.
;----------------------------------------
PLY_AKY_Channel9_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr nz,PLY_AKY_Channel9_RegisterBlock_Process
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel9_RegisterBlockLineState_Opcode),a
PLY_AKY_Channel9_PtTrack: ld sp,0                   ;Points on the Track.
        dec sp                                  ;Only one byte is read. Compensate.
        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        pop hl                                  ;Reads the RegisterBlock address.

        ld (PLY_AKY_Channel9_PtTrack + 1),sp
        ld (PLY_AKY_Channel9_PtRegisterBlock + 1),hl
        ;A is the duration of the block.
PLY_AKY_Channel9_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ld (PLY_AKY_Channel9_WaitBeforeNextRegisterBlock + 1),a













;Reading the RegisterBlock.
;----------------------------------------
PLY_AKY_ReadRegisterBlocks:

;----------------------------------------------------------------------------------------------
;PSG 1.
;----------------------------------------------------------------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        ld b,%11100000

        ld sp,PLY_AKY_RetTable_ReadRegisterBlock
        ld ix,PLY_AKY_Channel1_Psg1Register_Base
        ld iy,PLY_AKY_Psg1HardwareRegisterArray

PLY_AKY_Channel1_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel1_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel1_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel1_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 2
;----------------------------------------

        ;Shifts the R7 for the next channels.
        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!

        ld ix,PLY_AKY_Channel2_Psg1Register_Base

PLY_AKY_Channel2_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel2_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel2_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel2_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 3
;----------------------------------------

        ;Shifts the R7 for the next channels.
        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.

        ld ix,PLY_AKY_Channel3_Psg1Register_Base

PLY_AKY_Channel3_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel3_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel3_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel3_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.

        ;Register 7 to A.
        ld a,b

; -----------------------------------------------------------------------------------
; PSG 1 access.
; -----------------------------------------------------------------------------------

;A = register 7.
        ld de,#c080
        ld b,#f6
        out (c),d       ;#f6c0
        exx
        ld hl,PLY_AKY_Psg1SoftwareRegisterArray
        ld e,#f6
        ld bc,#f401

;Register 0
        out (c),0       ;#f400+Register
        ld b,e
        out (c),0       ;#f600
        dec b
        outi            ;#f400+value
        exx
        out (c),e       ;#f680
        out (c),d       ;#f6c0
        exx

;Register 1
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 2
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 3
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 4
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 5
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c
        inc c                           ;R6 is encoded later.

;Register 7
        out (c),c
        ld b,e
        out (c),0
        dec b
        dec b
        out (c),a                       ;Read A register instead of the list.
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 8
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c
        inc hl                          ;Skip padding byte.

;Register 9
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c
        inc hl                          ;Skip padding byte.

;Register 10
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 11
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 12
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d
        exx
        inc c

;Register 13
PLY_AKY_PsgRegister13_Code
        ld a,(hl)
        inc hl                          ;Goes to the "retrig" value, just after R13.
        cp (hl)                         ;If IsRetrig?, force the R13 to be triggered.
        jr z,PLY_AKY_PsgRegister13_End
        ld (hl),a                       ;The "retrig" value becomes the R13, so that it is not played again, unless the R13 value is modified.

        out (c),c
        ld b,e
        out (c),0
        dec b
        dec b
        out (c),a
        exx
        out (c),e
        out (c),d
PLY_AKY_PsgRegister13_End:
        inc hl

;Register 6
        ld c,6
        out (c),c
        ld b,e
        out (c),0
        dec b
        outi
        exx
        out (c),e
        out (c),d



;----------------------------------------------------------------------------------------------
;PSG 2.
;----------------------------------------------------------------------------------------------

;Reading the RegisterBlock - Channel 4
;----------------------------------------

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        ld b,%11100000

        ld ix,PLY_AKY_Channel1_Psg2Register_Base
        ld iy,PLY_AKY_Psg2HardwareRegisterArray

PLY_AKY_Channel4_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel4_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel4_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel4_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel4_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 5
;----------------------------------------

        ;Shifts the R7 for the next channels.
        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!

        ld ix,PLY_AKY_Channel2_Psg2Register_Base

PLY_AKY_Channel5_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel5_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel5_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel5_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel5_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 6
;----------------------------------------

        ;Shifts the R7 for the next channels.
        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.

        ld ix,PLY_AKY_Channel3_Psg2Register_Base

PLY_AKY_Channel6_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel6_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel6_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel6_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel6_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.

        ;PSG 2 access.
        ;B is Register 7.
        ld hl,PLY_AKY_Psg2SoftwareRegisterArray
        ld c,PLY_AKY_PLAYCITY_SELECTWRITE_PORT_LSB_LEFT
        jp PLY_AKY_SendPlayCitySendRegisters                ;Uses the RET table to return.
PLY_AKY_ReturnPsg2SendRegisters:







;----------------------------------------------------------------------------------------------
;PSG 3.
;----------------------------------------------------------------------------------------------

;Reading the RegisterBlock - Channel 7.
;--------------------------------------

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        ld b,%11100000

        ld ix,PLY_AKY_Channel1_Psg3Register_Base
        ld iy,PLY_AKY_Psg3HardwareRegisterArray

PLY_AKY_Channel7_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel7_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel7_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel7_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel7_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 8.
;--------------------------------------

        ;Shifts the R7 for the next channels.
        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!

        ld ix,PLY_AKY_Channel2_Psg3Register_Base

PLY_AKY_Channel8_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel8_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel8_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel8_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel8_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 9.
;--------------------------------------

        ;Shifts the R7 for the next channels.
        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.

        ld ix,PLY_AKY_Channel3_Psg3Register_Base

PLY_AKY_Channel9_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel9_RegisterBlockLineState_Opcode: or a        ;0 if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel9_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel9_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel9_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.

        ;PSG 3 access.
        ;B is Register 7.
        ld hl,PLY_AKY_Psg3SoftwareRegisterArray
        ld c,PLY_AKY_PLAYCITY_SELECTWRITE_PORT_LSB_RIGHT
        jp PLY_AKY_SendPlayCitySendRegisters                ;Uses the RET table to return.
PLY_AKY_ReturnPsg3SendRegisters:


PLY_AKY_Exit: ld sp,0
        ret






;Sends the registers to the PlayCity.
;IN:    B = Register7 value.
;       HL = Register list, starting at register 0.
;       C = SELECT/WRITE LSB port of the PlayCity (#84 for right channels, #88 for left channels).
PLY_AKY_SendPlayCitySendRegisters:
        ld a,b

        ;Sends the register 7 first, to be able to use A later.
        ld de,7 * 256 + PLY_AKY_PLAYCITY_SELECT_PORT_MSB
        ld b,e
        out (c),d               ;#f984/88 to select a register (7 here).
        dec b
        out (c),a

        ;Register 0.
        xor a                   ;A = register. We could use out (c),0, but we would need to set a to 1 after. The code is cleared this way.
        ld b,e
        out (c),a               ;#f984/88 to select a register.
        outi                    ;#f884/88 to select a value. Thanks to OUTI, no need to decrease B!

        ;Register 1.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 2.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 3.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 4.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 5.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 8.
        ld a,8
        ld b,e
        out (c),a
        outi
        inc hl                          ;Skips padding byte.

        ;Register 9.
        inc a
        ld b,e
        out (c),a
        outi
        inc hl                          ;Skips padding byte.

        ;Register 10.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 11.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 12.
        inc a
        ld b,e
        out (c),a
        outi

        ;Register 13.
        inc a
        ld b,e
        out (c),a       ;Selects the register even if it won't be used. Simpler this way.

        ld a,(hl)
        inc hl
        cp (hl)                         ;If IsRetrig?, force the R13 to be triggered.
        jr z,PLY_AKY_PsgPlayCityRegister13_End
        ld (hl),a                       ;The R13 becomes the "retrig" value, so that it is not played again, unless Retrig value is modified.
        dec b
        out (c),a
PLY_AKY_PsgPlayCityRegister13_End:
        inc hl                          ;Go past the IsRetrig?.

        ;Register 6.
        ld a,6
        ld b,e
        out (c),a
        outi

        ret











;Generic code interpreting the RegisterBlock
;IN:    HL = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKY_ReadRegisterBlock:
        ;Gets the first byte of the line. What type? Jump to the matching code.
        ld a,(hl)
        inc hl
        jp c,PLY_AKY_RRB_NonInitialState
        ;Initial state.
        rra
        jr c,PLY_AKY_RRB_IS_SoftwareOnlyOrSoftwareAndHardware
        rra
        jr c,PLY_AKY_RRB_IS_HardwareOnly
        ;jr PLY_AKY_RRB_IS_NoSoftwareNoHardware

;Generic code interpreting the RegisterBlock - Initial state.
;----------------------------------------------------------------
;IN:    HL = Points after the first byte.
;       A = First byte, twice shifted to the right (type removed).
;       B = Register 7. All sounds are open (0) by default, all noises closed (1). The code must put ONLY bit 2 and 5 for sound and noise respectively. NOT any other bits!
;       C = May be used as a temp.
;       DE = free to use.
;       IX = Points on the software registers array.
;       IY = Points on the hardware registers array.

;       A' = free to use (not used).
;       DE' = f4f6
;       BC' = f680
;       L' = Volume register.
;       H' = LSB frequency register.

;OUT:   HL MUST points after the structure.
;       B = updated (ONLY bit 2 and 5).
;       L' = Volume register increased of 1 (*** IMPORTANT! The code MUST increase it, even if not using it! ***)
;       H' = LSB frequency register, increased of 2 (see above).
;       DE' = unmodified (f4f6)
;       BC' = unmodified (f680)

PLY_AKY_RRB_NoiseChannelBit: equ 5          ;Bit to modify to set/reset the noise channel.
PLY_AKY_RRB_SoundChannelBit: equ 2          ;Bit to modify to set/reset the sound channel.

PLY_AKY_RRB_IS_NoSoftwareNoHardware:
        ;No software no hardware.
        rra                     ;Noise?
        jr nc,PLY_AKY_RRB_NIS_NoSoftwareNoHardware_ReadVolume
        ;There is a noise. Reads it.
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),c

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_NIS_NoSoftwareNoHardware_ReadVolume:
        ;The volume is now in b0-b3.
        ;and %1111      ;No need, the bit 7 is 0.
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),a

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b
        ret


;---------------------
PLY_AKY_RRB_IS_HardwareOnly:
        ;Retrig?
        rra
        jr nc,PLY_AKY_RRB_IS_HO_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (iy + PLY_AKY_PsgRegister_OffsetRetrig),a
PLY_AKY_RRB_IS_HO_NoRetrig:

        ;Noise?
        rra
        jr nc,PLY_AKY_RRB_IS_HO_NoNoise
        ;Reads the noise.
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),c

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_HO_NoNoise:

        ;The envelope.
        and %1111
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwareEnvelope),a

        ;Copies the hardware period.
        ld a,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodLSB),a
        ld a,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodMSB),a

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        ;Sends the hardware volume.
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),16
        ret


;---------------------
PLY_AKY_RRB_IS_SoftwareOnlyOrSoftwareAndHardware:
        ;Another decision to make about the sound type.
        rra
        jr c,PLY_AKY_RRB_IS_SoftwareAndHardware

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
        rra
        jr nc,PLY_AKY_RRB_IS_SoftwareOnly_NoNoise
        ;Noise. Reads it.
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),c

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_SoftwareOnly_NoNoise:
        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),a

        ;Reads the software period.
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodLSB),a
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodMSB),a
        ret





;---------------------
PLY_AKY_RRB_IS_SoftwareAndHardware:
        ;Retrig?
        rra
        jr nc,PLY_AKY_RRB_IS_SAH_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (iy + PLY_AKY_PsgRegister_OffsetRetrig),a
PLY_AKY_RRB_IS_SAH_NoRetrig:

        ;Noise?
        rra
        jr nc,PLY_AKY_RRB_IS_SAH_NoNoise
        ;Reads the noise.
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),c

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_SAH_NoNoise:

        ;The envelope.
        and %1111
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwareEnvelope),a

        ;Reads the software period.
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodLSB),a
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodMSB),a

        ;Sends the hardware volume.
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),16

        ;Copies the hardware period.
        ld a,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodLSB),a
        ld a,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodMSB),a
        ret








        ;Manages the loop. This code is put here so that no jump needs to be coded when its job is done.
PLY_AKY_RRB_NIS_NoSoftwareNoHardware_Loop
        ;Loops. Reads the next pointer to this RegisterBlock.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a

        ;Makes another iteration to read the new data.
        ;Since we KNOW it is not an initial state (because no jump goes to an initial state), we can directly go to the right branching.
        ;Reads the first byte.
        ld a,(hl)
        inc hl
        ;jr PLY_AKY_RRB_NonInitialState

;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKY_RRB_NonInitialState:
        rra
        jr c,PLY_AKY_RRB_NIS_SoftwareOnlyOrSoftwareAndHardware
        rra
        jp c,PLY_AKY_RRB_NIS_HardwareOnly

        ;No software, no hardware, OR loop.

        ld e,a
        and %11         ;Bit 3:loop?/volume bit 0, bit 2: volume?
        cp %10          ;If no volume, yet the volume is >0, it means loop.
        jr z,PLY_AKY_RRB_NIS_NoSoftwareNoHardware_Loop

        ;No loop: so "no software no hardware".

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        ;Volume? bit 2 - 2.
        ld a,e
        rra
        jr nc,PLY_AKY_RRB_NIS_NoVolume
        and %1111
        ;Sends the volume.
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),a
PLY_AKY_RRB_NIS_NoVolume:

        ;Noise? Was on bit 7, but there has been two shifts. We can't use A, it may have been modified by the volume AND.
        bit 7 - 2, e
        ret z
        ;Noise.
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),c
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
        ret







PLY_AKY_RRB_NIS_SoftwareOnlyOrSoftwareAndHardware:
        ;Another decision to make about the sound type.
        rra
        jp c,PLY_AKY_RRB_NIS_SoftwareAndHardware


;---------------------
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        ld e,a
        ;Gets the volume (already shifted).
        and %1111
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),a

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        bit 6 - 2, e
        jr z,PLY_AKY_RRB_NIS_SoftwareOnly_NoLSP
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodLSB),a
PLY_AKY_RRB_NIS_SoftwareOnly_NoLSP:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        bit 7 - 2, e
        ret z

        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        ld a,(hl)       ;Useless bits at the end, not a problem.
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodMSB),a

        rla     ;Carry is isNoise?
        ret nc

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b

        ;Is there a new noise value? If yes, gets the noise.
        rla
        ret nc
        ;Gets the noise.
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),c
        ret



;---------------------
PLY_AKY_RRB_NIS_HardwareOnly
        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rla
        ld e,a
        and %1110
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwareEnvelope),a

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        ;Hardware volume.
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),16

        ld a,e

        ;LSB for hardware period? Currently on b6.
        rla
        rla
        jr nc,PLY_AKY_RRB_NIS_HardwareOnly_NoLSB
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodLSB),c
PLY_AKY_RRB_NIS_HardwareOnly_NoLSB:

        ;MSB for hardware period?
        rla
        jr nc,PLY_AKY_RRB_NIS_HardwareOnly_NoMSB
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodMSB),c
PLY_AKY_RRB_NIS_HardwareOnly_NoMSB:

        ;Noise or retrig?
        rla
        jr c,PLY_AKY_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop          ;The retrig/noise code is shared.

        ret



;---------------------
PLY_AKY_RRB_NIS_SoftwareAndHardware:
        ;Hardware volume.
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterVolume),16

        ;LSB of hardware period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterLSBH
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodLSB),c
PLY_AKY_RRB_NIS_SAHH_AfterLSBH:
        ;MSB of hardware period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterMSBH
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodMSB),c
PLY_AKY_RRB_NIS_SAHH_AfterMSBH:

        ;LSB of software period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterLSBS
        ld c,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodLSB),c
PLY_AKY_RRB_NIS_SAHH_AfterLSBS:

        ;MSB of software period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterMSBS
        ld c,(hl)
        inc hl
        ld (ix + PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodMSB),c
PLY_AKY_RRB_NIS_SAHH_AfterMSBS:

        ;New hardware envelope?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterEnvelope
        ld c,(hl)
        inc hl
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterHardwareEnvelope),a
PLY_AKY_RRB_NIS_SAHH_AfterEnvelope:

        ;Retrig and/or noise?
        rra
        ret nc

        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKY_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop:
        ;Noise or retrig. Reads the next byte.
        ld a,(hl)
        inc hl

        ;Retrig?
        rra
        jr nc,PLY_AKY_RRB_NIS_S_NOR_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (iy + PLY_AKY_PsgRegister_OffsetRetrig),a
PLY_AKY_RRB_NIS_S_NOR_NoRetrig:

        ;Noise? If no, nothing more to do.
        rra
        ret nc
        ;Noise. Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
        ;Is there a new noise value? If yes, gets the noise.
        rra
        ret nc
        ;Sets the noise.
        ld (iy + PLY_AKY_PsgRegister_OffsetRegisterNoise),a
        ret


;The PSG registers. Note than the Register 7 (mixer) is not present, because it is passed inside a register.
PLY_AKY_Psg1SoftwareRegisterArray:
PLY_AKY_Psg1Register0:      db 0    ;Register 0.
PLY_AKY_Psg1Register1:      db 0    ;Register 1.
PLY_AKY_Psg1Register2:      db 0    ;Register 2.
PLY_AKY_Psg1Register3:      db 0    ;Register 3.
PLY_AKY_Psg1Register4:      db 0    ;Register 4.
PLY_AKY_Psg1Register5:      db 0    ;Register 5.
;No Reg6 (noise)!
;No Reg7 (mix)!
PLY_AKY_Psg1Register8:      db 0    ;Register 8.
        db 0                    ;A byte to skip, needed to allow index registers when filling the register with a generic code.
PLY_AKY_Psg1Register9:      db 0    ;Register 9.
        db 0                    ;A byte to skip, same as above.
PLY_AKY_Psg1Register10:     db 0    ;Register 10.
PLY_AKY_Psg1SoftwareRegisterArray_End:
;The hardware register array must be stuck to the software register array.
PLY_AKY_Psg1HardwareRegisterArray
PLY_AKY_Psg1Register11:     db 0    ;Register 11.
PLY_AKY_Psg1Register12:     db 0    ;Register 12.
PLY_AKY_Psg1Register13:     db 0    ;Register 13.
PLY_AKY_Psg1Retrig:         db 0    ;Retrig value, must be just after Register13.
PLY_AKY_Psg1Noise:          db 0    ;Noise.
PLY_AKY_Psg1HardwareRegisterArray_End:

PLY_AKY_Psg1SoftwareRegisterArray_Size: equ PLY_AKY_Psg1SoftwareRegisterArray_End - PLY_AKY_Psg1SoftwareRegisterArray
PLY_AKY_Psg1HardwareRegisterArray_Size: equ PLY_AKY_Psg1HardwareRegisterArray_End - PLY_AKY_Psg1HardwareRegisterArray



        ASSERT PLY_AKY_Psg1HardwareRegisterArray == PLY_AKY_Psg1SoftwareRegisterArray_End

;Offsets to reach the registers in a generic way with an offset, according to the channel.
PLY_AKY_PsgRegister_OffsetRegisterVolume: equ PLY_AKY_Psg1Register8 - PLY_AKY_Psg1SoftwareRegisterArray
PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodLSB: equ PLY_AKY_Psg1Register0 - PLY_AKY_Psg1SoftwareRegisterArray
PLY_AKY_PsgRegister_OffsetRegisterSoftwarePeriodMSB: equ PLY_AKY_Psg1Register1 - PLY_AKY_Psg1SoftwareRegisterArray

PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodLSB: equ PLY_AKY_Psg1Register11 - PLY_AKY_Psg1HardwareRegisterArray
PLY_AKY_PsgRegister_OffsetRegisterHardwarePeriodMSB: equ PLY_AKY_Psg1Register12 - PLY_AKY_Psg1HardwareRegisterArray
PLY_AKY_PsgRegister_OffsetRegisterHardwareEnvelope: equ PLY_AKY_Psg1Register13 - PLY_AKY_Psg1HardwareRegisterArray
PLY_AKY_PsgRegister_OffsetRetrig: equ PLY_AKY_Psg1Retrig - PLY_AKY_Psg1HardwareRegisterArray
PLY_AKY_PsgRegister_OffsetRegisterNoise: equ PLY_AKY_Psg1Noise - PLY_AKY_Psg1HardwareRegisterArray

;The registers array for PSG 2 and 3.
PLY_AKY_Psg2SoftwareRegisterArray:
        ds PLY_AKY_Psg1SoftwareRegisterArray_Size, 0
PLY_AKY_Psg2HardwareRegisterArray:
        ds PLY_AKY_Psg1HardwareRegisterArray_Size, 0

PLY_AKY_Psg3SoftwareRegisterArray:
        ds PLY_AKY_Psg1SoftwareRegisterArray_Size, 0
PLY_AKY_Psg3HardwareRegisterArray:
        ds PLY_AKY_Psg1HardwareRegisterArray_Size, 0



PLY_AKY_Channel1_Psg1Register_Base: equ PLY_AKY_Psg1SoftwareRegisterArray + 0
PLY_AKY_Channel2_Psg1Register_Base: equ PLY_AKY_Psg1SoftwareRegisterArray + 2
PLY_AKY_Channel3_Psg1Register_Base: equ PLY_AKY_Psg1SoftwareRegisterArray + 4

PLY_AKY_Channel1_Psg2Register_Base: equ PLY_AKY_Psg2SoftwareRegisterArray + 0
PLY_AKY_Channel2_Psg2Register_Base: equ PLY_AKY_Psg2SoftwareRegisterArray + 2
PLY_AKY_Channel3_Psg2Register_Base: equ PLY_AKY_Psg2SoftwareRegisterArray + 4

PLY_AKY_Channel1_Psg3Register_Base: equ PLY_AKY_Psg3SoftwareRegisterArray + 0
PLY_AKY_Channel2_Psg3Register_Base: equ PLY_AKY_Psg3SoftwareRegisterArray + 2
PLY_AKY_Channel3_Psg3Register_Base: equ PLY_AKY_Psg3SoftwareRegisterArray + 4


;RET table for the Read RegisterBlock/SendPlayCitySendRegisters codes to know where to return.
PLY_AKY_RetTable_ReadRegisterBlock:
        dw PLY_AKY_Channel1_RegisterBlock_Return
        dw PLY_AKY_Channel2_RegisterBlock_Return
        dw PLY_AKY_Channel3_RegisterBlock_Return
        dw PLY_AKY_Channel4_RegisterBlock_Return
        dw PLY_AKY_Channel5_RegisterBlock_Return
        dw PLY_AKY_Channel6_RegisterBlock_Return
        dw PLY_AKY_ReturnPsg2SendRegisters
        dw PLY_AKY_Channel7_RegisterBlock_Return
        dw PLY_AKY_Channel8_RegisterBlock_Return
        dw PLY_AKY_Channel9_RegisterBlock_Return
        dw PLY_AKY_ReturnPsg3SendRegisters
