;       AKY music player - V1.0.
;       By Julien Névo a.k.a. Targhan/Arkos.
;       December 2016.

;       PSG sending optimization trick by Madram/Overlanders.

;       The player uses the stack for optimizations. Make sure the interruptions are disabled before it is called.
;       The stack pointer is saved at the beginning and restored at the end.

;       Possible optimizations:
;       SIZE: The JP hooks at the beginning can be removed if you include this code in yours directly.
;       SIZE: If you don't play a song twice, all the code in PLY_AKY_Init can be removed, except the first lines that skip the header.
;       SIZE: The header is only needed for players that want to load any song. Most of the time, you don't need it. Erase both the init code and the header bytes in the song.
;       CPU:  Retrigs are quite seldomly used. If you don't use them, you can remove all the tests (keep the bit shifts though!). Will save a dozen cycles per frame.
;       CPU:  We *could* save 3 NOPS by removing the first "jp PLY_AKY_ReadRegisterBlock" and stucking the whole code instead. But it would make the whole really ugly.

PLY_AKY_OPCODE_OR_A: equ #b7                        ;Opcode for "or a".
PLY_AKY_OPCODE_SCF: equ #37                         ;Opcode for "scf".

PLY_AKY_Start:
        ;Hooks for external calls. Can be removed if not needed.
        jp PLY_AKY_Init             ;Player + 0.
        jp PLY_AKY_Play             ;Player + 3.


;       Initializes the player.
;       HL = music address.
PLY_AKY_Init:
        ;Skips the header.
        inc hl                          ;Skips the format version.
        ld a,(hl)                       ;Channel count.
        inc hl
        ld de,4
PLY_AKY_Init_SkipHeaderLoop:                ;There is always at least one PSG to skip.
        add hl,de
        sub 3                           ;A PSG is three channels.
        jr z,PLY_AKY_Init_SkipHeaderEnd
        jr nc,PLY_AKY_Init_SkipHeaderLoop   ;Security in case of the PSG channel is not a multiple of 3.
PLY_AKY_Init_SkipHeaderEnd:
        ld (PLY_AKY_PtLinker + 1),hl        ;HL now points on the Linker.

        ld a,PLY_AKY_OPCODE_OR_A
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
        ld hl,1
        ld (PLY_AKY_PatternFrameCounter + 1),hl

        ret

;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
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

        pop hl
        ld (PLY_AKY_Channel1_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel2_PtTrack + 1),hl
        pop hl
        ld (PLY_AKY_Channel3_PtTrack + 1),hl

        ld (PLY_AKY_PtLinker + 1),sp

        ;Resets the RegisterBlocks of the channel 2 and 3. The first one is skipped so there is no need to do so.
        ld a,1
        ld (PLY_AKY_Channel2_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKY_Channel3_WaitBeforeNextRegisterBlock + 1),a
        jr PLY_AKY_Channel1_WaitBeforeNextRegisterBlock_Over

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













;Reading the RegisterBlock.
;----------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------
        ;Auxiliary registers are for the PSG access.
                ld hl,0 * 256 + 8                       ;H = first frequency register, L = first volume register.
                ld de,#f4f6
                ld bc,#f690                             ;#90 used for both #80 for the PSG, and volume 16!

                ld a,#c0                                ;Used for PSG.
                out (c),a                               ;f6c0. Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
        ex af,af'
        exx

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        ld bc,%11100000 * 256 + 255                     ;C is 255 to prevent the following LDIs to decrease B.

        ld sp,PLY_AKY_RetTable_ReadRegisterBlock

PLY_AKY_Channel1_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel1_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel1_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel1_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 2
;----------------------------------------

        ;Shifts the R7 for the next channels.
        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!

PLY_AKY_Channel2_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel2_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel2_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel2_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 3
;----------------------------------------

        ;Shifts the R7 for the next channels.
        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.

PLY_AKY_Channel3_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKY_Channel3_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
        jp PLY_AKY_ReadRegisterBlock
PLY_AKY_Channel3_RegisterBlock_Return:
        ld a,PLY_AKY_OPCODE_SCF
        ld (PLY_AKY_Channel3_RegisterBlockLineState_Opcode),a
        ld (PLY_AKY_Channel3_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.

        ;Register 7 to A.
        ld a,b

;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).

;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).
        exx

                inc h           ;Was 6, so now 7!

                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

;Register 6
                dec h

                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.

                ld hl,PLY_AKY_PsgRegister6
                dec b           ; -1, not -2 because of OUTI does -1 before doing the out.
                outi            ;f400 + value
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'


;Register 11
                ld a,11         ;Next regiser

                ld b,d
                out (c),a       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                dec b
                outi            ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'


;Register 12
                inc a           ;Next regiser

                ld b,d
                out (c),a       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                dec b
                outi            ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'




;Register 13
PLY_AKY_PsgRegister13_Code
                ld a,(hl)
PLY_AKY_PsgRegister13_Retrig cp 255                         ;If IsRetrig?, force the R13 to be triggered.
                jr z,PLY_AKY_PsgRegister13_End
                ld (PLY_AKY_PsgRegister13_Retrig + 1),a

                ld b,d
                ld l,13
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'
PLY_AKY_PsgRegister13_End:



PLY_AKY_Exit: ld sp,0
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
;       C = May be used as a temp. BUT must NOT be 0, as ldi will decrease it, we do NOT want B to be decreased!!
;       DE = free to use.
;       IX = free to use (not used!).
;       IY = free to use (not used!).

;       A' = free to use (not used).
;       DE' = f4f6
;       BC' = f680
;       L' = Volume register.
;       H' = LSB frequency register.

;OUT:   HL MUST point after the structure.
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
        ld de,PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_NIS_NoSoftwareNoHardware_ReadVolume:
        ;The volume is now in b0-b3.
        ;and %1111      ;No need, the bit 7 was 0.

        exx
                ;Sends the volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.
                inc h           ;Increases the frequency register.
                inc h
        exx

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b
        ret


;---------------------
PLY_AKY_RRB_IS_HardwareOnly:
        ;Retrig?
        rra
        jr nc,PLY_AKY_RRB_IS_HO_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKY_PsgRegister13_Retrig + 1),a
PLY_AKY_RRB_IS_HO_NoRetrig:

        ;Noise?
        rra
        jr nc,PLY_AKY_RRB_IS_HO_NoNoise
        ;Reads the noise.
        ld de,PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_HO_NoNoise:

        ;The envelope.
        and %1111
        ld (PLY_AKY_PsgRegister13),a

        ;Copies the hardware period.
        ld de,PLY_AKY_PsgRegister11
        ldi
        ldi

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        exx
                ;Sets the hardware volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),c       ;f400 + value (volume to 16).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.
                inc h           ;Increases the frequency register (mandatory!).
                inc h
        exx
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
        ld de,PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_SoftwareOnly_NoNoise:
        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
        exx
                ;Sends the volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.
        exx

        ;Reads the software period.
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc h           ;Increases the frequency register.
        exx

        ld a,(hl)
        inc hl
        exx
                ;Sends the MSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc h           ;Increases the frequency register.
        exx

        ret





;---------------------
PLY_AKY_RRB_IS_SoftwareAndHardware:
        ;Retrig?
        rra
        jr nc,PLY_AKY_RRB_IS_SAH_NoRetrig
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKY_PsgRegister13_Retrig + 1),a
PLY_AKY_RRB_IS_SAH_NoRetrig:

        ;Noise?
        rra
        jr nc,PLY_AKY_RRB_IS_SAH_NoNoise
        ;Reads the noise.
        ld de,PLY_AKY_PsgRegister6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b
PLY_AKY_RRB_IS_SAH_NoNoise:

        ;The envelope.
        and %1111
        ld (PLY_AKY_PsgRegister13),a

        ;Reads the software period.
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc h           ;Increases the frequency register.
        exx

        ld a,(hl)
        inc hl
        exx
                ;Sends the MSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc h           ;Increases the frequency register.

                ;Sets the hardware volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),c       ;f400 + value (volume to 16).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.
        exx

        ;Copies the hardware period.
        ld de,PLY_AKY_PsgRegister11
        ldi
        ldi
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
        exx
                ;Sends the volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

        exx
PLY_AKY_RRB_NIS_NoVolume:
        ;Sadly, have to lose a bit of CPU here, as this must be done in all cases.
        exx
                inc l           ;Next volume register.
                inc h           ;Next frequency registers.
                inc h
        exx

        ;Noise? Was on bit 7, but there has been two shifts. We can't use A, it may have been modified by the volume AND.
        bit 7 - 2, e
        ret z
        ;Noise.
        ld a,(hl)
        ld (PLY_AKY_PsgRegister6),a
        inc hl
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
        exx
                ;Sends the volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.
        exx

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        bit 6 - 2, e
        jr z,PLY_AKY_RRB_NIS_SoftwareOnly_NoLSP
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                ;H not incremented on purpose.
        exx
PLY_AKY_RRB_NIS_SoftwareOnly_NoLSP:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        bit 7 - 2, e
        jr nz,PLY_AKY_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
        ;Bit of loss of CPU, but has to be done in all cases.
        exx
                inc h
                inc h
        exx
        ret
PLY_AKY_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise:
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        ld a,(hl)       ;Useless bits at the end, not a problem.
        inc hl
        exx
                ;Sends the MSB software frequency.
                inc h           ;Was not increased before.

                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc h           ;Increases the frequency register.
        exx

        rla     ;Carry is isNoise?
        ret nc

        ;Opens the noise channel.
        res PLY_AKY_RRB_NoiseChannelBit, b

        ;Is there a new noise value? If yes, gets the noise.
        rla
        ret nc
        ;Gets the noise.
        ld de,PLY_AKY_PsgRegister6
        ldi
        ret



;---------------------
PLY_AKY_RRB_NIS_HardwareOnly
        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rla
        ld e,a
        and %1110
        ld (PLY_AKY_PsgRegister13),a

        ;Closes the sound channel.
        set PLY_AKY_RRB_SoundChannelBit, b

        ;Hardware volume.
        exx
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),c       ;f400 + value (16, hardware volume).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.

                inc h           ;Increases the frequency register.
                inc h
        exx

        ld a,e

        ;LSB for hardware period? Currently on b6.
        rla
        rla
        jr nc,PLY_AKY_RRB_NIS_HardwareOnly_NoLSB
        ld de,PLY_AKY_PsgRegister11
        ldi
PLY_AKY_RRB_NIS_HardwareOnly_NoLSB:

        ;MSB for hardware period?
        rla
        jr nc,PLY_AKY_RRB_NIS_HardwareOnly_NoMSB
        ld de,PLY_AKY_PsgRegister12
        ldi
PLY_AKY_RRB_NIS_HardwareOnly_NoMSB:

        ;Noise or retrig?
        rla
        jr c,PLY_AKY_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop          ;The retrig/noise code is shared.

        ret



;---------------------
PLY_AKY_RRB_NIS_SoftwareAndHardware:
        ;Hardware volume.
        exx
                ;Sends the volume.
                ld b,d
                out (c),l       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),c       ;f400 + value (16 = hardware volume).
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                inc l           ;Increases the volume register.
        exx

        ;LSB of hardware period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterLSBH
        ld de,PLY_AKY_PsgRegister11
        ldi
PLY_AKY_RRB_NIS_SAHH_AfterLSBH:
        ;MSB of hardware period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterMSBH
        ld de,PLY_AKY_PsgRegister12
        ldi
PLY_AKY_RRB_NIS_SAHH_AfterMSBH:

        ;LSB of software period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterLSBS
        ld e,a
        ld a,(hl)
        inc hl
        exx
                ;Sends the LSB software frequency.
                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                ;H not increased on purpose.
        exx
        ld a,e
PLY_AKY_RRB_NIS_SAHH_AfterLSBS:

        ;MSB of software period?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterMSBS
        ld e,a
        ld a,(hl)
        inc hl
        exx
                ;Sends the MSB software frequency.
                inc h

                ld b,d
                out (c),h       ;f400 + register.
                ld b,e
                out (c),0       ;f600.
                ld b,d
                out (c),a       ;f400 + value.
                ld b,e
                out (c),c       ;f680
                ex af,af'
                out (c),a       ;f6c0.
                ex af,af'

                dec h           ;Yup. Will be compensated below.
        exx
        ld a,e
PLY_AKY_RRB_NIS_SAHH_AfterMSBS:
        ;A bit of loss of CPU, but this has to be done every time!
        exx
                inc h
                inc h
        exx

        ;New hardware envelope?
        rra
        jr nc,PLY_AKY_RRB_NIS_SAHH_AfterEnvelope
        ld de,PLY_AKY_PsgRegister13
        ldi
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
        ld (PLY_AKY_PsgRegister13_Retrig + 1),a
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
        ld (PLY_AKY_PsgRegister6),a
        ret


;Some stored PSG registers.
PLY_AKY_PsgRegister6: db 0
PLY_AKY_PsgRegister11: db 0
PLY_AKY_PsgRegister12: db 0
PLY_AKY_PsgRegister13: db 0


;RET table for the Read RegisterBlock code to know where to return.
PLY_AKY_RetTable_ReadRegisterBlock :
        dw PLY_AKY_Channel1_RegisterBlock_Return
        dw PLY_AKY_Channel2_RegisterBlock_Return
        dw PLY_AKY_Channel3_RegisterBlock_Return