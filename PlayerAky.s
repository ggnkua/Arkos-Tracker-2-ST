;       Stabilized AKY music player - V1.0.
;       By Julien Névo a.k.a. Targhan/Arkos.
;       February 2018.

;       This version of the AKY player is "stabilized", which means that the CPU consumed by the player (on Amstrad CPC) is always the same. It is also slower,
;       since the worst-case branching is always taken in account. However, it is hugely convenient for demos or games with require cycle-accurate timings!
;       The "waiting" also makes the code bigger (and less readable).

;       The init code is not stabilized (is it a problem?).

;       PSG sending optimization trick by Madram/Overlanders.

;       The player uses the stack for optimizations. Make sure the interruptions are disabled before it is called.
;       The stack pointer is saved at the beginning and restored at the end.

;       Possible optimizations:
;       SIZE: The JP hooks at the beginning can be removed if you include this code in yours directly.
;       SIZE: If you don't play a song twice, all the code in PLY_AKYst_Init can be removed, except the first lines that skip the header.
;       SIZE: The header is only needed for players that want to load any song. Most of the time, you don't need it. Erase both the init code and the header bytes in the song.

; Port by George Nakos (GGN of pick-your-favorite-group - KUA software productions/D-Bug/Paradize/Reboot/Bello games)
; (yes, crews are becoming pointless :))
        
;Global convetions for mapping of z80 registers
;assuming that hl=a1
;assuming that sp=a6
;assuming that a=d1
;assuming that af=d7
;assuming that bc=d3
;assuming that de=d2
;assuming that bc'=d4
;assuming that hl'=a2
;assuming that a'=d0
;assuming that af'=d5
;assuming that de'=d6
;Note: I am using a in a register of its own even though it's a part of af. I think this is a good idea in general but we'll have to see if this causes other problems (the obvious problem is that if I use d1 then the upper bits of d3.w aren't updated automatically)
;Note 2: exx and ex isntructions are "emulated" using exg which not the most optimium way to do this. Ideally the regions where ex/exx have effect the register names can be swapped. HOWEVER: for now this is very error prone. A third pass of the source when the player is running properly can eliminate this
;Note 3: register f doesn't appear to be used in the main player - so we can probably junk d7/d5

; Register mappings
; 

; Macros for sndh or normal player.
; In sndh mode the player has to be position independent, and that mostly boils down
; to being PC relative. So we define some macros for the instructions that require
; one format or the other, just so both versions of the player can be generated
; from the same source

    .macro movex src,dst
    .if ^^defined SNDH_PLAYER
        move\! \src,\dst - PLY_AKYst_Init(a4)
    .else
        move\! \src,\dst
    .endif
    .endm

; Nasty piece of rmac issue here - when invoked with -fb parameter
; rmac will convert $ffffxxxx.w constants to $xxxx.l
; No clever ideas about what to do for now, so this will have to do
    .macro moveym value,address
    .if ^^defined SNDH_PLAYER
        move.b \value,\address
    .else
        move.b \value,\{address}.w
    .endif
    .endm

    .macro moveymw value,address
    .if ^^defined SNDH_PLAYER
        move.w \value,\address
    .else
        move.w \value,\{address}.w
    .endif
    .endm

PLY_AKYst_OPCODE_OR_A equ $00000000                  ;Opcode for "ori.b #0,d0".
PLY_AKYst_OPCODE_SCF  equ $003c0001                         ;Opcode for "ori #1,ccr".

PLY_AKYst_Start:
        ;Hooks for external calls. Can be removed if not needed.
        bra.s PLY_AKYst_Init            ;Player + 0.
        bra.s PLY_AKYst_Play            ;Player + 2.
    


;       Initializes the player.
;       a0.l = music address
PLY_AKYst_Init:
         .if ^^defined SNDH_PLAYER
         lea PLY_AKYst_Init(pc),a4		;base pointer for PC-relative stores
         .endif

        ;Skips the header.
        addq.l #1,a0                    ;Skips the format version.
        move.b (a0)+,d1                 ;Channel count.
PLY_AKYst_Init_SkipHeaderLoop:                ;There is always at least one PSG to skip.
        addq.l #4,a0
        subq.b #3,d1                    ;A PSG is three channels.
        beq.s PLY_AKYst_Init_SkipHeaderEnd
        bcc.s PLY_AKYst_Init_SkipHeaderLoop     ;Security in case of the PSG channel is not a multiple of 3.
PLY_AKYst_Init_SkipHeaderEnd:
        movex.w a0,PLY_AKYst_PtLinker       ;a0 now points on the Linker.

        move.l #PLY_AKYst_OPCODE_OR_A,d0
        movex.l d0,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        movex.l d0,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        movex.l d0,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        movex.w #1,PLY_AKYst_PatternFrameCounter

        rts

;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
; a0=start of tune - must be aligned to 64k for now!

PLY_AKYst_Play:

         .if ^^defined SNDH_PLAYER
         lea PLY_AKYst_Init(pc),a4		;base pointer for PC-relative stores
         .endif

;Linker.
;----------------------------------------
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PatternFrameCounter equ * + 2
        move.w #1,a1             ;How many frames left before reading the next Pattern.
        lea (a0,a1.w),a1
        subq.w #1,a1

* SMC - DO NOT OPTIMISE!
        cmpa.l a0,a1
        beq.s PLY_AKYst_PatternFrameCounter_Over
        movex.w a1,PLY_AKYst_PatternFrameCounter
        ;The pattern is not over.
        bra.s PLY_AKYst_PatternFrameManagement_End

PLY_AKYst_PatternFrameCounter_Over:

;The pattern is over. Reads the next one.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PtLinker = * + 2
        lea 0(a0),a6                        ;Points on the Pattern of the linker.

        move.w (a6)+,a1                     ;Gets the duration of the Pattern, or 0 if end of the song.
        lea (a0,a1.w),a1
* SMC - DO NOT OPTIMISE!
        cmpa.l a0,a1
        bne.s PLY_AKYst_LinkerNotEndSong
        ;End of the song. Where to loop?
        move.w (a6)+,a1
        lea (a0,a1.w),a1
        ;We directly point on the frame counter of the pattern to loop to.
        move.l a1,a6
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
        move.w (a6)+,a1
        lea (a0,a1.w),a1
PLY_AKYst_LinkerNotEndSong:
        movex.w a1,PLY_AKYst_PatternFrameCounter

        movex.w (a6)+,PLY_AKYst_Channel1_PtTrack
        movex.w (a6)+,PLY_AKYst_Channel2_PtTrack
        movex.w (a6)+,PLY_AKYst_Channel3_PtTrack
        movex.w a6,PLY_AKYst_PtLinker

        ;Resets the RegisterBlocks of the channels.
        moveq #1,d1
        movex.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock
        movex.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock
        movex.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock
PLY_AKYst_PatternFrameManagement_End:

;Reading the Track - channel 1.
;----------------------------------------
;PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1
        beq.s PLY_AKYst_Channel1_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel1_RegisterBlock_Process
PLY_AKYst_Channel1_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.l #PLY_AKYst_OPCODE_OR_A,d1
        movex.l d1,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
;PLY_AKYst_Channel1_PtTrack: ld sp,0                   ;Points on the Track.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtTrack = * + 2
        lea 0(a0),a6                ;Points on the Track.
        move.b (a6),d1                          ;Gets the duration.
        move.w 2(a6),a1                         ;Reads the RegisterBlock address.
        lea (a0,a1.w),a1
        addq.w #4,a6

        movex.w a6,PLY_AKYst_Channel1_PtTrack
        movex.w a1,PLY_AKYst_Channel1_PtRegisterBlock
        ;d1 is the duration of the block.
PLY_AKYst_Channel1_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        movex.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock



;Reading the Track - channel 2.
;----------------------------------------
;PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1       
        beq.s PLY_AKYst_Channel2_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel2_RegisterBlock_Process
PLY_AKYst_Channel2_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.l #PLY_AKYst_OPCODE_OR_A,d1
        movex.l d1,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
PLY_AKYst_Channel2_PtTrack = * + 2
        lea 0(a0),a6                            ;Points on the Track.
        move.b (a6),d1                          ;Gets the duration (b1-7). b0 = silence block?
        move.w 2(a6),a1
        lea (a0,a1.w),a1
        addq.w #4,a6

        movex.w a6,PLY_AKYst_Channel2_PtTrack
        movex.w a1,PLY_AKYst_Channel2_PtRegisterBlock
        ;d1 is the duration of the block.
PLY_AKYst_Channel2_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        movex.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock




;Reading the Track - channel 3.
;----------------------------------------
;PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        subq.b #1,d1
        beq.s PLY_AKYst_Channel3_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel3_RegisterBlock_Process
PLY_AKYst_Channel3_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        move.l #PLY_AKYst_OPCODE_OR_A,d1
        movex.l d1,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtTrack equ * + 2
        lea 0(a0),a6                                    ;Points on the Track.

        move.b (a6),d1                          ;Gets the duration (b1-7). b0 = silence block?
        move.w 2(a6),a1
        lea (a0,a1.w),a1
        addq.w #4,a6

        movex.w a6,PLY_AKYst_Channel3_PtTrack
        movex.w a1,PLY_AKYst_Channel3_PtRegisterBlock
PLY_AKYst_Channel3_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        movex.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock











;Reading the RegisterBlock.
;----------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------

                move.w #((0 * 256) + 8),d7                 ;d7 high byte = first frequency register, d7 low byte = first volume register.
;                move.w #$f4f6,d2
;                move.w #$f690,d3                         ;#90 used for both #80 for the PSG, and volume 16!
                move.w #$f690,d4                         ;#90 used for both #80 for the PSG, and volume 16!
        
                ;ld a,#c0                                ;Used for PSG.
;                move.w #$c0,d1                          ;Used for PSG.
                ;out (c),a                               ;f6c0. Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
        ;ex af,af'
        ;exg d0,d1
        ;exg d7,d5
        ;exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        ;In d3, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        move.w #%11100000 * 256 + 255,d3                ;d3 low is 255 to prevent the following LDIs to decrease B. 


* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtRegisterBlock = * + 2
        lea 0(a0),a1                                            ;Points on the data of the RegisterBlock to read.
PLY_AKYst_Channel1_RegisterBlockLineState_Opcode: ori.b #0,d0  ;if initial state, "ori.b #0,d0" / "ori #1,ccr" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel1_RegisterBlock_Return:
        movex.l #PLY_AKYst_OPCODE_SCF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        movex.w a1,PLY_AKYst_Channel1_PtRegisterBlock           ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 2
;----------------------------------------

        ;Shifts the R7 for the next channels.
;        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!
        ror.w #8,d3
        lsr.b #1,d3
        ror.w #8,d3     ;yeah this definitely could be done faster :)
        

PLY_AKYst_Channel2_PtRegisterBlock equ * + 2
        lea 0(a0),a1                ;Points on the data of the RegisterBlock to read.
PLY_AKYst_Channel2_RegisterBlockLineState_Opcode: ori.b #0,d0   ;if initial state, "ori.b #0,d0" / "ori #1,ccr" if non-initial state.
       bsr PLY_AKYst_ReadRegisterBlock 
PLY_AKYst_Channel2_RegisterBlock_Return:
        movex.l #PLY_AKYst_OPCODE_SCF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        movex.w a1,PLY_AKYst_Channel2_PtRegisterBlock        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 3
;----------------------------------------

        ;Shifts the R7 for the next channels.
;        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.
        ror.w #8,d3
        lsr.b #1,d3
        ror.w #8,d3     ;yeah this definitely could be done faster :)

* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtRegisterBlock equ * + 2
        lea 0(a0),a1                ;Points on the data of the RegisterBlock to read.
PLY_AKYst_Channel3_RegisterBlockLineState_Opcode: ori.b #0,d0   ;if initial state, "ori.b #0,d0" / "ori #1,ccr" if non-initial state.
        bsr PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel3_RegisterBlock_Return:
        movex.l #PLY_AKYst_OPCODE_SCF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        movex.w a1,PLY_AKYst_Channel3_PtRegisterBlock        ;This is new pointer on the RegisterBlock.

        ;Register 7 to d1.
        move.w d3,d1
        lsr.w #8,d1

;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).

;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

                moveym #7,$ffff8800
                moveym d1,$ffff8802

;Register 6
                ;sub.w #$100,a1
                moveym #6,$ffff8800
                moveym PLY_AKYst_PsgRegister6(pc),$ffff8802

;Register 11
                moveym #11,$ffff8800
                moveym PLY_AKYst_PsgRegister11(pc),$ffff8802
                

;Register 12
                moveym #12,$ffff8800
                moveym PLY_AKYst_PsgRegister12(pc),$ffff8802


;Register 13
PLY_AKYst_PsgRegister13_Code:
                move.b PLY_AKYst_PsgRegister13(pc),d1
PLY_AKYst_PsgRegister13_Retrig equ * + 3
                cmp.b #255,d1                                   ;If IsRetrig?, force the R13 to be triggered.
                bne.s PLY_AKYst_PsgRegister13_Change
                bra.s PLY_AKYst_PsgRegister13_End
PLY_AKYst_PsgRegister13_Change:
                movex.b d1,PLY_AKYst_PsgRegister13_Retrig

                moveym #13,$ffff8800
                moveym d1,$ffff8802
PLY_AKYst_PsgRegister13_End:



PLY_AKYst_Exit:
        rts








;Generic code interpreting the RegisterBlock
;IN:    HL = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYst_ReadRegisterBlock:
        ;Gets the first byte of the line. What type? Jump to the matching code thanks to the carry.
PLY_AKYst_RRB_BranchOnNonInitailState:
        bcs PLY_AKYst_RRB_NonInitialState

        ; Code from the bcs and above copied here so nothing will screw with the carry flag        
        move.b (a1)+,d1
;        move.b (a1),d1
;        addq.w #1,a1
        
        ;Not in the original code, but simplifies the stabilization.
;        ror.w #8,d2             ;d1 must be saved!
        move.b d1,d2
;        ror.w #8,d2
;        and.b #%00000011,d1
        and.b #%00000011,d2
;        add.b d1,d1
        add.b d2,d2
;        move.b d1,d2
;        move.w d2,d1            ;Retrieves d1, which is supposed to be shifted in the original code.
;        lsr.w #8,d1
;        lsr.b #1,d1
;        lsr.b #1,d1
        lsr.b #2,d1
;        and.w #$ff,d2
        ext.w d2
        lea PLY_AKYst_IS_JPTable(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTable(pc,a5.w)
PLY_AKYst_IS_JPTable:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardware-PLY_AKYst_IS_JPTable
        dc.w PLY_AKYst_RRB_IS_SoftwareOnly-PLY_AKYst_IS_JPTable
        dc.w PLY_AKYst_RRB_IS_HardwareOnly-PLY_AKYst_IS_JPTable
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardware-PLY_AKYst_IS_JPTable

;Generic code interpreting the RegisterBlock - Initial state.
;----------------------------------------------------------------
;IN:    HL = Points after the first byte.
;       A = First byte, twice shifted to the right (type removed).
;       B = Register 7. All sounds are open (0) by default, all noises closed (1). The code must put ONLY bit 2 and 5 for sound and noise respectively. NOT any other bits!
;       C = May be used as a temp. BUT must NOT be 0, as ldi will decrease it, we do NOT want B to be decreased!!
;       DE = free to use.
;       IX = free to use (not used!).
;       IY = free to use (not used!).
;       SP = Do no use, used for the RET.

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

PLY_AKYst_RRB_NoiseChannelBit equ 5          ;Bit to modify to set/reset the noise channel.
PLY_AKYst_RRB_SoundChannelBit equ 2          ;Bit to modify to set/reset the sound channel.


PLY_AKYst_RRB_IS_NoSoftwareNoHardware:          ;50 cycles.

        ;No software no hardware.
        lsr.b #1,d1             ;Noise?
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise:
        ;There is a noise. Reads it.
;        ld de,PLY_AKYst_PsgRegister6
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
;        movex.b (a1),PLY_AKYst_PsgRegister6
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3

        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End:
        
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolume:
        ;The volume is now in b0-b3.

;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        moveym d7,$ffff8800
        moveym d1,$ffff8802
;        add.w #(2<<8)+1,a1      ;Increases the volume register (low byte) and frequency register (high byte).
        add.w #(2<<8)+1,d7      ;Increases the volume register (low byte) and frequency register (high byte).
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit+8, d3
        rts


;---------------------
PLY_AKYst_RRB_IS_HardwareOnly:                          ;79 cycles.

        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Retrig
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrig
PLY_AKYst_RRB_IS_HO_Retrig:
        bset #7,d1                      ;A value to make sure the retrig is performed, yet A can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrig:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Noise 
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoise
PLY_AKYst_RRB_IS_HO_Noise:        ;Reads the noise.
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
;        movex.b (a1),PLY_AKYst_PsgRegister6
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
 
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
PLY_AKYst_RRB_IS_HO_AfterNoise:
        ;The envelope.
        and.b #%1111,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Copies the hardware period.
;        ldi
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1
;        movex.b (a1),PLY_AKYst_PsgRegister11
;        movex.b 1(a1),PLY_AKYst_PsgRegister11+1
;        addq.w #2,a1
;        addq.w #2,d2
;        subq.w #2,d3

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit+8,d3

;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        moveym d7,$ffff8800
;        moveym d3,$ffff8802     ;(volume to 16).
        moveym d4,$ffff8802     ;(volume to 16).

;        add.w #$201,a1          ;Increases the volume register (low byte), and frequency register (mandatory!).
        add.w #$201,d7          ;Increases the volume register (low byte), and frequency register (mandatory!).
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;        ret
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
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
;        movex.b (a1),PLY_AKYst_PsgRegister6
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise:

        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        moveym d7,$ffff8800
        moveym d1,$ffff8802
;        addq.w #1,a1    ;Increases the volume register.
        addq.w #1,d7    ;Increases the volume register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

;The exporter here exports the period values as hi/lo instead of lo/hi
;even they get exported as individual dc.b staements.
;That's not how big endian works!
;So for now I'll read the bytes in reverse order and compensate using addq.w #2 below
        ;Reads the software period.
        move.b (a1),d1
        addq.w #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
                ;move.w a1,d7     ;can trash d7 as it's not used for now
                ;lsr.w #8,d7
                moveymw d7,$ffff8800
                moveym d1,$ffff8802
;                add.w #1<<8,a1  ;Increases the frequency register.
                add.w #1<<8,d7  ;Increases the frequency register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        move.b (a1)+,d1
;        move.b (a1),d1
;        addq.w #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
        moveym d1,$ffff8802
;        add.w #1<<8,a1          ;Increases the frequency register.
        add.w #1<<8,d7          ;Increases the frequency register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        rts




;---------------------
PLY_AKYst_RRB_IS_SoftwareAndHardware:
        
        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Retrig
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrig
PLY_AKYst_RRB_IS_SAH_Retrig:
        bset #7,d1                      ;A value to make sure the retrig is performed, yet d1 can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrig:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Noise
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoise
PLY_AKYst_RRB_IS_SAH_Noise:
        ;Reads the noise.
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
;        movex.b (a1),PLY_AKYst_PsgRegister6
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
PLY_AKYst_RRB_IS_SAH_AfterNoise:

        ;The envelope.
        and.b #%1111,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Reads the software period.
        move.b (a1)+,d1
;        move.b (a1),d1
;        addq.l #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
        moveym d1,$ffff8802
                
;        add.w #1<<8,a1          ;Increases the frequency register.
        add.w #1<<8,d7          ;Increases the frequency register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        move.b (a1)+,d1
;        move.b (a1),d1
;        addq.w #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
                ;move.w a1,d7    ;can trash d7 as it's not used for now
                ;lsr.w #8,d7
                moveymw d7,$ffff8800
                moveym d1,$ffff8802

;                add.w #1<<8,a1  ;Increases the frequency register.
                add.w #1<<8,d7  ;Increases the frequency register.

                ;move.w a1,d7    ;can trash d7 as it's not used for now
                moveym d7,$ffff8800
;                moveym d3,$ffff8802     ;(volume to 16).
                moveym d4,$ffff8802     ;(volume to 16).

;                addq.w #1,a1    ;Increases the volume register.
                addq.w #1,d7    ;Increases the volume register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        ;Copies the hardware period.
;        ldi
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1
;        movex.b (a1),PLY_AKYst_PsgRegister11
;        movex.b 1(a1),PLY_AKYst_PsgRegister11+1
;        addq.w #2,a1
;        addq.w #2,d2
;        subq.w #2,d3
        rts





;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKYst_RRB_NonInitialState:

        ; Code from the start of PLY_AKYst_ReadRegisterBlock copied here so nothing will screw with the carry flag        
        move.b (a1)+,d1
;        move.b (a1),d1
;        addq.w #1,a1

        ;Not in the original code, but simplifies the stabilization.
;        ror.w #8,d2                     ;d1 must be saved!
        move.b d1,d2
;        ror.w #8,d2
;        and.b #%00001111,d1             ;Keeps 4 bits to be able to detect the loop. (%1000)
        and.b #%00001111,d2             ;Keeps 4 bits to be able to detect the loop. (%1000)
;        add.b d1,d1
        add.b d2,d2
;        move.b d1,d2

;        move.w d2,d1                    ;Retrieves A, which is supposed to be shifted in the original code.
;        lsr.w #8,d1
        lsr.b #2,d1
;        and.w #$ff,d2
        ext.w d2
        lea PLY_AKYst_NIS_JPTable(pc),a5
        add.w PLY_AKYst_NIS_JPTable(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTable:

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware-PLY_AKYst_NIS_JPTable          ;%0000
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly-PLY_AKYst_NIS_JPTable                  ;%0001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly-PLY_AKYst_NIS_JPTable                  ;%0010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware-PLY_AKYst_NIS_JPTable           ;%0011

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware-PLY_AKYst_NIS_JPTable          ;%0100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly-PLY_AKYst_NIS_JPTable                  ;%0101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly-PLY_AKYst_NIS_JPTable                  ;%0110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware-PLY_AKYst_NIS_JPTable           ;%0111
        
        dc.w PLY_AKYst_RRB_NIS_ManageLoop-PLY_AKYst_NIS_JPTable                    ;%1000. Loop!
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly-PLY_AKYst_NIS_JPTable                  ;%1001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly-PLY_AKYst_NIS_JPTable                  ;%1010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware-PLY_AKYst_NIS_JPTable           ;%1011
        
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware-PLY_AKYst_NIS_JPTable          ;%1100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly-PLY_AKYst_NIS_JPTable                  ;%1101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly-PLY_AKYst_NIS_JPTable                  ;%1110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware-PLY_AKYst_NIS_JPTable           ;%1111
        

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
;        move.b (a1),d1
;        addq.w #1,a1
        
        ;Reads the next NIS state. We know there won't be any loop.
;        ror.w #8,d2
        move.b d1,d2                    ;d1 must be saved!
;        ror.w #8,d2
;        and.b #%00000011,d1
        and.b #%00000011,d2
;        add.b d1,d1
        add.b d2,d2
;        move.b d1,d2

;        move.w d2,d1                    ;Retrieves A, which is supposed to be shifted in the original code.
;        lsr.w #8,d1
        lsr.b #2,d1
;        andi.w #$ff,d2
        ext.w d2
        lea PLY_AKYst_NIS_JPTable_NoLoop(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoop(pc,a5.w)




        ;This table jumps at each state, but AFTER the loop compensation.
PLY_AKYst_NIS_JPTable_NoLoop:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop-PLY_AKYst_NIS_JPTable_NoLoop     ;%00
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_Loop-PLY_AKYst_NIS_JPTable_NoLoop             ;%01
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_Loop-PLY_AKYst_NIS_JPTable_NoLoop             ;%10
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop-PLY_AKYst_NIS_JPTable_NoLoop      ;%11
        
        


PLY_AKYst_RRB_NIS_NoSoftwareNoHardware:                 ;60 + LoopCompensation cycles.
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop:            ;60 cycles.
        ;No software, no hardware.
        ;NO NEED to test the loop! It has been tested before. We can optimize from the original code.
        move.b d1,d2            ;Used below.

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit+8,d3

        ;Volume? bit 2 - 2.
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Volume
        bra.s PLY_AKYst_RRB_NIS_AfterVolume
PLY_AKYst_RRB_NIS_Volume:
        and.b #%1111,d1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
       ;move.w a1,d7    ;can trash d7 as it's not used for now
       moveym d7,$ffff8800
       moveym d1,$ffff8802
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
PLY_AKYst_RRB_NIS_AfterVolume:

        ;Sadly, have to lose a bit of CPU here, as this must be done in all cases.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;        add.w #$201,a1          ;Next volume register (low byte) and frequency registers (high byte)
        add.w #$201,d7          ;Next volume register (low byte) and frequency registers (high byte)
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        ;Noise? Was on bit 7, but there has been two shifts. We can't use A, it may have been modified by the volume AND.
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_Noise
        rts
PLY_AKYst_RRB_NIS_Noise:
        ;Noise.
        move.b (a1),d1
        movex.b d1,PLY_AKYst_PsgRegister6
        addq.w #1,a1
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
        rts






;---------------------
PLY_AKYst_RRB_NIS_SoftwareOnly:
PLY_AKYst_RRB_NIS_SoftwareOnly_Loop:                    ;129 cycles.
        
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        move.b d1,d2
        ;Gets the volume (already shifted).
        and.b #%1111,d1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        moveym d7,$ffff8800
        moveym d1,$ffff8802
;               addq.w #1,a1     ;Increases the volume register.
               addq.w #1,d7     ;Increases the volume register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSP
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP
PLY_AKYst_RRB_NIS_SoftwareOnly_LSP:
        move.b (a1),d1
        addq.w #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
        moveym d1,$ffff8802
                ;a1 high byte not incremented on purpose.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;        add.w #2<<8,a1
        add.w #2<<8,d7
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;        ret
        rts
        
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise:   ;53 cycles.           
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        move.b (a1),d1  ;Useless bits at the end, not a problem.
        addq.w #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;                ;Sends the MSB software frequency.
;        add.w #1<<8,a1          ;Was not increased before.
        add.w #1<<8,d7          ;Was not increased before.

        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
        moveym d1,$ffff8802

;        add.w #1<<8,a1          ;Increases the frequency register.
        add.w #1<<8,d7          ;Increases the frequency register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        
        rol.b #1,d1             ;Carry is isNoise?
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent:
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
       
        ;Is there a new noise value? If yes, gets the noise.
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_Noise
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_Noise:
        ;Gets the noise.
;       ldi        
        movex.b (a1),PLY_AKYst_PsgRegister6
;        movex.b (a1)+,PLY_AKYst_PsgRegister6
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
        rts


;---------------------
PLY_AKYst_RRB_NIS_HardwareOnly:

PLY_AKYst_RRB_NIS_HardwareOnly_Loop:

        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rol.b #1,d1
        move.b d1,d2
        and.b #%1110,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit+8,d3

        ;Hardware volume.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
;        moveym d3,$ffff8802
        moveym d4,$ffff8802

;                inc l           ;Increases the volume register.

;                inc h           ;Increases the frequency register.
;                inc h
;        add.w #$201,a1          ;Increases the volume register (low byte), frequency register (high byte)
        add.w #$201,d7          ;Increases the volume register (low byte), frequency register (high byte)
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

;        ld a,e
        move.b d2,d1

        ;LSB for hardware period? Currently on b6.
;        rla
        rol.b #1,d1
;        rla
        rol.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_HardwareOnly_LSB
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSB
;        jr PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB
PLY_AKYst_RRB_NIS_HardwareOnly_LSB:
;        ld de,PLY_AKYst_PsgRegister11
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister11
;        movex.b (a1),PLY_AKYst_PsgRegister11
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB:

        ;MSB for hardware period?
;        rla
        rol.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_HardwareOnly_MSB
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSB
;        jr PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB
PLY_AKYst_RRB_NIS_HardwareOnly_MSB:
;        ld de,PLY_AKYst_PsgRegister12
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister12
;        movex.b (a1),PLY_AKYst_PsgRegister12
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB:
        
        ;Noise or retrig?
;        rla
        rol.b #1,d1
;        jp c,PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop          ;The retrig/noise code is shared.
        bcs PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
;        ret
        rts


;---------------------
PLY_AKYst_RRB_NIS_SoftwareAndHardware:

PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop:             ;182 cycles.

                ;This is the longest! So nothing to wait.
                ;ds PLY_AKYst_NOP_LongestInState - 182, 0         ;For all the IS/NIS subcodes to spend the same amount of time.
        

        ;Hardware volume.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
                ;Sends the volume.
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        moveym d7,$ffff8800
;        moveym d3,$ffff8802     ;(16 = hardware volume).
        moveym d4,$ffff8802     ;(16 = hardware volume).
;        addq.w #1,a1            ;Increases the volume register.
        addq.w #1,d7            ;Increases the volume register.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        ;LSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBH
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBH
PLY_AKYst_RRB_NIS_SAHH_LSBH:
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister11
;        movex.b (a1),PLY_AKYst_PsgRegister11
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
PLY_AKYst_RRB_NIS_SAHH_AfterLSBH:

        ;MSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBH
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBH
PLY_AKYst_RRB_NIS_SAHH_MSBH:
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister12
;        movex.b (a1),PLY_AKYst_PsgRegister12
;        addq.w #1,a1
;        addq.w #1,d2
;        subq.w #1,d3
PLY_AKYst_RRB_NIS_SAHH_AfterMSBH:
        
        ;LSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBS
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBS
PLY_AKYst_RRB_NIS_SAHH_LSBS:
        move.b d1,d2
        move.b (a1),d1
        addq.w #1,a1
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
        moveym d1,$ffff8802
                ;a1 high byte not increased on purpose.
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        move.b d2,d1
PLY_AKYst_RRB_NIS_SAHH_AfterLSBS:
       
        ;MSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBS
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBS
PLY_AKYst_RRB_NIS_SAHH_MSBS:
        move.b d1,d2
        move.b (a1),d1
        addq.w #1,a1
;       exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;                ;Sends the MSB software frequency.
;        add.w #1<<8,a1
        add.w #1<<8,d7

        ;move.w a1,d7    ;can trash d7 as it's not used for now
        ;lsr.w #8,d7
        moveymw d7,$ffff8800
        moveym d1,$ffff8802

;                dec h           ;Yup. Will be compensated below.
;        sub.w #1<<8,a1
        sub.w #1<<8,d7
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
        move.b d2,d1
PLY_AKYst_RRB_NIS_SAHH_AfterMSBS:
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2
;        add.w #2<<8,a1
        add.w #2<<8,d7
;        exx
;        exg d3,d4
;        exg d2,d6
;        exg a1,a2

        ;New hardware envelope?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_Envelope
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope
PLY_AKYst_RRB_NIS_SAHH_Envelope:
;        ldi
        movex.b (a1)+,PLY_AKYst_PsgRegister13
        ;movex.b (a1),PLY_AKYst_PsgRegister13
        ;addq.w #1,a1
        ;addq.w #1,d2
        ;subq.w #1,d3
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope:

        ;Retrig and/or noise?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
        rts

        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop:
        ;Noise or retrig. Reads the next byte.
        move.b (a1),d1
        addq.w #1,a1

        ;Retrig?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Retrig
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig
PLY_AKYst_RRB_NIS_S_NOR_Retrig:
        bset #7,d1                      ;A value to make sure the retrig is performed, yet d1 can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig:

        ;Noise? If no, nothing more to do.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Noise
        rts
PLY_AKYst_RRB_NIS_S_NOR_Noise:
        
        ;Noise. Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
        ;Is there a new noise value? If yes, gets the noise.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoise
        rts
PLY_AKYst_RRB_NIS_S_NOR_SetNoise:
        ;Sets the noise.
        movex.b d1,PLY_AKYst_PsgRegister6
        rts


;Some stored PSG registers.
PLY_AKYst_PsgRegister6: dc.b 0
PLY_AKYst_PsgRegister11: dc.b 0
PLY_AKYst_PsgRegister12: dc.b 0
PLY_AKYst_PsgRegister13: dc.b 0

