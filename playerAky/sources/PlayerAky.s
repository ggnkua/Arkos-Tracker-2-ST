;       Stabilized AKY music player - V1.0.
;       By Julien N�vo a.k.a. Targhan/Arkos.
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
;assuming that hl=a0
;assuming that sp=a6
;assuming that a=d1

;assuming that af=d3
;assuming that de=d2
;assuming that bc=d3
;assuming that bc'=d4

; Register mappings
; 

;PLY_AKYst_OPCODE_OR_A: equ #b7                        ;Opcode for "or a".
;PLY_AKYst_OPCODE_SCF: equ #37                         ;Opcode for "scf".
PLY_AKYst_OPCODE_OR_A equ $00000000                  ;Opcode for "ori.b #0,d0".
PLY_AKYst_OPCODE_SCF  equ $003c0001                         ;Opcode for "ori #1,d0".

;PLY_AKYst_NOP_Loop: equ 35                           ;How much is spent because of the looping.
;PLY_AKYst_NOP_LongestInState: equ 182                ;The longest CPU sent in an IS/NIS subcode.

PLY_AKYst_Start:
        ;Hooks for external calls. Can be removed if not needed.
        bra.s PLY_AKYst_Init            ;Player + 0.
        bra.s PLY_AKYst_Play            ;Player + 2.
    


;       Initializes the player.
;       HL = music address.
*       a0.l = music address
PLY_AKYst_Init:
        ;Skips the header.
;        inc hl                          ;Skips the format version.
        addq.l #1,a0                    ;Skips the format version.
;        ld a,(hl)                       ;Channel count.
;        inc hl
        move.b (a0)+,d1                 ;Let's say that d1=accumulator
;        ld de,4
        move.w #4,d2                    ;Let's say that d2=de
PLY_AKYst_Init_SkipHeaderLoop:                ;There is always at least one PSG to skip.
;        add hl,de
        addq.l #4,a0
;        sub 3                           ;A PSG is three channels.
        subq.b #3,d0                    ;A PSG is three channels.
;        jr z,PLY_AKYst_Init_SkipHeaderEnd
        blt.s PLY_AKYst_Init_SkipHeaderEnd
;        jr nc,PLY_AKYst_Init_SkipHeaderLoop   ;Security in case of the PSG channel is not a multiple of 3.
        bcc.s PLY_AKYst_Init_SkipHeaderLoop
PLY_AKYst_Init_SkipHeaderEnd:
;        ld (PLY_AKYst_PtLinker + 1),hl        ;HL now points on the Linker.
        move.l  a0,PLY_AKYst_PtLinker       ;HL now points on the Linker.

;        ld a,PLY_AKYst_OPCODE_OR_A
        move.l #PLY_AKYst_OPCODE_OR_A,d0
;        ld (PLY_AKYst_Channel1_RegisterBlockLineState_Opcode),a
        move.l d0,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
;        ld (PLY_AKYst_Channel2_RegisterBlockLineState_Opcode),a
        move.l d0,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
;        ld (PLY_AKYst_Channel3_RegisterBlockLineState_Opcode),a
        move.l d0,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
;        ld hl,1
;        ld (PLY_AKYst_PatternFrameCounter + 1),hl
        move.w #2,PLY_AKYst_PatternFrameCounter

;        ret
        rts

;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
; a0=hl=start of tune - must be aligned to 64k for now!

PLY_AKYst_Play:
        move.l a0,a6                                ;copy the upper 16 bits to a6 - we'll need it later
;        ld (PLY_AKYst_Exit + 1),sp

;Linker.
;----------------------------------------
;PLY_AKYst_PatternFrameCounter: ld hl,1                ;How many frames left before reading the next Pattern.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PatternFrameCounter: move.w #1,d0             ;How many frames left before reading the next Pattern.
;        dec hl
;        ld a,l
;        or h
        cmp.w #0,a0
;        jr z,PLY_AKYst_PatternFrameCounter_Over
        beq.s PLY_AKYst_PatternFrameCounter_Over
;        ld (PLY_AKYst_PatternFrameCounter + 1),hl
        move.w a0,PLY_AKYst_PatternFrameCounter+2       ;*SMC galore!
        ;The pattern is not over.
;        jr PLY_AKYst_PatternFrameManagement_End
        bra.s PLY_AKYst_PatternFrameManagement_End

PLY_AKYst_PatternFrameCounter_Over:

;The pattern is over. Reads the next one.
;PLY_AKYst_PtLinker: ld sp,0                             ;Points on the Pattern of the linker.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PtLinker = * + 2
                    move.w #0,a6                        ;Points on the Pattern of the linker.
                                                        ;*assuming sp=a0
;        pop hl                                          ;Gets the duration of the Pattern, or 0 if end of the song.
        move.w (a6)+,a0
;        ld a,l
;        or h
        cmp.w #0,a0
;        jr nz,PLY_AKYst_LinkerNotEndSong
        bgt.s PLY_AKYst_LinkerNotEndSong
        ;End of the song. Where to loop?
;        pop hl
        move.w (a6)+,a0
        ;We directly point on the frame counter of the pattern to loop to.
;        ld sp,hl
        move.w a0,a6
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
;        pop hl
        move.w (a6)+,a0
;        jr PLY_AKYst_LinkerNotEndSong_After
PLY_AKYst_LinkerNotEndSong:
;        ld (PLY_AKYst_PatternFrameCounter + 1),hl
        move.w a0,PLY_AKYst_PatternFrameCounter + 2

;        pop hl
;        ld (PLY_AKYst_Channel1_PtTrack + 1),hl
        move.w (a6)+,PLY_AKYst_Channel1_PtTrack
;        pop hl
;        ld (PLY_AKYst_Channel2_PtTrack + 1),hl
        move.w (a6)+,PLY_AKYst_Channel2_PtTrack+2
;        pop hl
;        ld (PLY_AKYst_Channel3_PtTrack + 1),hl
        move.w (a6)+,PLY_AKYst_Channel3_PtTrack+2
;        ld (PLY_AKYst_PtLinker + 1),sp
        move.l a6,PLY_AKYst_PtLinker

        ;Resets the RegisterBlocks of the channels.
;        ld a,1
        moveq #1,d1
;        ld (PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock + 1),a
        move.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock
;        ld (PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock + 1),a
        move.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock
;        ld (PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock + 1),a
        move.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock + 3
PLY_AKYst_PatternFrameManagement_End:

;Reading the Track - channel 1.
;----------------------------------------
;PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        ;dec a
        subq.b #1,d1
;        jr z,PLY_AKYst_Channel1_RegisterBlock_Finished
        blt.s PLY_AKYst_Channel1_RegisterBlock_Finished
;        jr PLY_AKYst_Channel1_RegisterBlock_Process
        bra.s PLY_AKYst_Channel1_RegisterBlock_Process
PLY_AKYst_Channel1_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
;        ld a,PLY_AKYst_OPCODE_OR_A
        move.l #PLY_AKYst_OPCODE_OR_A,d1
;        ld (PLY_AKYst_Channel1_RegisterBlockLineState_Opcode),a
        move.l d1,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
;PLY_AKYst_Channel1_PtTrack: ld sp,0                   ;Points on the Track.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtTrack = * + 4
PLY_AKYst_Channel1_PtTrack: suba.w a6,a6                ;Clear lower word for the add to work properly
                                                        ;(i.e. we don't want to sign extend the 16 high bits
                            add.w #0,a6               ;Points on the Track.
;        dec sp                                  ;Only one byte is read. Compensate.
        subq.w #1,a6
;        pop af                                  ;Gets the duration.
        move.w (a6)+,d3                          ;assuming that af=d3
;        pop hl                                  ;Reads the RegisterBlock address.
        move.w (a6)+,a0

;        ld (PLY_AKYst_Channel1_PtTrack + 1),sp
        move.w a6,PLY_AKYst_Channel1_PtTrack
;        ld (PLY_AKYst_Channel1_PtRegisterBlock + 1),hl
        move.w a0,PLY_AKYst_Channel1_PtRegisterBlock

        ;A is the duration of the block.
PLY_AKYst_Channel1_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
;        ld (PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock + 1),a
        move.b d0,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock



;Reading the Track - channel 2.
;----------------------------------------
;PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
;        dec a
        subq.b #1,d1       
;        jr z,PLY_AKYst_Channel2_RegisterBlock_Finished
        blt.s PLY_AKYst_Channel2_RegisterBlock_Finished
;                ld b,6                  ;26 cycles.
;                djnz $
;                nop
;        jr PLY_AKYst_Channel2_RegisterBlock_Process
        bra.s PLY_AKYst_Channel2_RegisterBlock_Process
PLY_AKYst_Channel2_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
;        ld a,PLY_AKYst_OPCODE_OR_A
        move.l #PLY_AKYst_OPCODE_OR_A,d1
;        ld (PLY_AKYst_Channel2_RegisterBlockLineState_Opcode),a
        move.l d1,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
;PLY_AKYst_Channel2_PtTrack: ld sp,0                   ;Points on the Track.
PLY_AKYst_Channel2_PtTrack: suba.w a6,a6                    ;Points on the Track.
;        dec sp                                  ;Only one byte is read. Compensate.
        subq.w #1,d0
;        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        move.w (a0)+,d3
;        pop hl                                  ;Reads the RegisterBlock address.
        move.w (a0)+,d0

;        ld (PLY_AKYst_Channel2_PtTrack + 1),sp
        move.l a0,(PLY_AKYst_Channel2_PtTrack + 2)
;        ld (PLY_AKYst_Channel2_PtRegisterBlock + 1),hl
        move.w d0,(PLY_AKYst_Channel2_PtRegisterBlock + 2)
        ;A is the duration of the block.
PLY_AKYst_Channel2_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
;        ld (PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock + 1),a
        move.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock




;Reading the Track - channel 3.
;----------------------------------------
;PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock: move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
;        dec a
        subq.w #1,d1
;        jr z,PLY_AKYst_Channel3_RegisterBlock_Finished
        blt.s PLY_AKYst_Channel3_RegisterBlock_Finished
;                ld b,6                  ;26 cycles.
;                djnz $
;                nop
;        jr PLY_AKYst_Channel3_RegisterBlock_Process
        bra.s PLY_AKYst_Channel3_RegisterBlock_Process
PLY_AKYst_Channel3_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
;        ld a,PLY_AKYst_OPCODE_OR_A
        move.l #PLY_AKYst_OPCODE_OR_A,d1
;        ld (PLY_AKYst_Channel3_RegisterBlockLineState_Opcode),a
        move.l d1,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
;PLY_AKYst_Channel3_PtTrack: ld sp,0                   ;Points on the Track.
PLY_AKYst_Channel3_PtTrack: lea 0,a0                    ;Points on the Track.
;        dec sp                                  ;Only one byte is read. Compensate.
        subq.w #1,a0
;        pop af                                  ;Gets the duration (b1-7). b0 = silence block?
        move.w (a0)+,d3
;        pop hl                                  ;Reads the RegisterBlock address.
        move.w (a0)+,d0

;        ld (PLY_AKYst_Channel3_PtTrack + 1),sp
        move.l a0,(PLY_AKYst_Channel3_PtTrack + 2)
;        ld (PLY_AKYst_Channel3_PtRegisterBlock + 1),hl
        move.w d0,(PLY_AKYst_Channel3_PtRegisterBlock + 2)
        ;A is the duration of the block.
PLY_AKYst_Channel3_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        ;ld (PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock + 1),a
        move.b d1,(PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock + 3)











;Reading the RegisterBlock.
;----------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------

                ;ld hl,0 * 256 + 8                       ;H = first frequency register, L = first volume register.
                move.w #0 * 256 + 8,d1                       ;H = first frequency register, L = first volume register.
                ;ld de,#f4f6
                move.w #$f4f6,d2                         ;assuming that de=d2
                ;ld bc,#f690                             ;#90 used for both #80 for the PSG, and volume 16!
                move.w #$f690,d3                         ;assuming that bc=d3
        
                ;ld a,#c0                                ;Used for PSG.
                move.w #$c0,d1                          ;Used for PSG.
                ;out (c),a                               ;f6c0. Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
* From what I understand on the amstrad one has to write to a port to first enable writing to the psg. We don't need this since we have direct memory map                
        ;ex af,af'
        ;exx
* So the 2 instructions above seem to swap internal registers (z80 apparently has af/af', bc/bc', de/de', hl/hl')
* which means that we'll simply use different 68k registers below)

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
;        ld bc,%11100000 * 256 + 255                     ;C is 255 to prevent the following LDIs to decrease B.
        move.w #%11100000 * 256 + 255,d4                 ;assuming that bc'=d4

;        ld sp,PLY_AKYst_RetTable_ReadRegisterBlock
        move.l #PLY_AKYst_Channel1_RegisterBlock_Return,a0  ;so the above sets the return address to the label we have here by modifying the stack. Let's not use that thing for now (or ever)

;PLY_AKYst_Channel1_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtRegisterBlock = * + 2
        move.w #0,d0               ;Points on the data of the RegisterBlock to read.
;PLY_AKYst_Channel1_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
PLY_AKYst_Channel1_RegisterBlockLineState_Opcode: ori.b #0,d0  ;yeah well, the best substitution I can think of right now is ori.b #0,d0 / ori #1,ccr
;        jp PLY_AKYst_ReadRegisterBlock
        bra PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel1_RegisterBlock_Return:
;        ld a,PLY_AKYst_OPCODE_SCF
        move.l #PLY_AKYst_OPCODE_SCF,d1
;        ld (PLY_AKYst_Channel1_RegisterBlockLineState_Opcode),a
        move.l d1,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
;        ld (PLY_AKYst_Channel1_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.
        move.w d0,PLY_AKYst_Channel1_PtRegisterBlock


;Reading the RegisterBlock - Channel 2
;----------------------------------------

        ;Shifts the R7 for the next channels.
;        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!
        move.w d3,d7     ;well, that's what we get for putting b into the high word
        lsr.w #1,d7
        move.b d3,d7
        move.w d7,d3    ;yeah this definitely could be done faster :)
        

;PLY_AKYst_Channel2_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKYst_Channel2_PtRegisterBlock: move.w #0,d0                ;Points on the data of the RegisterBlock to read.
;PLY_AKYst_Channel2_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
PLY_AKYst_Channel2_RegisterBlockLineState_Opcode: ori.b #0,d0
;        jp PLY_AKYst_ReadRegisterBlock
       bra PLY_AKYst_ReadRegisterBlock 
PLY_AKYst_Channel2_RegisterBlock_Return:
;        ld a,PLY_AKYst_OPCODE_SCF
        move.l #PLY_AKYst_OPCODE_SCF,d1
;        ld (PLY_AKYst_Channel2_RegisterBlockLineState_Opcode),a
        move.l d1,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
;        ld (PLY_AKYst_Channel2_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.
        move.w d0,PLY_AKYst_Channel2_PtRegisterBlock + 2        ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 3
;----------------------------------------

        ;Shifts the R7 for the next channels.
;        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.
        move.w d3,d7
        lsr.w #8,d7
        ror.b #1,d7
        lsl.w #8,d7
        and.w #$ff,d3
        or.w d7,d3          ;*lolololol

;PLY_AKYst_Channel3_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
PLY_AKYst_Channel3_PtRegisterBlock: move.w #0,d0                ;Points on the data of the RegisterBlock to read.
;PLY_AKYst_Channel3_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
PLY_AKYst_Channel3_RegisterBlockLineState_Opcode: ori.b #0,d0
;        jp PLY_AKYst_ReadRegisterBlock
        bra PLY_AKYst_ReadRegisterBlock
PLY_AKYst_Channel3_RegisterBlock_Return:
        ;ld a,PLY_AKYst_OPCODE_SCF
        move.l #PLY_AKYst_OPCODE_SCF,d1
;        ld (PLY_AKYst_Channel3_RegisterBlockLineState_Opcode),a
        move.l d1,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
;        ld (PLY_AKYst_Channel3_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.
        move.w d0,PLY_AKYst_Channel3_PtRegisterBlock + 2        ;This is new pointer on the RegisterBlock.

        ;Register 7 to A.
;        ld a,b
        move.w d3,d1
        lsr.w #8,d1

;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).

;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).
;        exx

;                inc h           ;Was 6, so now 7!
                add.w #1<<8,d0


;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
* I really think the above boils down to:
                move.b #7,$ffff8800.w
                move.b d1,$ffff8802.w

;Register 6
;                dec h
                sub.w #1<<8,d0

;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;
;                ld hl,PLY_AKYst_PsgRegister6
;                dec b           ; -1, not -2 because of OUTI does -1 before doing the out.
;                outi            ;f400 + value
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
* and again...
                move.b #6,$ffff8800.w
                move.b PLY_AKYst_PsgRegister6,$ffff8802.w

;Register 11
;                ld a,11         ;Next regiser
;
;                ld b,d
;                out (c),a       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                dec b
;                outi            ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
                move.b #11,$ffff8800.w
                move.b PLY_AKYst_PsgRegister11,$ffff8802.w
                

;Register 12
;                inc a           ;Next regiser
;
;                ld b,d
;                out (c),a       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                dec b
;                outi            ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
                move.b #12,$ffff8800.w
                move.b PLY_AKYst_PsgRegister12,$ffff8802.w


;Register 13
PLY_AKYst_PsgRegister13_Code:
;                ld a,(hl)
                move.b PLY_AKYst_PsgRegister13,d1
;PLY_AKYst_PsgRegister13_Retrig: cp 255                         ;If IsRetrig?, force the R13 to be triggered.
PLY_AKYst_PsgRegister13_Retrig: cmp #255,d1
;                jr nz,PLY_AKYst_PsgRegister13_Change
                blt.s PLY_AKYst_PsgRegister13_Change
;                        ld b,7                  ;30 cycles.
;                        djnz $
;                        nop
;                jr PLY_AKYst_PsgRegister13_End
                bra PLY_AKYst_PsgRegister13_End
PLY_AKYst_PsgRegister13_Change:
;                ld (PLY_AKYst_PsgRegister13_Retrig + 1),a
                move.b PLY_AKYst_PsgRegister13_Retrig + 3,d1

;                ld b,d
;                ld l,13
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
                move.b #12,$ffff8800.w
                move.b d1,$ffff8802.w
PLY_AKYst_PsgRegister13_End:



;PLY_AKYst_Exit: ld sp,0
PLY_AKYst_Exit: ;ld sp,0
;        ret
        rts








;Generic code interpreting the RegisterBlock
;IN:    HL = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYst_ReadRegisterBlock:
        ;Gets the first byte of the line. What type? Jump to the matching code thanks to the carry.
;        ld a,(hl)
        move.w d0,a0
        move.b (a0),d1             ;* Yeah, that definitely won't work - that needs to be a valid address
;        inc hl
        addq.w #1,d0
;        jp c,PLY_AKYst_RRB_NonInitialState
        bcs PLY_AKYst_RRB_NonInitialState
        
        
        ;Not in the original code, but simplifies the stabilization.
;        ld d,a                  ;A must be saved!        
;        and %00000011
;        add a,a
;        add a,a
;        ld e,a
;        ld a,d                  ;Retrieves A, which is supposed to be shifted in the original code.
;        rra
;        rra
;        ld d,0
;        ld ix,PLY_AKYst_IS_JPTable
;        add ix,de
;        jp (ix)
;PLY_AKYst_IS_JPTable:
;        jp PLY_AKYst_RRB_IS_NoSoftwareNoHardware          ;%00
;        nop
;        jp PLY_AKYst_RRB_IS_SoftwareOnly                  ;%01
;        nop
;        jp PLY_AKYst_RRB_IS_HardwareOnly                  ;%10
;        nop
;        jp PLY_AKYst_RRB_IS_SoftwareAndHardware           ;%11
        move.b d1,d7
        ext.w d7
        add.w d7,d7
        lea PLY_AKYst_IS_JPTable(pc),a6
        jmp (a6,d7.w)
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
;        rra                     ;Noise?
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise
        move.w d0,a1                    ;* yes, this is going to explode
        cmp.b (a1),d1
;        jr PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise:
        ;There is a noise. Reads it.
;        ld de,PLY_AKYst_PsgRegister6
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;TODO increment hl, de and decrement bc
        move.w d0,a1                    ;* moar assplosions ahoy!
        move.b (a1),PLY_AKYst_PsgRegister6

        ;Opens the noise channel.
        ;res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d4  ;need to double check this! (as anything else I suppose) 
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End:
        
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolume:
        ;The volume is now in b0-b3.
        ;and %1111      ;No need, the bit 7 was 0.

;        exx
;                ;Sends the volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
;
;                inc l           ;Increases the volume register.
;                inc h           ;Increases the frequency register.
;                inc h
        move.w d4,d7
        lsr.w #8,d7
        move.b d0,$ffff8800.w   ;*these are probably wrong because of the exx
        move.b d1,$ffff8802.w
        add.w #(2<<8)+1,d0
;        exx
        ;Closes the sound channel.
;        set PLY_AKYst_RRB_SoundChannelBit, b
        bset #PLY_AKYst_RRB_SoundChannelBit+8, d3
;        ret
        rts


;---------------------
PLY_AKYst_RRB_IS_HardwareOnly:                          ;79 cycles.

        ;Retrig?
;        rra
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_IS_HO_Retrig
        bcs.s PLY_AKYst_RRB_IS_HO_Retrig
;        jr PLY_AKYst_RRB_IS_HO_AfterRetrig
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrig
PLY_AKYst_RRB_IS_HO_Retrig:
;        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        bset #7,d1
 ;       ld (PLY_AKYst_PsgRegister13_Retrig + 1),a
        move.b d1,PLY_AKYst_PsgRegister13_Retrig + 3
PLY_AKYst_RRB_IS_HO_AfterRetrig:

        ;Noise?
        ;rra
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_IS_HO_Noise
        bcs.s PLY_AKYst_RRB_IS_HO_Noise 
        move.w d0,a1
        cmp.b (a1),d1           ;* explody stuff
;        jr PLY_AKYst_RRB_IS_HO_AfterNoise
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoise
PLY_AKYst_RRB_IS_HO_Noise:        ;Reads the noise.
;        ld de,PLY_AKYst_PsgRegister6
        move.w #PLY_AKYst_PsgRegister6,d2 ;*bogus bogus bogus bogus
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister6
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3 
 
        ;Opens the noise channel.
        ;res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
PLY_AKYst_RRB_IS_HO_AfterNoise:

        ;The envelope.
;        and %1111
        and.b #%1111,d1
;        ld (PLY_AKYst_PsgRegister13),a
        move.b d1,PLY_AKYst_PsgRegister13

        ;Copies the hardware period.
;        ld de,PLY_AKYst_PsgRegister11
        lea PLY_AKYst_PsgRegister11,a1
;        ldi
;        ldi
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+1
        addq.w #1,d0
        addq.w #1,d2
        addq.w #1,d3

        ;Closes the sound channel.
        ;set PLY_AKYst_RRB_SoundChannelBit, b
        bset #PLY_AKYst_RRB_SoundChannelBit+8,d3

;        exx
;                ;Sets the hardware volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),c       ;f400 + value (volume to 16).
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'

        move.b d0,$ffff8800.w
        move.b d4,$ffff8802.w

;                inc l           ;Increases the volume register.
;                inc h           ;Increases the frequency register (mandatory!).
;                inc h
;        exx
;        ret
        rts

;---------------------
PLY_AKYst_RRB_IS_SoftwareOnly:                  ;112 cycles.

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
;        rra
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_IS_SoftwareOnly_Noise
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_Noise
        move.w d0,a1
        cmp.b (a1),d1   ;*yeah at this point we know that hl should probably be on an address register, roit?
;        jr PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise
PLY_AKYst_RRB_IS_SoftwareOnly_Noise:
        ;Noise. Reads it.
;        ld de,PLY_AKYst_PsgRegister6
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
;        res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise:

        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
;        exx
;                ;Sends the volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.b d0,$ffff8800.w   ;*wrong because of the exx
        move.b d1,$ffff8802.w
;                inc l           ;Increases the volume register.
        addq.b #1,d0            ;*wrong because of the exx
;        exx

        ;Reads the software period.
;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1       
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the LSB software frequency.
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
                move.w d0,d7  ;*wrong because of the exx
                lsr.w #8,d7
                move.b d7,$ffff8800.w
                move.b d1,$ffff8802.w
;                inc h           ;Increases the frequency register.
                add.w #1<<8,d0  ;*wrong because of the exx
;        exx

;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the MSB software frequency.
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d0,d7
        lsr.w #8,d7
        move.b d7,$ffff8800.w
        move.b d1,$ffff8802.w
;                inc h           ;Increases the frequency register.
        add.w #1<<8,d0
;        exx

;        ret
        rts




;---------------------
PLY_AKYst_RRB_IS_SoftwareAndHardware:                   ;139 cycles.
        
        ;Retrig?
;        rra
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_IS_SAH_Retrig
        bcs.s PLY_AKYst_RRB_IS_SAH_Retrig
;        jr PLY_AKYst_RRB_IS_SAH_AfterRetrig
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrig
PLY_AKYst_RRB_IS_SAH_Retrig:
;        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        bset #7,d1
;        ld (PLY_AKYst_PsgRegister13_Retrig + 1),a
        move.b d1,PLY_AKYst_PsgRegister13_Retrig+3
PLY_AKYst_RRB_IS_SAH_AfterRetrig:

        ;Noise?
;        rra
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_IS_SAH_Noise
        bcs.s PLY_AKYst_RRB_IS_SAH_Noise
;        jr PLY_AKYst_RRB_IS_SAH_AfterNoise
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoise
PLY_AKYst_RRB_IS_SAH_Noise:
        ;Reads the noise.
;        ld de,PLY_AKYst_PsgRegister6
;        ldi                     ;Safe for B, C is not 0. Preserves A.
        move.w d0,a1        ;*lolol
        move.w (a1),PLY_AKYst_PsgRegister6 
        ;Opens the noise channel.
;        res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
PLY_AKYst_RRB_IS_SAH_AfterNoise:

        ;The envelope.
;        and %1111
        and.b #%1111,d1
;        ld (PLY_AKYst_PsgRegister13),a
        move.b d1,PLY_AKYst_PsgRegister13

        ;Reads the software period.
;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.l #1,d1
;        exx
;                ;Sends the LSB software frequency.
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d0,d7
        lsr.w #8,d7
        move.b d7,$ffff8800.w
        move.b d1,$ffff8802.w
                
;                inc h           ;Increases the frequency register.
        add.w #1<<256,d1
;        exx

;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the MSB software frequency.
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
                move.w d0,d7
                lsr.w #8,d7
                move.b d7,$ffff8800.w
                move.b d1,$ffff8802.w

;                inc h           ;Increases the frequency register.
                add.w #1<<8,d0

;                ;Sets the hardware volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),c       ;f400 + value (volume to 16).
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
                move.b d1,$ffff8800.w
                move.b d3,$ffff8802.w

;                inc l           ;Increases the volume register.
                addq.b #1,d0
;        exx

        ;Copies the hardware period.
;        ld de,PLY_AKYst_PsgRegister11
;        ldi
;        ldi
        move.b (a1)+,PLY_AKYst_PsgRegister11
        move.b (a1)+,PLY_AKYst_PsgRegister11+1
        addq.w #1,d0
        addq.w #1,d2
        addq.w #1,d3
;        ret
        rts





;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKYst_RRB_NonInitialState:

        ;Not in the original code, but simplifies the stabilization.
;        ld d,a                          ;A must be saved!
        move.b d1,d7
;        and %00001111                   ;Keeps 4 bits to be able to detect the loop. (%1000)
        and.b #%00001111,d7
;        add a,a
        add.b d7,d7
;        add a,a
        add.b d7,d7
;        ld e,a
        move.b d7,d2

;        ld a,d                          ;Retrieves A, which is supposed to be shifted in the original code.
;        rra
;        rra
        lsr.b #2,d1
;        ld d,0
        and.w #$ff00,d2
;        ld ix,PLY_AKYst_NIS_JPTable
;        add ix,de
        lea PLY_AKYst_NIS_JPTable(pc),a6
        add.w PLY_AKYst_NIS_JPTable(pc,d2.w),a6
;        jp (ix)
        jmp (a6)
        ;All these codes consider there is no loop, so have a "wait" at the beginning. Except the "loop" code in %1000, which manages the loop...
PLY_AKYst_NIS_JPTable:
;        jp PLY_AKYst_RRB_NIS_NoSoftwareNoHardware          ;%0000
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareOnly                  ;%0001
;        nop
;        jp PLY_AKYst_RRB_NIS_HardwareOnly                  ;%0010
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareAndHardware           ;%0011
;        nop
;
;        jp PLY_AKYst_RRB_NIS_NoSoftwareNoHardware          ;%0100
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareOnly                  ;%0101
;        nop
;        jp PLY_AKYst_RRB_NIS_HardwareOnly                  ;%0110
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareAndHardware           ;%0111
;        nop
;        
;        jp PLY_AKYst_RRB_NIS_ManageLoop                    ;%1000. Loop!
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareOnly                  ;%1001
;        nop
;        jp PLY_AKYst_RRB_NIS_HardwareOnly                  ;%1010
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareAndHardware           ;%1011
;        nop
;        
;        jp PLY_AKYst_RRB_NIS_NoSoftwareNoHardware          ;%1100
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareOnly                  ;%1101
;        nop
;        jp PLY_AKYst_RRB_NIS_HardwareOnly                  ;%1110
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareAndHardware           ;%1111

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
;        ld a,(hl)
;        inc hl
;        ld h,(hl)
;        ld l,a
        move.w d0,a1
        move.w (a1),d0 ;*yup, bogus for now

        ;Makes another iteration to read the new data.
        ;Since we KNOW it is not an initial state (because no jump goes to an initial state), we can directly go to the right branching.
        ;Reads the first byte.
;        ld a,(hl)
;        inc hl
        move.w d0,a1
        move.b (a1),d1
        addq.w #1,d0
        
        ;Reads the next NIS state. We know there won't be any loop.
;        ld d,a                          ;A must be saved!
        move.b d1,d2
        lsl.w #8,d2
;        and %00000011                   ;Keeps 4 bits to be able to detect the loop. (%1000)
        and.w #%0000001111111111,d2
;        add a,a
        add.w d2,d2
;        add a,a
        add.w d2,d2
;        ld e,a
        move.b d1,d2

;        ld a,d                          ;Retrieves A, which is supposed to be shifted in the original code.
        move.b d7,d0
;        rra
;        rra
        lsr.b #2,d0
;        ld d,0
        andi.w #$ff,d2
;        ld ix,PLY_AKYst_NIS_JPTable_NoLoop
        lea PLY_AKYst_NIS_JPTable_NoLoop,a6
;        add ix,de
        add.w d2,a6
;        jp (ix)
        jmp (a6)
        ;This table jumps at each state, but AFTER the loop compensation.
PLY_AKYst_NIS_JPTable_NoLoop:
;        jp PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop     ;%00
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareOnly_Loop             ;%01
;        nop
;        jp PLY_AKYst_RRB_NIS_HardwareOnly_Loop             ;%10
;        nop
;        jp PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop      ;%11
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop-PLY_AKYst_NIS_JPTable_NoLoop     ;%00
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_Loop-PLY_AKYst_NIS_JPTable_NoLoop             ;%01
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_Loop-PLY_AKYst_NIS_JPTable_NoLoop             ;%10
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop-PLY_AKYst_NIS_JPTable_NoLoop      ;%11
        
        


PLY_AKYst_RRB_NIS_NoSoftwareNoHardware:                 ;60 + LoopCompensation cycles.
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop:            ;60 cycles.
        ;No software, no hardware.
        ;NO NEED to test the loop! It has been tested before. We can optimize from the original code.
;        ld e,a                  ;Used below.
        move.b d1,d0

        ;Closes the sound channel.
        ;set PLY_AKYst_RRB_SoundChannelBit, b
        bset #PLY_AKYst_RRB_SoundChannelBit+8,d3

        ;Volume? bit 2 - 2.
;        rra
        lsr.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_Volume
        bcs.s PLY_AKYst_RRB_NIS_Volume
;        jr PLY_AKYst_RRB_NIS_AfterVolume
        bra.s PLY_AKYst_RRB_NIS_AfterVolume
PLY_AKYst_RRB_NIS_Volume:
;        and %1111
        and.b #%1111,d1
;        exx
;                ;Sends the volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
;        exx
       move.b d0,$ffff8800.w
       move.b d1,$ffff8802.w 
PLY_AKYst_RRB_NIS_AfterVolume:

        ;Sadly, have to lose a bit of CPU here, as this must be done in all cases.
;        exx
;                inc l           ;Next volume register.
;                inc h           ;Next frequency registers.
;                inc h
;        exx
        add.w #$201,d0

        ;Noise? Was on bit 7, but there has been two shifts. We can't use A, it may have been modified by the volume AND.
        ;bit 7 - 2, e
        btst #7 - 2,d2
;        jr nz,PLY_AKYst_RRB_NIS_Noise
        blt.s PLY_AKYst_RRB_NIS_Noise
;        ret
        rts
PLY_AKYst_RRB_NIS_Noise:
        ;Noise.
;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        ld (PLY_AKYst_PsgRegister6),a
        move.b d1,PLY_AKYst_PsgRegister6
;        inc hl
        addq.w #1,d0
        ;Opens the noise channel.
;        res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
;        ret
        rts






;---------------------
PLY_AKYst_RRB_NIS_SoftwareOnly:
PLY_AKYst_RRB_NIS_SoftwareOnly_Loop:                    ;129 cycles.
        
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
;        ld e,a
        move.b d1,d2
        ;Gets the volume (already shifted).
;        and %1111
        and.b #%1111,d1
;        exx
;                ;Sends the volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.b d0,$ffff8800.w
        move.b d1,$ffff8802.w
;                inc l           ;Increases the volume register.
               addq.b #1,d0
;        exx

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
;        bit 6 - 2, e
        btst #6 - 2,d2
;        jr nz,PLY_AKYst_RRB_NIS_SoftwareOnly_LSP
        blt.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSP
;        jr PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP
PLY_AKYst_RRB_NIS_SoftwareOnly_LSP:
;        ld a,(hl)
        move.w d0,a1
        move.w (a1),d1
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the LSB software frequency.
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d6,$ffff8800.w ;high byte (register h) to 8800, low byte (register l) to 8801
        move.b d1,$ffff8802.w
                ;H not incremented on purpose.
;        exx
PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
;        bit 7 - 2, e
        btst #7 - 2,d2
;        jr nz,PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
        blt.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
        ;Bit of loss of CPU, but has to be done in all cases.
;        exx
;                inc h
;                inc h
;        exx
;        ret
        rts
        
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise:   ;53 cycles.           
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
;        ld a,(hl)       ;Useless bits at the end, not a problem.
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the MSB software frequency.
;                inc h           ;Was not increased before.
        add.w #1<<8,d0

;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d0,$ffff8800.w
        move.b d1,$ffff8802.w

;                inc h           ;Increases the frequency register.
        add.w #1<<8,d0
;        exx
        
;        rla     ;Carry is isNoise?
        rol.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent
;        ret
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent:
        ;Opens the noise channel.
;        res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
       
        ;Is there a new noise value? If yes, gets the noise.
;        rla
        rol.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SoftwareOnly_Noise
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_Noise
;        ret
        rts
PLY_AKYst_RRB_NIS_SoftwareOnly_Noise:
        ;Gets the noise.
;        ld de,PLY_AKYst_PsgRegister6
;        ldi
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister6
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3
;        ret
        rts


;---------------------
PLY_AKYst_RRB_NIS_HardwareOnly:

PLY_AKYst_RRB_NIS_HardwareOnly_Loop:            ;102 cycles.

                ;ds PLY_AKYst_NOP_LongestInState - 102, 0         ;For all the IS/NIS subcodes to spend the same amount of time.

        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
;        rla
        rol.b #1,d1
;        ld e,a
        move.b d1,d2
;        and %1110
        and.b #%1110,d1
;        ld (PLY_AKYst_PsgRegister13),a
        move.b d1,PLY_AKYst_PsgRegister13

        ;Closes the sound channel.
;        set PLY_AKYst_RRB_SoundChannelBit, b
        bset #PLY_AKYst_RRB_SoundChannelBit+8,d3

        ;Hardware volume.
;        exx
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),c       ;f400 + value (16, hardware volume).
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d0,$ffff8800.w
        move.b d3,$ffff8802.w

;                inc l           ;Increases the volume register.

;                inc h           ;Increases the frequency register.
;                inc h
        add.w #$201,d0
;        exx

;        ld a,e
        move.b d2,d1

        ;LSB for hardware period? Currently on b6.
;        rla
;        rla
        rol.b #2,d1
;        jr c,PLY_AKYst_RRB_NIS_HardwareOnly_LSB
        bcc.s PLY_AKYst_RRB_NIS_HardwareOnly_LSB
;        jr PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB
PLY_AKYst_RRB_NIS_HardwareOnly_LSB:
;        ld de,PLY_AKYst_PsgRegister11
;        ldi
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister11
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3
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
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister12
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB:
        
        ;Noise or retrig?
;        rla
        rol.b #1,d1
;        jp c,PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop          ;The retrig/noise code is shared.
        bcc PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
;        ret
        rts


;---------------------
PLY_AKYst_RRB_NIS_SoftwareAndHardware:

PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop:             ;182 cycles.

                ;This is the longest! So nothing to wait.
                ;ds PLY_AKYst_NOP_LongestInState - 182, 0         ;For all the IS/NIS subcodes to spend the same amount of time.
        

        ;Hardware volume.
;        exx
                ;Sends the volume.
;                ld b,d
;                out (c),l       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),c       ;f400 + value (16 = hardware volume).
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.b d0,$ffff8800.w
        move.b d3,$ffff8802.w
;                inc l           ;Increases the volume register.
        addq.w #1,d0
;        exx

        ;LSB of hardware period?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SAHH_LSBH
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBH
;        jr PLY_AKYst_RRB_NIS_SAHH_AfterLSBH
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBH
PLY_AKYst_RRB_NIS_SAHH_LSBH:
;        ld de,PLY_AKYst_PsgRegister11
;        ldi
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister11
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3
PLY_AKYst_RRB_NIS_SAHH_AfterLSBH:

        ;MSB of hardware period?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SAHH_MSBH
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBH
;        jr PLY_AKYst_RRB_NIS_SAHH_AfterMSBH
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBH
PLY_AKYst_RRB_NIS_SAHH_MSBH:
;        ld de,PLY_AKYst_PsgRegister12
;        ldi
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister12
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3
PLY_AKYst_RRB_NIS_SAHH_AfterMSBH:
        
        ;LSB of software period?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SAHH_LSBS
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBS
;        jr PLY_AKYst_RRB_NIS_SAHH_AfterLSBS
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBS
PLY_AKYst_RRB_NIS_SAHH_LSBS:
;        ld e,a
        move.b d1,d2
;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the LSB software frequency.
;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d0,$ffff8800.w
        move.b d1,$ffff8802.w
                ;H not increased on purpose.
;        exx
;        ld a,e
        move.b d2,d1
PLY_AKYst_RRB_NIS_SAHH_AfterLSBS:
       
        ;MSB of software period?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SAHH_MSBS
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBS
;        jr PLY_AKYst_RRB_NIS_SAHH_AfterMSBS
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBS
PLY_AKYst_RRB_NIS_SAHH_MSBS:
;        ld e,a
        move.b d1,d2
;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.w #1,d0
;        exx
;                ;Sends the MSB software frequency.
;                inc h
        add.w #1<<8,d0

;                ld b,d
;                out (c),h       ;f400 + register.
;                ld b,e
;                out (c),0       ;f600.
;                ld b,d
;                out (c),a       ;f400 + value.
;                ld b,e
;                out (c),c       ;f680
;                ex af,af'
;                out (c),a       ;f6c0.
;                ex af,af'
        move.w d0,$ffff8800.w
        move.b d1,$ffff8802.w

;                dec h           ;Yup. Will be compensated below.
        sub.w #1<<8,d0
;        exx
;        ld a,e
        move.b d2,d1
PLY_AKYst_RRB_NIS_SAHH_AfterMSBS:
        ;A bit of loss of CPU, but this has to be done every time!
;        exx
;                inc h
;                inc h
;        exx

        ;New hardware envelope?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_SAHH_Envelope
        bcs.s PLY_AKYst_RRB_NIS_SAHH_Envelope
;        jr PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope
PLY_AKYst_RRB_NIS_SAHH_Envelope:
;        ld de,PLY_AKYst_PsgRegister13
;        ldi
        move.w d0,a1
        move.b (a1),PLY_AKYst_PsgRegister13
        addq.w #1,d0
        addq.w #1,d2
        subq.w #1,d3
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope:

        ;Retrig and/or noise?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop
;        ret
        rts

        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop:              ;31 cycles
        ;Noise or retrig. Reads the next byte.
;        ld a,(hl)
        move.w d0,a1
        move.b (a1),d1
;        inc hl
        addq.w #1,d0

        ;Retrig?
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_S_NOR_Retrig
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Retrig
;        jr PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig
PLY_AKYst_RRB_NIS_S_NOR_Retrig:
;        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        bset #7,d1
;        ld (PLY_AKYst_PsgRegister13_Retrig + 1),a
        move.b d1,PLY_AKYst_PsgRegister13_Retrig + 3
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig:

        ;Noise? If no, nothing more to do.
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_S_NOR_Noise
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Noise
;        ret
        rts
PLY_AKYst_RRB_NIS_S_NOR_Noise:
        
        ;Noise. Opens the noise channel.
;        res PLY_AKYst_RRB_NoiseChannelBit, b
        bclr #PLY_AKYst_RRB_NoiseChannelBit+8,d3
        ;Is there a new noise value? If yes, gets the noise.
;        rra
        ror.b #1,d1
;        jr c,PLY_AKYst_RRB_NIS_S_NOR_SetNoise
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoise
;        ret
        rts
PLY_AKYst_RRB_NIS_S_NOR_SetNoise:
        ;Sets the noise.
;        ld (PLY_AKYst_PsgRegister6),a
        move.b d1,PLY_AKYst_PsgRegister6
;        ret
        rts


;Some stored PSG registers.
;PLY_AKYst_PsgRegister6: db 0
;PLY_AKYst_PsgRegister11: db 0
;PLY_AKYst_PsgRegister12: db 0
;PLY_AKYst_PsgRegister13: db 0
PLY_AKYst_PsgRegister6: dc.b 0
PLY_AKYst_PsgRegister11: dc.b 0
PLY_AKYst_PsgRegister12: dc.b 0
PLY_AKYst_PsgRegister13: dc.b 0


;RET table for the Read RegisterBlock code to know where to return.
;PLY_AKYst_RetTable_ReadRegisterBlock:
;        dw PLY_AKYst_Channel1_RegisterBlock_Return
;        dw PLY_AKYst_Channel2_RegisterBlock_Return
;        dw PLY_AKYst_Channel3_RegisterBlock_Return
