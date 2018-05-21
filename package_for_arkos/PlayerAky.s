;
; AKY music player
;
; Port by George Nakos (GGN of pick-your-favorite-group - KUA software productions/D-Bug/Paradize/Reboot/Bello games)
; (yes, crews are becoming pointless :))
;
; Based on the soruces of "Stabilized AKY music player - V1.0."
;       By Julien Névo a.k.a. Targhan/Arkos.
;       February 2018.
;
; This source was written for the rmac assembler (http://virtualjaguar.kicks-ass.net/builds/)
; It should be fairly easy to adapt to other assemblers.
;
; Note that the source makes use of macros, so take a look at their definitions (after these messages end) before reading the code


PLY_AKYst_RRB_NoiseChannelBit equ 5                             ;Bit to modify to set/reset the noise channel.
PLY_AKYst_RRB_SoundChannelBit equ 2                             ;Bit to modify to set/reset the sound channel.


PLY_AKYst_OPCODE_SZF equ $7200                                  ;Opcode for "moveq #0,d0".
PLY_AKYst_OPCODE_CZF  equ $72ff                                 ;Opcode for "moveq #-1,d0".

PLY_AKYst_Start:
        ;Hooks for external calls. Can be removed if not needed.
        bra.s PLY_AKYst_Init                                    ;Player + 0.
        bra.s PLY_AKYst_Play                                    ;Player + 2.
    


;       Initializes the player.
;       a0.l=music address
PLY_AKYst_Init:

        ;Skips the header.
        addq.l #1,a0                                            ;Skips the format version.
        move.b (a0)+,d1                                         ;Channel count.
PLY_AKYst_Init_SkipHeaderLoop:                                  ;There is always at least one PSG to skip.
        addq.l #4,a0
        subq.b #3,d1                                            ;A PSG is three channels.
        beq.s PLY_AKYst_Init_SkipHeaderEnd
        bcc.s PLY_AKYst_Init_SkipHeaderLoop                     ;Security in case of the PSG channel is not a multiple of 3.
PLY_AKYst_Init_SkipHeaderEnd:
        move.l a0,PLY_AKYst_PtLinker                           ;a0 now points on the Linker.

        move.w #PLY_AKYst_OPCODE_SZF,d0
        move.w d0,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        move.w d0,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        move.w d0,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        move.w #1,PLY_AKYst_PatternFrameCounter

        rts

;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
;       a0.l=start of tune

PLY_AKYst_Play:

        lea $ffff8800.w,a2                                      ;cache YM registers
        lea $ffff8802.w,a3


;Linker.
;----------------------------------------
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PatternFrameCounter equ * + 2
        move.w #1,d1                                            ;How many frames left before reading the next Pattern.
        subq.w #1,d1

        beq.s PLY_AKYst_PatternFrameCounter_Over
        move.w d1,PLY_AKYst_PatternFrameCounter
        bra.s PLY_AKYst_PatternFrameManagement_End

PLY_AKYst_PatternFrameCounter_Over:

;The pattern is over. Reads the next one.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PtLinker = * + 2
        lea 0.l,a6                                              ;Points on the Pattern of the linker.
        move.w (a6)+,d1                                         ;Gets the duration of the Pattern, or 0 if end of the song.
        bne.s PLY_AKYst_LinkerNotEndSong
        ;End of the song. Where to loop?
        move.w (a6)+,d1
        ;We directly point on the frame counter of the pattern to loop to.
        lea (a0,d1.w),a6
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
        move.w (a6)+,d1
PLY_AKYst_LinkerNotEndSong:
        move.w d1,PLY_AKYst_PatternFrameCounter

        move.w (a6)+,PLY_AKYst_Channel1_PtTrack
        move.w (a6)+,PLY_AKYst_Channel2_PtTrack
        move.w (a6)+,PLY_AKYst_Channel3_PtTrack
        move.l a6,PLY_AKYst_PtLinker

        ;Resets the RegisterBlocks of the channels.
        moveq #1,d1
        move.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock
        move.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock
        move.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock
PLY_AKYst_PatternFrameManagement_End:

;Reading the Track - channel 1.
;----------------------------------------
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1                                            ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1
        beq.s PLY_AKYst_Channel1_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel1_RegisterBlock_Process
PLY_AKYst_Channel1_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtTrack = * + 2
        lea 0(a0),a6                                            ;Points on the Track.
        move.b (a6),d1                                          ;Gets the duration.
        move.w 2(a6),a1                                         ;Reads the RegisterBlock address.
        lea (a0,a1.w),a1
        move.l a1,PLY_AKYst_Channel1_PtRegisterBlock
        addq.w #4,a6

        sub.l a0,a6                                             ;TODO can we do without this?

        move.w a6,PLY_AKYst_Channel1_PtTrack
        ;d1 is the duration of the block.
PLY_AKYst_Channel1_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        move.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock



;Reading the Track - channel 2.
;----------------------------------------
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1       
        beq.s PLY_AKYst_Channel2_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel2_RegisterBlock_Process
PLY_AKYst_Channel2_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_PtTrack = * + 2
        lea 0(a0),a6                                            ;Points on the Track.
        move.b (a6),d1                                          ;Gets the duration (b1-7). b0 = silence block?
        move.w 2(a6),a1
        lea (a0,a1.w),a1
        move.l a1,PLY_AKYst_Channel2_PtRegisterBlock
        addq.w #4,a6

        sub.l a0,a6                                             ;TODO can we do without this?

        move.w a6,PLY_AKYst_Channel2_PtTrack
        ;d1 is the duration of the block.
PLY_AKYst_Channel2_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        move.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock




;Reading the Track - channel 3.
;----------------------------------------
;PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock: ld a,1         ;Frames to wait before reading the next RegisterBlock. 0 = finished.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1
        beq.s PLY_AKYst_Channel3_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel3_RegisterBlock_Process
PLY_AKYst_Channel3_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtTrack equ * + 2
        lea 0(a0),a6                                            ;Points on the Track.

        move.b (a6),d1                                          ;Gets the duration (b1-7). b0 = silence block?
        move.w 2(a6),a1
        lea (a0,a1.w),a1
        move.l a1,PLY_AKYst_Channel3_PtRegisterBlock
        addq.w #4,a6

        sub.l a0,a6                                             ;TODO can we do without this?

        move.w a6,PLY_AKYst_Channel3_PtTrack
PLY_AKYst_Channel3_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        move.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock











;Reading the RegisterBlock.
;----------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------

        move.w #((0 * 256) + 8),d7                              ;d7 high byte = first frequency register, d7 low byte = first volume register.
        move.w #$f690,d4                                        ;$90 used for both $80 for the PSG, and volume 16!
        
        ;In d3, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        move.w #%11100000,d3


* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtRegisterBlock = * + 2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel1_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel1_PtRegisterBlock           ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 2
;----------------------------------------

        ;Shifts the R7 for the next channels.
        lsr.b #1,d3
        

* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_PtRegisterBlock equ * + 2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel2_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel2_PtRegisterBlock           ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 3
;----------------------------------------

        ;Shifts the R7 for the next channels.
        lsr.b #1,d3

* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtRegisterBlock equ * + 2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel3_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel3_PtRegisterBlock           ;This is new pointer on the RegisterBlock.

        ;Register 7 to d1.
        move.w d3,d1

;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).

;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).

        move.b #7,(a2)
        move.b d1,(a3)

;Register 6
        move.b #6,(a2)
        move.b PLY_AKYst_PsgRegister6(pc),(a3)

;Register 11
        move.b #11,(a2)
        move.b PLY_AKYst_PsgRegister11(pc),(a3)

;Register 12
        move.b #12,(a2)
        move.b PLY_AKYst_PsgRegister12(pc),(a3)


;Register 13
PLY_AKYst_PsgRegister13_Code:
        move.b PLY_AKYst_PsgRegister13(pc),d1
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PsgRegister13_Retrig equ * + 3
        cmp.b #255,d1                                           ;If IsRetrig?, force the R13 to be triggered.
        bne.s PLY_AKYst_PsgRegister13_Change
        bra.s PLY_AKYst_PsgRegister13_End
PLY_AKYst_PsgRegister13_Change:
        move.b d1,PLY_AKYst_PsgRegister13_Retrig

        move.b #13,(a2)
        move.b d1,(a3)

PLY_AKYst_PsgRegister13_End:



PLY_AKYst_Exit:
        rts





;Generic code interpreting the RegisterBlock
;IN:    a1 = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYst_ReadRegisterBlock:
        ;Gets the first byte of the line. What type? Jump to the matching code thanks to the zero flag.
PLY_AKYst_RRB_BranchOnNonInitailState:
        bne PLY_AKYst_RRB_NonInitialState

        ; Code from the bcs and above copied here so nothing will screw with the zero flag
        move.b (a1)+,d1
        
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTable(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTable(pc,a5.w)
PLY_AKYst_IS_JPTable:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardware-PLY_AKYst_IS_JPTable
        dc.w PLY_AKYst_RRB_IS_SoftwareOnly        -PLY_AKYst_IS_JPTable
        dc.w PLY_AKYst_RRB_IS_HardwareOnly        -PLY_AKYst_IS_JPTable
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardware -PLY_AKYst_IS_JPTable

;Generic code interpreting the RegisterBlock - Initial state.
;----------------------------------------------------------------
;IN:    a1 = Points after the first byte.
;       A = First byte, twice shifted to the right (type removed).
;       d3 = Register 7. All sounds are open (0) by default, all noises closed (1). The code must put ONLY bit 2 and 5 for sound and noise respectively. NOT any other bits!
;       A' = free to use (not used).
;       d4 = f680
;       d7 (low byte) = Volume register.
;       d7 (high byte) = LSB frequency register.

;OUT:   a1 MUST point after the structure.
;       d3 = updated (ONLY bit 2 and 5).
;       d7 (low byte) = Volume register increased of 1 (*** IMPORTANT! The code MUST increase it, even if not using it! ***)
;       d7 (high byte) = LSB frequency register, increased of 2 (see above).


PLY_AKYst_RRB_IS_NoSoftwareNoHardware:

        ;No software no hardware.
        lsr.b #1,d1             ;Noise?
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise:
        ;There is a noise. Reads it.
        move.b (a1)+,PLY_AKYst_PsgRegister6

        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End:
        
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolume:
        ;The volume is now in b0-b3.

        move.b d7,(a2)
        move.b d1,(a3)

        add.w #(2<<8)+1,d7                                      ;Increases the volume register (low byte) and frequency register (high byte).
        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        rts


;---------------------
PLY_AKYst_RRB_IS_HardwareOnly:

        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Retrig
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrig
PLY_AKYst_RRB_IS_HO_Retrig:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet A can still be use.
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrig:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Noise 
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoise
PLY_AKYst_RRB_IS_HO_Noise:                                      ;Reads the noise.
        move.b (a1)+,PLY_AKYst_PsgRegister6
 
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoise:
        ;The envelope.
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13

        ;Copies the hardware period.
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+1

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        move.b d7,(a2)
        move.b d4,(a3)                                     ;(volume to 16).

        add.w #$201,d7                                          ;Increases the volume register (low byte), and frequency register (high byte - mandatory!).
        rts

;---------------------
PLY_AKYst_RRB_IS_SoftwareOnly:

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_Noise
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise
PLY_AKYst_RRB_IS_SoftwareOnly_Noise:
        ;Noise. Reads it.
        move.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise:

        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
        move.b d7,(a2)
        move.b d1,(a3)

        addq.w #1,d7                                            ;Increases the volume register.

        ;Reads the software period.
        move.w d7,(a2)
        move.b (a1)+,(a3)

        add.w #1<<8,d7                                          ;Increases the frequency register.

        move.w d7,(a2)
        move.b (a1)+,(a3)

        add.w #1<<8,d7                                          ;Increases the frequency register.

        rts




;---------------------
PLY_AKYst_RRB_IS_SoftwareAndHardware:
        
        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Retrig
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrig
PLY_AKYst_RRB_IS_SAH_Retrig:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet d1 can still be use.
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrig:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Noise
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoise
PLY_AKYst_RRB_IS_SAH_Noise:
        ;Reads the noise.
        move.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoise:

        ;The envelope.
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13

        ;Reads the software period.
        move.w d7,(a2)
        move.b (a1)+,(a3)
       
        add.w #1<<8,d7                                          ;Increases the frequency register.

        move.w d7,(a2)
        move.b (a1)+,(a3)

        add.w #1<<8,d7                                          ;Increases the frequency register.

        move.b d7,(a2)
        move.b d4,(a3)                                     ;(volume to 16).

        addq.w #1,d7                                            ;Increases the volume register.

        ;Copies the hardware period.
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+1
        rts





;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKYst_RRB_NonInitialState:

        ; Code from the start of PLY_AKYst_ReadRegisterBlock copied here so nothing will screw with the zero flag        
        move.b (a1)+,d1

        move.b d1,d2
        and.b #%00001111,d2                                      ;Keeps 4 bits to be able to detect the loop. (%1000)
        add.b d2,d2

        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTable(pc),a5
        add.w PLY_AKYst_NIS_JPTable(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTable:

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware-PLY_AKYst_NIS_JPTable          ;%0000
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly        -PLY_AKYst_NIS_JPTable          ;%0001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly        -PLY_AKYst_NIS_JPTable          ;%0010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware -PLY_AKYst_NIS_JPTable          ;%0011

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware-PLY_AKYst_NIS_JPTable          ;%0100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly        -PLY_AKYst_NIS_JPTable          ;%0101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly        -PLY_AKYst_NIS_JPTable          ;%0110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware -PLY_AKYst_NIS_JPTable          ;%0111
        
        dc.w PLY_AKYst_RRB_NIS_ManageLoop          -PLY_AKYst_NIS_JPTable          ;%1000. Loop!
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly        -PLY_AKYst_NIS_JPTable          ;%1001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly        -PLY_AKYst_NIS_JPTable          ;%1010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware -PLY_AKYst_NIS_JPTable          ;%1011
        
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware-PLY_AKYst_NIS_JPTable          ;%1100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly        -PLY_AKYst_NIS_JPTable          ;%1101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly        -PLY_AKYst_NIS_JPTable          ;%1110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware -PLY_AKYst_NIS_JPTable          ;%1111
        

PLY_AKYst_RRB_NIS_ManageLoop:
        ;Loops. Reads the next pointer to this RegisterBlock.
;Check if address is odd, and make it even if so
;Auto-even address. Not the best thing we could do performance wise but it'll do for now
        move.l a1,d1
        addq.l #1,d1
        bclr #0,d1
        move.l d1,a1
        move.w (a1),a1
        lea (a0,a1.w),a1

        ;Makes another iteration to read the new data.
        ;Since we KNOW it is not an initial state (because no jump goes to an initial state), we can directly go to the right branching.
        ;Reads the first byte.
        move.b (a1)+,d1
        
        ;Reads the next NIS state. We know there won't be any loop.
        move.b d1,d2                                            ;d1 must be saved!
        and.b #%00000011,d2
        add.b d2,d2

        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTable_NoLoop(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoop(pc,a5.w)




        ;This table jumps at each state, but AFTER the loop compensation.
PLY_AKYst_NIS_JPTable_NoLoop:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop-PLY_AKYst_NIS_JPTable_NoLoop     ;%00
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_Loop        -PLY_AKYst_NIS_JPTable_NoLoop     ;%01
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_Loop        -PLY_AKYst_NIS_JPTable_NoLoop     ;%10
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop -PLY_AKYst_NIS_JPTable_NoLoop     ;%11
        
        


PLY_AKYst_RRB_NIS_NoSoftwareNoHardware:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop:
        ;No software, no hardware.
        ;NO NEED to test the loop! It has been tested before. We can optimize from the original code.
        move.b d1,d2                                            ;Used below.

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        ;Volume? bit 2 - 2.
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Volume
        bra.s PLY_AKYst_RRB_NIS_AfterVolume
PLY_AKYst_RRB_NIS_Volume:
        and.b #%1111,d1
        move.b d7,(a2)
        move.b d1,(a3)

PLY_AKYst_RRB_NIS_AfterVolume:

        add.w #$201,d7                                          ;Next volume register (low byte) and frequency registers (high byte)

        ;Noise? Was on bit 7, but there has been two shifts. We can't use d1, it may have been modified by the volume AND.
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_Noise
        rts
PLY_AKYst_RRB_NIS_Noise:
        ;Noise.
        move.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        rts






;---------------------
PLY_AKYst_RRB_NIS_SoftwareOnly:
PLY_AKYst_RRB_NIS_SoftwareOnly_Loop:
        
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        move.b d1,d2
        ;Gets the volume (already shifted).
        and.b #%1111,d1
        move.b d7,(a2)
        move.b d1,(a3)

        addq.w #1,d7                                            ;Increases the volume register.

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSP
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP
PLY_AKYst_RRB_NIS_SoftwareOnly_LSP:
        move.w d7,(a2)
        move.b (a1)+,(a3)
                                                                ;d7 high byte not incremented on purpose.
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
        add.w #2<<8,d7
        rts
        
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise:
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        move.b (a1)+,d1                                         ;Useless bits at the end, not a problem.
                                                                ;Sends the MSB software frequency.
        add.w #1<<8,d7                                          ;Was not increased before.

        move.w d7,(a2)
        move.b d1,(a3)

        add.w #1<<8,d7                                          ;Increases the frequency register.
        
        rol.b #1,d1                                             ;Carry is isNoise?
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent:
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
       
        ;Is there a new noise value? If yes, gets the noise.
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_Noise
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_Noise:
        ;Gets the noise.
        move.b (a1)+,PLY_AKYst_PsgRegister6
        rts


;---------------------
PLY_AKYst_RRB_NIS_HardwareOnly:

PLY_AKYst_RRB_NIS_HardwareOnly_Loop:

        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rol.b #1,d1
        move.b d1,d2
        and.b #%1110,d1
        move.b d1,PLY_AKYst_PsgRegister13

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        ;Hardware volume.
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).

        add.w #$201,d7                                          ;Increases the volume register (low byte), frequency register (high byte)

        move.b d2,d1

        ;LSB for hardware period? Currently on b6.
        rol.b #2,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSB
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB
PLY_AKYst_RRB_NIS_HardwareOnly_LSB:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB:

        ;MSB for hardware period?
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSB
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB
PLY_AKYst_RRB_NIS_HardwareOnly_MSB:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB:
        
        ;Noise or retrig?
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
        rts


;---------------------
PLY_AKYst_RRB_NIS_SoftwareAndHardware:

PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop:

        ;Hardware volume.
                                                                ;Sends the volume.
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).

        addq.w #1,d7                                            ;Increases the volume register.

        ;LSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBH
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBH
PLY_AKYst_RRB_NIS_SAHH_LSBH:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBH:

        ;MSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBH
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBH
PLY_AKYst_RRB_NIS_SAHH_MSBH:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBH:
        
        ;LSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBS
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBS
PLY_AKYst_RRB_NIS_SAHH_LSBS:
        move.w d7,(a2)
        move.b (a1)+,(a3)
                                                                ;d7 high byte not increased on purpose.
PLY_AKYst_RRB_NIS_SAHH_AfterLSBS:
       
        ;MSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBS
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBS
PLY_AKYst_RRB_NIS_SAHH_MSBS:
                                                                ;Sends the MSB software frequency.
        add.w #1<<8,d7

        move.w d7,(a2)
        move.b (a1)+,(a3)

        sub.w #1<<8,d7                                          ;Yup. Will be compensated below.
PLY_AKYst_RRB_NIS_SAHH_AfterMSBS:
        add.w #2<<8,d7

        ;New hardware envelope?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_Envelope
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope
PLY_AKYst_RRB_NIS_SAHH_Envelope:
        move.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope:

        ;Retrig and/or noise?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
        rts

        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop:
        ;Noise or retrig. Reads the next byte.
        move.b (a1)+,d1

        ;Retrig?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Retrig
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig
PLY_AKYst_RRB_NIS_S_NOR_Retrig:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet d1 can still be use.
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig:

        ;Noise? If no, nothing more to do.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Noise
        rts
PLY_AKYst_RRB_NIS_S_NOR_Noise:
        
        ;Noise. Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ;Is there a new noise value? If yes, gets the noise.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoise
        rts
PLY_AKYst_RRB_NIS_S_NOR_SetNoise:
        ;Sets the noise.
        move.b d1,PLY_AKYst_PsgRegister6
        rts

;Some stored PSG registers.
PLY_AKYst_PsgRegister6: dc.b 0
PLY_AKYst_PsgRegister11: dc.b 0
PLY_AKYst_PsgRegister12: dc.b 0
PLY_AKYst_PsgRegister13: dc.b 0

