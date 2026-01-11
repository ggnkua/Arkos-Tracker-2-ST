;
; AKY music player
;
; Port by George Nakos (GGN of pick-your-favorite-group - KUA software productions/D-Bug/Paradize/Reboot/Bello games)
; (yes, crews are becoming pointless :))
;
; Based on the soruces of "Stabilized AKY music player - V1.0."
;       By Julien N^)vo a.k.a. Targhan/Arkos.
;       February 2018.
; Applied the v1.0.1 bug fix at 7th July 2025, which has the comment:
;       v1.0.1: BREAKING CHANGE: Previously generated songs (such as done with AT2) are NOT compatible (hardware sounds will sound broken).
;               - Corrected a bug if using player configuration + hardware-only sound with noise (noise would disappear) (thanks Zik).
;               - Corrected another bug if using hardware-only sound with odd envelope (thanks Zik again).
;
; This source was written for the rmac assembler (http://rmac.is-slick.com)
; It should be fairly easy to adapt to other assemblers.
;
; Note that the source makes use of macros, so take a look at their definitions (after these messages end) before reading the code
;
; Equates that control code generation:
;
;UNROLLED_CODE - if 1, enable unrolled slightly faster YM register reading code
;SID_VOICES    - if 1, enable SID voices (takes more CPU time!)
;PC_REL_CODE   - if 1, make code PC relative (helps if you move the routine around, like for example SNDH)
;AVOID_SMC     - if 1, assemble the player without SMC stuff,
;DUMP_SONG     - if 1, produce a YM dump of the tune. DOES NOT WORK WITH SID OR EVENTS YET!
;SAMPLES       - if 1, call the sample player before the player exits
;
; Note that if you define want to create SNDH files, you should enable PC_REL_CODE and AVOID_SMC as well. SNDH files are meant to be compatible with all platforms
;
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
;       Initialises the player.
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
        lea values_store+2(pc),a3
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
PLY_AKYst_ReadRegisterBlockM26:
PLY_AKYst_RRB_BranchOnNonInitailStateM26:
        bne PLY_AKYst_RRB_NonInitialStateM26
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTableM26(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTableM26(pc,a5.w)
PLY_AKYst_IS_JPTableM26:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM26-PLY_AKYst_IS_JPTableM26
        dc.w PLY_AKYst_RRB_IS_SoftwareOnlyM26-PLY_AKYst_IS_JPTableM26
        dc.w PLY_AKYst_RRB_IS_HardwareOnlyM26-PLY_AKYst_IS_JPTableM26
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardwareM26-PLY_AKYst_IS_JPTableM26
PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM26:
        lsr.b #1,d1             
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM26
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM26
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM26:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM26:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolumeM26:
        move.b d1,4*$8(a3)
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        bra readregs_outM26
PLY_AKYst_RRB_IS_HardwareOnlyM26:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_RetrigM26
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrigM26
PLY_AKYst_RRB_IS_HO_RetrigM26:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrigM26:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_NoiseM26
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoiseM26
PLY_AKYst_RRB_IS_HO_NoiseM26:                                    
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoiseM26:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d4,4*$8(a3)
        bra readregs_outM26
PLY_AKYst_RRB_IS_SoftwareOnlyM26:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM26
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM26
PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM26:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM26:
        move.b d1,4*$8(a3)
        move.b (a1)+,4*$0(a3)
        move.b (a1)+,4*($0+1)(a3)
        bra readregs_outM26
PLY_AKYst_RRB_IS_SoftwareAndHardwareM26:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_RetrigM26
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrigM26
PLY_AKYst_RRB_IS_SAH_RetrigM26:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrigM26:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_NoiseM26
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoiseM26
PLY_AKYst_RRB_IS_SAH_NoiseM26:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoiseM26:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,4*$0(a3)
        move.b (a1)+,4*($0+1)(a3)
        move.b d4,4*$8(a3)
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bra readregs_outM26
PLY_AKYst_RRB_NonInitialStateM26:
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00001111,d2                                      
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTableM26(pc),a5
        add.w PLY_AKYst_NIS_JPTableM26(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTableM26:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_ManageLoopM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM26-PLY_AKYst_NIS_JPTableM26          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM26-PLY_AKYst_NIS_JPTableM26          
PLY_AKYst_RRB_NIS_ManageLoopM26:
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
        lea PLY_AKYst_NIS_JPTable_NoLoopM26(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoopM26(pc,a5.w)
PLY_AKYst_NIS_JPTable_NoLoopM26:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM26-PLY_AKYst_NIS_JPTable_NoLoopM26     
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM26-PLY_AKYst_NIS_JPTable_NoLoopM26     
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_LoopM26-PLY_AKYst_NIS_JPTable_NoLoopM26     
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM26-PLY_AKYst_NIS_JPTable_NoLoopM26     
PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM26:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM26:
        move.b d1,d2                                            
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_VolumeM26
        bra.s PLY_AKYst_RRB_NIS_AfterVolumeM26
PLY_AKYst_RRB_NIS_VolumeM26:
        and.b #%1111,d1
        move.b d1,4*$8(a3)
PLY_AKYst_RRB_NIS_AfterVolumeM26:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_NoiseM26
        bra readregs_outM26
PLY_AKYst_RRB_NIS_NoiseM26:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        bra readregs_outM26
PLY_AKYst_RRB_NIS_SoftwareOnlyM26:
PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM26:
        move.b d1,d2
        and.b #%1111,d1
        move.b d1,4*$8(a3)
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM26
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM26
PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM26:
        move.b (a1)+,4*$0(a3)
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM26:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM26
        bra readregs_outM26
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM26:
        move.b (a1)+,d1                                         
        move.b d1,4*($0+1)(a3)
        rol.b #1,d1                                             
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM26
        bra readregs_outM26
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM26:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM26
        bra readregs_outM26
PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM26:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bra readregs_outM26
PLY_AKYst_RRB_NIS_HardwareOnlyM26:
PLY_AKYst_RRB_NIS_HardwareOnly_LoopM26:
        move.b d1,d2
        and.b #%111,d1
        or.b #%1000,d1                                          
        move.b d1,PLY_AKYst_PsgRegister13
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d4,4*$8(a3)
        move.b d2,d1
        rol.b #3,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSBM26
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM26
PLY_AKYst_RRB_NIS_HardwareOnly_LSBM26:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM26:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSBM26
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM26
PLY_AKYst_RRB_NIS_HardwareOnly_MSBM26:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM26:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM26
        bra.s readregs_outM26
PLY_AKYst_RRB_NIS_SoftwareAndHardwareM26:
PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM26:
        move.b d4,4*$8(a3)
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBHM26
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM26
PLY_AKYst_RRB_NIS_SAHH_LSBHM26:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM26:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBHM26
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM26
PLY_AKYst_RRB_NIS_SAHH_MSBHM26:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM26:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBSM26
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM26
PLY_AKYst_RRB_NIS_SAHH_LSBSM26:
        move.b (a1)+,4*$0(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM26:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBSM26
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM26
PLY_AKYst_RRB_NIS_SAHH_MSBSM26:
        move.b (a1)+,4*($0+1)(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM26:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_EnvelopeM26
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM26
PLY_AKYst_RRB_NIS_SAHH_EnvelopeM26:
        move.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM26:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM26
        bra.s readregs_outM26
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM26:
        move.b (a1)+,d1
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_RetrigM26
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM26
PLY_AKYst_RRB_NIS_S_NOR_RetrigM26:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM26:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_NoiseM26
        bra.s readregs_outM26
PLY_AKYst_RRB_NIS_S_NOR_NoiseM26:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM26
        bra.s readregs_outM26
PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM26:
        move.b d1,PLY_AKYst_PsgRegister6
readregs_outM26:
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
PLY_AKYst_ReadRegisterBlockM51:
PLY_AKYst_RRB_BranchOnNonInitailStateM51:
        bne PLY_AKYst_RRB_NonInitialStateM51
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTableM51(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTableM51(pc,a5.w)
PLY_AKYst_IS_JPTableM51:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM51-PLY_AKYst_IS_JPTableM51
        dc.w PLY_AKYst_RRB_IS_SoftwareOnlyM51-PLY_AKYst_IS_JPTableM51
        dc.w PLY_AKYst_RRB_IS_HardwareOnlyM51-PLY_AKYst_IS_JPTableM51
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardwareM51-PLY_AKYst_IS_JPTableM51
PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM51:
        lsr.b #1,d1             
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM51
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM51
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM51:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM51:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolumeM51:
        move.b d1,4*$9(a3)
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        bra readregs_outM51
PLY_AKYst_RRB_IS_HardwareOnlyM51:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_RetrigM51
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrigM51
PLY_AKYst_RRB_IS_HO_RetrigM51:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrigM51:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_NoiseM51
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoiseM51
PLY_AKYst_RRB_IS_HO_NoiseM51:                                    
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoiseM51:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d4,4*$9(a3)
        bra readregs_outM51
PLY_AKYst_RRB_IS_SoftwareOnlyM51:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM51
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM51
PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM51:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM51:
        move.b d1,4*$9(a3)
        move.b (a1)+,4*$2(a3)
        move.b (a1)+,4*($2+1)(a3)
        bra readregs_outM51
PLY_AKYst_RRB_IS_SoftwareAndHardwareM51:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_RetrigM51
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrigM51
PLY_AKYst_RRB_IS_SAH_RetrigM51:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrigM51:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_NoiseM51
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoiseM51
PLY_AKYst_RRB_IS_SAH_NoiseM51:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoiseM51:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,4*$2(a3)
        move.b (a1)+,4*($2+1)(a3)
        move.b d4,4*$9(a3)
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bra readregs_outM51
PLY_AKYst_RRB_NonInitialStateM51:
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00001111,d2                                      
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTableM51(pc),a5
        add.w PLY_AKYst_NIS_JPTableM51(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTableM51:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_ManageLoopM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM51-PLY_AKYst_NIS_JPTableM51          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM51-PLY_AKYst_NIS_JPTableM51          
PLY_AKYst_RRB_NIS_ManageLoopM51:
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
        lea PLY_AKYst_NIS_JPTable_NoLoopM51(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoopM51(pc,a5.w)
PLY_AKYst_NIS_JPTable_NoLoopM51:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM51-PLY_AKYst_NIS_JPTable_NoLoopM51     
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM51-PLY_AKYst_NIS_JPTable_NoLoopM51     
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_LoopM51-PLY_AKYst_NIS_JPTable_NoLoopM51     
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM51-PLY_AKYst_NIS_JPTable_NoLoopM51     
PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM51:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM51:
        move.b d1,d2                                            
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_VolumeM51
        bra.s PLY_AKYst_RRB_NIS_AfterVolumeM51
PLY_AKYst_RRB_NIS_VolumeM51:
        and.b #%1111,d1
        move.b d1,4*$9(a3)
PLY_AKYst_RRB_NIS_AfterVolumeM51:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_NoiseM51
        bra readregs_outM51
PLY_AKYst_RRB_NIS_NoiseM51:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        bra readregs_outM51
PLY_AKYst_RRB_NIS_SoftwareOnlyM51:
PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM51:
        move.b d1,d2
        and.b #%1111,d1
        move.b d1,4*$9(a3)
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM51
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM51
PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM51:
        move.b (a1)+,4*$2(a3)
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM51:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM51
        bra readregs_outM51
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM51:
        move.b (a1)+,d1                                         
        move.b d1,4*($2+1)(a3)
        rol.b #1,d1                                             
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM51
        bra readregs_outM51
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM51:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM51
        bra readregs_outM51
PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM51:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bra readregs_outM51
PLY_AKYst_RRB_NIS_HardwareOnlyM51:
PLY_AKYst_RRB_NIS_HardwareOnly_LoopM51:
        move.b d1,d2
        and.b #%111,d1
        or.b #%1000,d1                                          
        move.b d1,PLY_AKYst_PsgRegister13
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d4,4*$9(a3)
        move.b d2,d1
        rol.b #3,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSBM51
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM51
PLY_AKYst_RRB_NIS_HardwareOnly_LSBM51:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM51:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSBM51
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM51
PLY_AKYst_RRB_NIS_HardwareOnly_MSBM51:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM51:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM51
        bra.s readregs_outM51
PLY_AKYst_RRB_NIS_SoftwareAndHardwareM51:
PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM51:
        move.b d4,4*$9(a3)
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBHM51
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM51
PLY_AKYst_RRB_NIS_SAHH_LSBHM51:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM51:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBHM51
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM51
PLY_AKYst_RRB_NIS_SAHH_MSBHM51:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM51:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBSM51
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM51
PLY_AKYst_RRB_NIS_SAHH_LSBSM51:
        move.b (a1)+,4*$2(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM51:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBSM51
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM51
PLY_AKYst_RRB_NIS_SAHH_MSBSM51:
        move.b (a1)+,4*($2+1)(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM51:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_EnvelopeM51
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM51
PLY_AKYst_RRB_NIS_SAHH_EnvelopeM51:
        move.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM51:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM51
        bra.s readregs_outM51
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM51:
        move.b (a1)+,d1
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_RetrigM51
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM51
PLY_AKYst_RRB_NIS_S_NOR_RetrigM51:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM51:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_NoiseM51
        bra.s readregs_outM51
PLY_AKYst_RRB_NIS_S_NOR_NoiseM51:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM51
        bra.s readregs_outM51
PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM51:
        move.b d1,PLY_AKYst_PsgRegister6
readregs_outM51:
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
PLY_AKYst_ReadRegisterBlockM76:
PLY_AKYst_RRB_BranchOnNonInitailStateM76:
        bne PLY_AKYst_RRB_NonInitialStateM76
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTableM76(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTableM76(pc,a5.w)
PLY_AKYst_IS_JPTableM76:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM76-PLY_AKYst_IS_JPTableM76
        dc.w PLY_AKYst_RRB_IS_SoftwareOnlyM76-PLY_AKYst_IS_JPTableM76
        dc.w PLY_AKYst_RRB_IS_HardwareOnlyM76-PLY_AKYst_IS_JPTableM76
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardwareM76-PLY_AKYst_IS_JPTableM76
PLY_AKYst_RRB_IS_NoSoftwareNoHardwareM76:
        lsr.b #1,d1             
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM76
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM76
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoiseM76:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_EndM76:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolumeM76:
        move.b d1,4*$A(a3)
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        bra readregs_outM76
PLY_AKYst_RRB_IS_HardwareOnlyM76:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_RetrigM76
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrigM76
PLY_AKYst_RRB_IS_HO_RetrigM76:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrigM76:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_NoiseM76
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoiseM76
PLY_AKYst_RRB_IS_HO_NoiseM76:                                    
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoiseM76:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d4,4*$A(a3)
        bra readregs_outM76
PLY_AKYst_RRB_IS_SoftwareOnlyM76:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM76
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM76
PLY_AKYst_RRB_IS_SoftwareOnly_NoiseM76:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoiseM76:
        move.b d1,4*$A(a3)
        move.b (a1)+,4*$4(a3)
        move.b (a1)+,4*($4+1)(a3)
        bra readregs_outM76
PLY_AKYst_RRB_IS_SoftwareAndHardwareM76:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_RetrigM76
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrigM76
PLY_AKYst_RRB_IS_SAH_RetrigM76:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrigM76:
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_NoiseM76
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoiseM76
PLY_AKYst_RRB_IS_SAH_NoiseM76:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoiseM76:
        and.b #%1111,d1
        move.b d1,PLY_AKYst_PsgRegister13
        move.b (a1)+,4*$4(a3)
        move.b (a1)+,4*($4+1)(a3)
        move.b d4,4*$A(a3)
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+$1
        bra readregs_outM76
PLY_AKYst_RRB_NonInitialStateM76:
        move.b (a1)+,d1
        move.b d1,d2
        and.b #%00001111,d2                                      
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTableM76(pc),a5
        add.w PLY_AKYst_NIS_JPTableM76(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTableM76:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_ManageLoopM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_HardwareOnlyM76-PLY_AKYst_NIS_JPTableM76          
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardwareM76-PLY_AKYst_NIS_JPTableM76          
PLY_AKYst_RRB_NIS_ManageLoopM76:
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
        lea PLY_AKYst_NIS_JPTable_NoLoopM76(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoopM76(pc,a5.w)
PLY_AKYst_NIS_JPTable_NoLoopM76:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM76-PLY_AKYst_NIS_JPTable_NoLoopM76     
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM76-PLY_AKYst_NIS_JPTable_NoLoopM76     
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_LoopM76-PLY_AKYst_NIS_JPTable_NoLoopM76     
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM76-PLY_AKYst_NIS_JPTable_NoLoopM76     
PLY_AKYst_RRB_NIS_NoSoftwareNoHardwareM76:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_LoopM76:
        move.b d1,d2                                            
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_VolumeM76
        bra.s PLY_AKYst_RRB_NIS_AfterVolumeM76
PLY_AKYst_RRB_NIS_VolumeM76:
        and.b #%1111,d1
        move.b d1,4*$A(a3)
PLY_AKYst_RRB_NIS_AfterVolumeM76:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_NoiseM76
        bra readregs_outM76
PLY_AKYst_RRB_NIS_NoiseM76:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        bra readregs_outM76
PLY_AKYst_RRB_NIS_SoftwareOnlyM76:
PLY_AKYst_RRB_NIS_SoftwareOnly_LoopM76:
        move.b d1,d2
        and.b #%1111,d1
        move.b d1,4*$A(a3)
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM76
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM76
PLY_AKYst_RRB_NIS_SoftwareOnly_LSPM76:
        move.b (a1)+,4*$4(a3)
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSPM76:
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM76
        bra readregs_outM76
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoiseM76:
        move.b (a1)+,d1                                         
        move.b d1,4*($4+1)(a3)
        rol.b #1,d1                                             
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM76
        bra readregs_outM76
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresentM76:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM76
        bra readregs_outM76
PLY_AKYst_RRB_NIS_SoftwareOnly_NoiseM76:
        move.b (a1)+,PLY_AKYst_PsgRegister6
        bra readregs_outM76
PLY_AKYst_RRB_NIS_HardwareOnlyM76:
PLY_AKYst_RRB_NIS_HardwareOnly_LoopM76:
        move.b d1,d2
        and.b #%111,d1
        or.b #%1000,d1                                          
        move.b d1,PLY_AKYst_PsgRegister13
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        move.b d4,4*$A(a3)
        move.b d2,d1
        rol.b #3,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSBM76
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM76
PLY_AKYst_RRB_NIS_HardwareOnly_LSBM76:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSBM76:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSBM76
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM76
PLY_AKYst_RRB_NIS_HardwareOnly_MSBM76:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSBM76:
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM76
        bra.s readregs_outM76
PLY_AKYst_RRB_NIS_SoftwareAndHardwareM76:
PLY_AKYst_RRB_NIS_SoftwareAndHardware_LoopM76:
        move.b d4,4*$A(a3)
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBHM76
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM76
PLY_AKYst_RRB_NIS_SAHH_LSBHM76:
        move.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBHM76:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBHM76
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM76
PLY_AKYst_RRB_NIS_SAHH_MSBHM76:
        move.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBHM76:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBSM76
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM76
PLY_AKYst_RRB_NIS_SAHH_LSBSM76:
        move.b (a1)+,4*$4(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterLSBSM76:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBSM76
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM76
PLY_AKYst_RRB_NIS_SAHH_MSBSM76:
        move.b (a1)+,4*($4+1)(a3)
PLY_AKYst_RRB_NIS_SAHH_AfterMSBSM76:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_EnvelopeM76
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM76
PLY_AKYst_RRB_NIS_SAHH_EnvelopeM76:
        move.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelopeM76:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM76
        bra.s readregs_outM76
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStopM76:
        move.b (a1)+,d1
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_RetrigM76
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM76
PLY_AKYst_RRB_NIS_S_NOR_RetrigM76:
        bset #7,d1                                              
        move.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrigM76:
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_NoiseM76
        bra.s readregs_outM76
PLY_AKYst_RRB_NIS_S_NOR_NoiseM76:
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM76
        bra.s readregs_outM76
PLY_AKYst_RRB_NIS_S_NOR_SetNoiseM76:
        move.b d1,PLY_AKYst_PsgRegister6
readregs_outM76:
PLY_AKYst_Channel3_RegisterBlock_Return:
        move.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        move.l a1,PLY_AKYst_Channel3_PtRegisterBlock
        ;Register 7 to d1.
        move.w d3,d1
;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).
;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).
        move.b d1,(7*4)(a3)
;Register 6
        move.b PLY_AKYst_PsgRegister6(pc),(6*4)(a3)
;Register 11
        lea $ffff8800.w,a2                                      ;we're going to write these values immediately to the YM so we might as well load an address register
        move.b #11,(a2)
        move.b PLY_AKYst_PsgRegister11(pc),2(a2)
;Register 12
        move.b #12,(a2)
        move.b PLY_AKYst_PsgRegister12(pc),2(a2)
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
        move.b d1,2(a2)
PLY_AKYst_PsgRegister13_End:
PLY_AKYst_Exit:
        rts
;Some stored PSG registers.
PLY_AKYst_PsgRegister6: dc.b 0
PLY_AKYst_PsgRegister11: dc.b 0
PLY_AKYst_PsgRegister12: dc.b 0
PLY_AKYst_PsgRegister13: dc.b 0
   readregs_outM26 00000000000003A6  t 
   readregs_outM51 0000000000000624  t 
   readregs_outM76 00000000000008A2  t 
