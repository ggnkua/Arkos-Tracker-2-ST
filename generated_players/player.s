;
; AKY music player
;
; Port by George Nakos (GGN of pick-your-favorite-group - KUA software productions/D-Bug/Paradize/Reboot/Bello games)
; (yes, crews are becoming pointless :))
;
; Based on the soruces of "Stabilized AKY music player - V1.0."
;       By Julien N^)vo a.k.a. Targhan/Arkos.
;       February 2018.
;
; This source was written for the rmac assembler (http://rmac.is-slick.com)
; It should be fairly easy to adapt to other assemblers.
;
; Note that the source makes use of macros, so take a look at their definitions (after these messages end) before reading the code
; Equates that control code generation:
;UNROLLED_CODE - if 1, enable unrolled slightly faster YM register reading code
;SID_VOICES    - if 1, enable SID voices (takes more CPU time!)
;PC_REL_CODE   - if 1, make code PC relative (helps if you move the routine around, like for example SNDH)
;AVOID_SMC     - if 1, assemble the player without SMC stuff, 
;DUMP_SONG     - if 1, produce a YM dump of the tune. DOES NOT WORK WITH SID OR EVENTS YET!
;
; Note that if you define want to create SNDH files, you should enable PC_REL_CODE and AVOID_SMC as well. SNDH files are meant to be compatible with all platforms
;
; Stuff TODO:
; @ Clean up register usage
; @ In PLY_AKYst_RRB_NIS_ManageLoop there is an auto-even of address happening due to the way the data is exported. This can be fixed by a) Exporting all data as words, b) pre-parsing the tune during init, finding odd addresses, even them and patch all affected offsets
; Macros for sndh or normal player.
; In sndh mode the player has to be position independent, and that mostly boils down
; to being PC relative. So we define some macros for the instructions that require
; one format or the other, just so both versions of the player can be generated
; from the same source
PLY_AKYst_RRB_NoiseChannelBit equ 5                             ;Bit to modify to set/reset the noise channel.
PLY_AKYst_RRB_SoundChannelBit equ 2                             ;Bit to modify to set/reset the sound channel.
;
; Subroutine PLY_AKYst_ReadRegisterBlock as a macro, so it can be inlined with the code
; volume = the YM volume register to update
; frequency = the YM low frequency register to update
; subroutine = 1 if used as a subroutine, 0 if used as inline expansion
; Originally the code used to have PLY_AKYst_ReadRegisterBlock as a subroutine
; which would call 3 times, once for each YM channel. In order to gain some speed
; this was changed into a macro and inlined with the code. However, people might still need
; the subroutine version because of space reasons (small intros, etc). Hence the
; "subroutine" parameter.
; Generally for each register write there are 4 different code paths:
; 1) Code used as subroutine, no SID voices
; 2) Code used as subroutine, SID voices
; 3) Code inlined, no SID voices
; 4) Code inlined, SID voices
; Each of those paths has slightly different code: the SID versions don't write to the YM
; directly but fill in a table for the SID routine, while the normal versions bang the
; registers directly. Each code path is of different optimisation maturity, so tread lightly!
; While the inlined versions have the luxury of knowing which registers to update beforehand,
; the subroutine versions don't. The mechanism used is to carry both values in d7:
; volume is low byte, frequency is high. These need to be updated after each write,
; as you'll notice. 
;
PLY_AKYst_OPCODE_SZF  equ $7200                                 ;Opcode for "moveq #0,d0".
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
        move.l a0,PLY_AKYst_PtLinker
        move.w #PLY_AKYst_OPCODE_SZF,d0
        move.w d0,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        move.w d0,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        move.w d0,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        move.w #$1,PLY_AKYst_PatternFrameCounter
        rts
;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
;       a0.l=start of tune
;       a6.l=buffer to store YM values if dumping (DUMP_SONG)
PLY_AKYst_Play:
        lea $ffff8800.w,a2                                      ;cache YM registers
        lea $ffff8802.w,a3
;Linker.
;----------------------------------------
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PatternFrameCounter equ *+2
        move.w #1,d1                                            ;How many frames left before reading the next Pattern.
        subq.w #1,d1
        beq.s PLY_AKYst_PatternFrameCounter_Over
        move.w d1,PLY_AKYst_PatternFrameCounter
        bra.s PLY_AKYst_PatternFrameManagement_End
PLY_AKYst_PatternFrameCounter_Over:
;The pattern is over. Reads the next one.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PtLinker = *+2
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
PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock = *+3
        move.b #1,d1                                            ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1
        beq.s PLY_AKYst_Channel1_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel1_RegisterBlock_Process
PLY_AKYst_Channel1_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtTrack = *+2
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
PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock = *+3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1       
        beq.s PLY_AKYst_Channel2_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel2_RegisterBlock_Process
PLY_AKYst_Channel2_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_PtTrack = *+2
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
PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock = *+3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1
        beq.s PLY_AKYst_Channel3_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel3_RegisterBlock_Process
PLY_AKYst_Channel3_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtTrack equ *+2
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
        move.w #((0*256)+8),d7                                  ;d7 high byte = first frequency register, d7 low byte = first volume register.
        move.w #$f690,d4                                        ;$90 used for both $80 for the PSG, and volume 16!
        ;In d3, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        ;Bits 6 and 7 are also set (bits 8 and 9 in the instruction below) - at least bit 6 is crucial to be
        ;set as the Falcon's internal IDE drives might switch off otherwise!
        move.w #%1111100000,d3
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtRegisterBlock = *+2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel1_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel1_PtRegisterBlock
;Reading the RegisterBlock - Channel 2
;----------------------------------------
        ;Shifts the R7 for the next channels.
        lsr.b #1,d3
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_PtRegisterBlock equ *+2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel2_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel2_PtRegisterBlock
;Reading the RegisterBlock - Channel 3
;----------------------------------------
        ;Shifts the R7 for the next channels.
        lsr.b #1,d3
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtRegisterBlock equ *+2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel3_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel3_PtRegisterBlock
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
PLY_AKYst_PsgRegister13_Retrig equ *+3
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
        readregs 0,0,1
PLY_AKYst_ReadRegisterBlockM33:
PLY_AKYst_RRB_BranchOnNonInitailStateM33:
        bne PLY_AKYst_RRB_NonInitialStateM33
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTableM33(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTableM33(pc,a5.w)
PLY_AKYst_IS_JPTableM33:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM33-PLY_AKYst_IS_JPTableM33
        dc.w PLY_AKYst_RRB_IS_SoftwareOnlyM33-PLY_AKYst_IS_JPTableM33
        dc.w PLY_AKYst_RRB_IS_HardwareOnlyM33-PLY_AKYst_IS_JPTableM33
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardwareM33-PLY_AKYst_IS_JPTableM33
PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM33:
        lsr.b #1,d1             
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM33
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM33
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM33:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM33:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolumeM33:
        move.b d7,(a2)
        move.b d1,(a3)
        add.w #(2<<8)+1,d7                                      
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        rts
PLY_AKYst_RRB_IS_HardwareOnlyM33:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_RetrigM33
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrigM33
PLY_AKYst_RRB_IS_HO_RetrigM33:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrigM33:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_NoiseM33
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoiseM33
PLY_AKYst_RRB_IS_HO_NoiseM33:                                      
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoiseM33:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d7,(a2)
        move.b d4,(a3)                                     
        add.w #$201,d7                                          
        rts
PLY_AKYst_RRB_IS_SoftwareOnlyM33:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM33
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM33
PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM33:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM33:
        move.b d7,(a2)
        move.b d1,(a3)
        addq.w #1,d7                                            
        move.w d7,(a2)
        move.b (a1)+,(a3)
        add.w #1<<8,d7                                          
        move.w d7,(a2)
        move.b (a1)+,(a3)
        add.w #1<<8,d7                                          
        rts
PLY_AKYst_RRB_IS_SoftwareAndHardwareM33:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_RetrigM33
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrigM33
PLY_AKYst_RRB_IS_SAH_RetrigM33:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrigM33:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_NoiseM33
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoiseM33
PLY_AKYst_RRB_IS_SAH_NoiseM33:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoiseM33:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.w d7,(a2)
        move.b (a1)+,(a3)
        add.w #1<<8,d7                                          
        move.w d7,(a2)
        move.b (a1)+,(a3)
        add.w #1<<8,d7                                          
        move.b d7,(a2)
        move.b d4,(a3)                                     
        addq.w #1,d7                                            
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        rts
PLY_AKYst_RRB_NonInitialStateM33:
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00001111,d2                                      
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTableM33(pc),a5
        add.w PLY_AKYst_NIS_JPTableM33(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTableM33:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_ManageLoopM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM33-PLY_AKYst_NIS_JPTableM33          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM33-PLY_AKYst_NIS_JPTableM33          
PLY_AKYst_RRB_NIS_ManageLoopM33:
        move.l a1,d1
        addq.l #1,d1
        bclr #0,d1
        move.l d1,a1
        move.w (a1),a1
        lea (a0,a1.w),a1
        move.b (a1)+,d1
        move.b d1,d2                                            
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTable_NoLoopM33(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoopM33(pc,a5.w)
PLY_AKYst_NIS_JPTable_NoLoopM33:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM33-PLY_AKYst_NIS_JPTable_NoLoopM33     
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM33-PLY_AKYst_NIS_JPTable_NoLoopM33     
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_LoopM33-PLY_AKYst_NIS_JPTable_NoLoopM33     
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM33-PLY_AKYst_NIS_JPTable_NoLoopM33     
PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM33:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM33:
        move.b d1,d2                                            
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_VolumeM33
        bra.s PLY_AKYst_RRB_NIS_AfterVolumeM33
PLY_AKYst_RRB_NIS_VolumeM33:
        and.b #%1111,d1
        move.b d7,(a2)
        move.b d1,(a3)
PLY_AKYst_RRB_NIS_AfterVolumeM33:
        add.w #$201,d7                                          
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_NoiseM33
        rts
PLY_AKYst_RRB_NIS_NoiseM33:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        rts
PLY_AKYst_RRB_NIS_SoftwareOnlyM33:
PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM33:
        move.b d1,d2
        and.b #%1111,d1
        move.b d7,(a2)
        move.b d1,(a3)
        addq.w #1,d7                                            
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM33
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM33
PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM33:
        move.w d7,(a2)
        move.b (a1)+,(a3)
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM33:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM33
        add.w #2<<8,d7
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM33:
        move.b (a1)+,d1                                         
        add.w #1<<8,d7                                          
        move.w d7,(a2)
        move.b d1,(a3)
        add.w #1<<8,d7                                          
        rol.b #1,d1                                             
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM33
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM33:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM33
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM33:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        rts
PLY_AKYst_RRB_NIS_HardwareOnlyM33:
PLY_AKYst_RRB_NIS_HardwareOnly_LoopM33:
        rol.b #1,d1
        move.b d1,d2
        and.b #%1110,d1
        move.b d1,PLY_AKYst_PsgRegister13
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d7,(a2)
        move.b d4,(a3)                                     
        add.w #$201,d7                                          
        move.b d2,d1
        rol.b #2,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSBM33
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM33
PLY_AKYst_RRB_NIS_HardwareOnly_LSBM33:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM33:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSBM33
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM33
PLY_AKYst_RRB_NIS_HardwareOnly_MSBM33:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM33:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM33
        rts
PLY_AKYst_RRB_NIS_SoftwareAndHardwareM33:
PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM33:
        move.b d7,(a2)
        move.b d4,(a3)                                     
        addq.w #1,d7                                            
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBHM33
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM33
PLY_AKYst_RRB_NIS_SAHH_LSBHM33:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM33:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBHM33
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM33
PLY_AKYst_RRB_NIS_SAHH_MSBHM33:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM33:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBSM33
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM33
PLY_AKYst_RRB_NIS_SAHH_LSBSM33:
        move.w d7,(a2)
        move.b (a1)+,(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM33:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBSM33
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM33
PLY_AKYst_RRB_NIS_SAHH_MSBSM33:
        add.w #1<<8,d7
        move.w d7,(a2)
        move.b (a1)+,(a3)
        sub.w #1<<8,d7                                          
PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM33:
        add.w #2<<8,d7
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_EnvelopeM33
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM33
PLY_AKYst_RRB_NIS_SAHH_EnvelopeM33:
        move.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM33:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM33
        rts
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM33:
        move.b (a1)+,d1
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_RetrigM33
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM33
PLY_AKYst_RRB_NIS_S_NOR_RetrigM33:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM33:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_NoiseM33
        rts
PLY_AKYst_RRB_NIS_S_NOR_NoiseM33:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM33
        rts
PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM33:
        move.b d1,PLY_AKYst_PsgRegister6
        rts
readregs_outM33:
;Some stored PSG registers.
PLY_AKYst_PsgRegister6: dc.b 0
PLY_AKYst_PsgRegister11: dc.b 0
PLY_AKYst_PsgRegister12: dc.b 0
PLY_AKYst_PsgRegister13: dc.b 0
