;       Arkos Tracker 2 player.

;       By Targhan/Arkos, December 2017.
;       Psg optimization trick on CPC by Madram/Overlanders.

;       Note:
;       - There can be a slightly difference when using volume in/out effects compared to the PC side, because the volume management is
;         different. This means there can be a difference of 1 at certain frames. As it shouldn't be a bother, I let it this way.
;         This allows the Z80 code to be faster and simpler.

;       Optimizations:
;       - Memory: you can remove the three hooks just below to save 9 bytes (yay!).
;       - Memory: remove the code at PLY_AKG_Stop if you don't indent to stop the music.
;       - Memory/CPU: set PLY_AKG_MANAGE_EVENTS to 0 if you don't use the events (or digidrums).
;       - Memory: if you play your song "one shot" (i.e. without restarting it again), you can set the PLY_AKG_FULL_INIT_CODE to 0, some
;         initialization code will not be assembled.
;       - Memory/CPU: make sure PLY_AKG_MANAGE_SOUND_EFFECTS is 0 (default) if you don't use the sound effects support.


PLY_AKG_Start:

PLY_AKG_MANAGE_SOUND_EFFECTS: equ 0                 ;Sound effects handled? Most of the time 0, unless you're working on a game.
PLY_AKG_MANAGE_EVENTS: equ 1                        ;1 to manage events. 0 to save a bit of memory and CPU if you don't need them.
PLY_AKG_FULL_INIT_CODE: equ 1                       ;0 to skip some init code/values, saving memory. Possible if you don't plan on restarting your song.

PLY_AKG_OPCODE_OR_A: equ #b7                        ;Opcode for "or a".
PLY_AKG_OPCODE_SCF: equ #37                         ;Opcode for "scf".
PLY_AKG_OPCODE_ADD_HL_BC_LSB: equ #09               ;Opcode for "add hl,bc", LSB.
PLY_AKG_OPCODE_ADD_HL_BC_MSB: equ #00               ;Opcode for "add hl,bc", MSB (fake, it is only 8 bits.
PLY_AKG_OPCODE_SBC_HL_BC_LSB: equ #42               ;Opcode for "sbc hl,bc", LSB.
PLY_AKG_OPCODE_SBC_HL_BC_MSB: equ #ed               ;Opcode for "sbc hl,bc", MSB.
PLY_AKG_OPCODE_ADD_A_IMMEDIATE: equ #c6             ;Opcode for "add a,x".
PLY_AKG_OPCODE_SUB_IMMEDIATE: equ #d6               ;Opcode for "sub x".
PLY_AKG_OPCODE_INC_HL: equ #23                      ;Opcode for "inc hl".
PLY_AKG_OPCODE_DEC_HL: equ #2b                      ;Opcode for "dec hl".

        ;Hooks for external calls. Can be removed if not needed.
        jp PLY_AKG_Init          ;PLY_AKG_Start + 0.
        jp PLY_AKG_Play          ;PLY_AKG_Start + 3.
        jp PLY_AKG_Stop          ;PLY_AKG_Start + 6.
        
;Initializes the player.
;IN:    HL = music address.
;       A = subsong index (>=0).
PLY_AKG_Init:
        ;Skips the tag.
        ld de,4
        add hl,de

        ld de,PLY_AKG_ArpeggiosTable + 1
        ldi
        ldi
        ld de,PLY_AKG_PitchesTable + 1
        ldi
        ldi
        ld de,PLY_AKG_InstrumentsTable + 1
        ldi
        ldi
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (PLY_AKG_Channel_ReadEffects_EffectBlocks1 + 1),bc
        ld (PLY_AKG_Channel_ReadEffects_EffectBlocks2 + 1),bc
        
        ;We have reached the Subsong addresses. Which one to use?
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ;HL points on the Subsong metadata.
        ld de,5         ;Skips the replay frequency, digichannel, psg count, loop start index, end index.
        add hl,de
        ld de,PLY_AKG_CurrentSpeed + 1       ;Reads the initial speed (>0).
        ldi
        ld de,PLY_AKG_BaseNoteIndex + 1      ;Reads the base note of the note that is considered "optimized", contrary to "escaped".
        ldi
        ld (PLY_AKG_ReadLinker_PtLinker + 1),hl
        
        ;Initializes values. You can remove this part if you don't stop/restart your song.
        if PLY_AKG_FULL_INIT_CODE
                xor a
                ld hl,PLY_AKG_InitTable0
                ld b,(PLY_AKG_InitTable0_End - PLY_AKG_InitTable0) / 2
                call PLY_AKG_Init_ReadWordsAndFill
                inc a
                ld hl,PLY_AKG_InitTable1
                ld b,(PLY_AKG_InitTable1_End - PLY_AKG_InitTable1) / 2
                call PLY_AKG_Init_ReadWordsAndFill
                ld a,PLY_AKG_OPCODE_OR_A
                ld hl,PLY_AKG_InitTableOrA
                ld b,(PLY_AKG_InitTableOrA_End - PLY_AKG_InitTableOrA) / 2
                call PLY_AKG_Init_ReadWordsAndFill
                ld a,255
                ld (PLY_AKG_PSGReg13_OldValue + 1),a
        endif

        ;Stores the address to the empty instrument *data* (header skipped).
        ld hl,(PLY_AKG_InstrumentsTable + 1)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        inc hl                  ;Skips the header.
        ld (PLY_EmptyInstrumentDataPt + 1),hl
        ;Sets all the instrument to "empty".
        ld (PLY_AKG_Channel1_PtInstrument + 1),hl
        ld (PLY_AKG_Channel2_PtInstrument + 1),hl
        ld (PLY_AKG_Channel3_PtInstrument + 1),hl
        ret

        if PLY_AKG_FULL_INIT_CODE
;Fills all the read addresses with a byte.
;IN:    HL = table where the addresses are.
;       B = how many items in the table.
;       A = byte to fill.
PLY_AKG_Init_ReadWordsAndFill:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (de),a
        djnz PLY_AKG_Init_ReadWordsAndFill
        ret
;Table initializing some data with 0.
PLY_AKG_InitTable0:
        dw PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + 1
        dw PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + 2
        dw PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + 1
        dw PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + 2
        dw PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + 1
        dw PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + 2
        dw PLY_AKG_Channel1_Pitch + 1
        dw PLY_AKG_Channel1_Pitch + 2
        dw PLY_AKG_Channel2_Pitch + 1
        dw PLY_AKG_Channel2_Pitch + 2
        dw PLY_AKG_Channel3_Pitch + 1
        dw PLY_AKG_Channel3_Pitch + 2
        dw PLY_AKG_Retrig + 1
        
PLY_AKG_InitTable0_End:
PLY_AKG_InitTable1:
        dw PLY_AKG_PatternDecreasingHeight + 1
        dw PLY_AKG_TickDecreasingCounter + 1
PLY_AKG_InitTable1_End:

PLY_AKG_InitTableOrA:
        dw PLY_AKG_Channel1_IsVolumeSlide
        dw PLY_AKG_Channel2_IsVolumeSlide
        dw PLY_AKG_Channel3_IsVolumeSlide
        dw PLY_AKG_Channel1_IsArpeggioTable
        dw PLY_AKG_Channel2_IsArpeggioTable
        dw PLY_AKG_Channel3_IsArpeggioTable
        dw PLY_AKG_Channel1_IsPitchTable
        dw PLY_AKG_Channel2_IsPitchTable
        dw PLY_AKG_Channel3_IsPitchTable
        dw PLY_AKG_Channel1_IsPitch
        dw PLY_AKG_Channel2_IsPitch
        dw PLY_AKG_Channel3_IsPitch
PLY_AKG_InitTableOrA_End:
        endif           ;PLY_AKG_FULL_INIT_CODE


;Stops the music. This code can be removed if you don't intend to stop it!
PLY_AKG_Stop:
        ;All the volumes to 0, all sound/noise channels stopped.
        xor a
        ld l,a
        ld h,a
        ld (PLY_AKG_PSGReg8),a
        ld (PLY_AKG_PSGReg9_10_Instr + 1),hl
        ld a,%00111111
        jp PLY_AKG_SendPSGRegisters


;Plays one frame of the subsong.
PLY_AKG_Play:
        ld (PLY_AKG_SaveSP + 1),sp

        if PLY_AKG_MANAGE_EVENTS
                xor a
                ld (PLY_AKG_Event),a
        endif

        ;Decreases the tick counter. If 0 is reached, a new line must be read.
PLY_AKG_TickDecreasingCounter: ld a,1
        dec a
        jp nz,PLY_AKG_SetSpeedBeforePlayStreams                 ;Jumps if there is no new line: continues playing the sound stream.

        ;New line! Is the Pattern ended? Not as long as there are lines to read.
PLY_AKG_PatternDecreasingHeight: ld a,1
        dec a
        jr nz,PLY_AKG_SetCurrentLineBeforeReadLine  ;Jumps if the pattern isn't ended.
        ;New pattern!
        ;Reads the Linker. This is called at the start of the song, or at the end of every position.
PLY_AKG_ReadLinker:
PLY_AKG_ReadLinker_PtLinker: ld sp,0
        ;Reads the address of each Track.
        pop hl
        ld a,l
        or h
        jr nz,PLY_AKG_ReadLinker_NoLoop         ;Reached the end of the song?
        ;End of the song.
        pop hl          ;HL is the loop address.
        ld sp,hl
        pop hl          ;Reads once again the address of Track 1, in the pattern looped to.
PLY_AKG_ReadLinker_NoLoop:
        ld (PLY_AKG_Channel1_PtTrack + 1),hl
        pop hl
        ld (PLY_AKG_Channel2_PtTrack + 1),hl
        pop hl
        ld (PLY_AKG_Channel3_PtTrack + 1),hl
        ;Reads the address of the LinkerBlock.
        pop hl
        ld (PLY_AKG_ReadLinker_PtLinker + 1),sp
        ld sp,hl

        ;Reads the LinkerBlock. SP = LinkerBlock.
        ;Reads the height and transposition1.
        pop hl
        ld c,l                                ;Stores the pattern height, used below.
        ld a,h
        ld (PLY_AKG_Channel1_Transposition + 1),a
        ;Reads the transposition2 and 3.
        pop hl
        ld a,l
        ld (PLY_AKG_Channel2_Transposition + 1),a
        ld a,h
        ld (PLY_AKG_Channel3_Transposition + 1),a
        ;Reads the special Tracks addresses.
        pop hl
        ld (PLY_AKG_SpeedTrack_PtTrack + 1),hl
        if PLY_AKG_MANAGE_EVENTS
                pop hl
                ld (PLY_AKG_EventTrack_PtTrack + 1),hl
        endif

        xor a
        ;Forces the reading of every Track and Special Track.
        ld (PLY_AKG_SpeedTrack_WaitCounter + 1),a
        if PLY_AKG_MANAGE_EVENTS
                ld (PLY_AKG_EventTrack_WaitCounter + 1),a
        endif
        ld (PLY_AKG_Channel1_WaitCounter + 1),a
        ld (PLY_AKG_Channel2_WaitCounter + 1),a
        ld (PLY_AKG_Channel3_WaitCounter + 1),a
        ld a,c
PLY_AKG_SetCurrentLineBeforeReadLine:
        ld (PLY_AKG_PatternDecreasingHeight + 1),a


        ;Reads the new line (notes, effects, Special Tracks, etc.).
PLY_AKG_ReadLine:
        ;Reads the Speed Track.
        ;-------------------------------------------------------------------
PLY_AKG_SpeedTrack_WaitCounter: ld a,0      ;Lines to wait?
        sub 1
        jr nc,PLY_AKG_SpeedTrack_MustWait       ;Jump if there are still lines to wait.
        ;No more lines to wait. Reads a new data. It may be an event value or a wait value.
PLY_AKG_SpeedTrack_PtTrack: ld hl,0
        ld a,(hl)
        inc hl
        srl a           ;Bit 0: wait?
        jr c,PLY_AKG_SpeedTrack_StorePointerAndWaitCounter      ;Jump if wait: A is the wait value.
        ;Value found. If 0, escape value (rare).
        jr nz,PLY_AKG_SpeedTrack_NormalValue
        ;Escape code. Reads the right value.
        ld a,(hl)
        inc hl
PLY_AKG_SpeedTrack_NormalValue:
        ld (PLY_AKG_CurrentSpeed + 1),a

        xor a                   ;Next time, a new value is read.
PLY_AKG_SpeedTrack_StorePointerAndWaitCounter:
        ld (PLY_AKG_SpeedTrack_PtTrack + 1),hl
PLY_AKG_SpeedTrack_MustWait:
        ld (PLY_AKG_SpeedTrack_WaitCounter + 1),a
PLY_AKG_SpeedTrack_End:
        
        
   


        ;Reads the Event Track.
        ;-------------------------------------------------------------------
        if PLY_AKG_MANAGE_EVENTS
PLY_AKG_EventTrack_WaitCounter: ld a,0          ;Lines to wait?
        sub 1
        jr nc,PLY_AKG_EventTrack_MustWait       ;Jump if there are still lines to wait.
        ;No more lines to wait. Reads a new data. It may be an event value or a wait value.
PLY_AKG_EventTrack_PtTrack: ld hl,0
        ld a,(hl)
        inc hl
        srl a           ;Bit 0: wait?
        jr c,PLY_AKG_EventTrack_StorePointerAndWaitCounter      ;Jump if wait: A is the wait value.
        ;Value found. If 0, escape value (rare).
        jr nz,PLY_AKG_EventTrack_NormalValue
        ;Escape code. Reads the right value.
        ld a,(hl)
        inc hl
PLY_AKG_EventTrack_NormalValue:
        ld (PLY_AKG_Event),a

        xor a                   ;Next time, a new value is read.
PLY_AKG_EventTrack_StorePointerAndWaitCounter:
        ld (PLY_AKG_EventTrack_PtTrack + 1),hl
PLY_AKG_EventTrack_MustWait:
        ld (PLY_AKG_EventTrack_WaitCounter + 1),a
PLY_AKG_EventTrack_End:
        endif







        ;-------------------------------------------------------------------------
        ;Reads the possible Cell of the Channel 1.
        ;-------------------------------------------------------------------------

PLY_AKG_Channel1_WaitCounter: ld a,0      ;Lines to wait?
        sub 1
        jr c,PLY_AKG_Channel1_PtTrack
        ;Still some lines to wait.
        ld (PLY_AKG_Channel1_WaitCounter + 1),a
        jp PLY_AKG_Channel1_ReadCellEnd
        
PLY_AKG_Channel1_PtTrack: ld hl,0      ;Points on the Cell to read.
        ;Reads note data. It can be a note, a wait...

        ld c,(hl)       ;C = data (b5-0) + effect? (b6) + new Instrument? (b7).
        inc hl
        ld a,c
        and %111111     ;A = data.
        cp 60           ;0-59: note. "cp" is preferred to "sub" so that the "note" branch (the slowest) is note-ready.
        jr c,PLY_AKG_Channel1_Note
        sub 60
        jp z,PLY_AKG_Channel1_MaybeEffects        ;60 = no note, but maybe effects.
        dec a
        jr z,PLY_AKG_Channel1_Wait                ;61 = wait, no effect.
        dec a
        jr z,PLY_AKG_Channel1_SmallWait           ;62 = small wait, no effect.
        ;63 = escape code for note, maybe effects.
        ;Reads the note in the next byte (HL has already been incremented).
        ld a,(hl)
        inc hl
        jr PLY_AKG_Channel1_AfterNoteKnown

        ;Small wait, no effect.
PLY_AKG_Channel1_SmallWait:
        ld a,c          ;Uses bit 6/7 to indicate how many lines to wait.
        rla
        rla
        rla
        and %11
        inc a         ;This wait start at 2 lines, to 5.
        ld (PLY_AKG_Channel1_WaitCounter + 1),a
        jr PLY_AKG_Channel1_BeforeEnd_StoreCellPointer

        ;Wait, no effect.
PLY_AKG_Channel1_Wait:
        ld a,(hl)   ;Reads the wait value on the next byte (HL has already been incremented).
        ld (PLY_AKG_Channel1_WaitCounter + 1),a
        inc hl
        jr PLY_AKG_Channel1_BeforeEnd_StoreCellPointer

        ;Little subcode put here, called just below. A bit dirty, but avoids long jump.
PLY_AKG_Channel1_SameInstrument:
        ;No new instrument. The instrument pointer must be reset.
PLY_AKG_Channel1_PtBaseInstrument: ld de,0
        ld (PLY_AKG_Channel1_PtInstrument + 1),de
        jr PLY_AKG_Channel1_AfterInstrument

        ;A note has been found, plus maybe an Instrument and effects. A = note. C = still has the New Instrument/Effects flags.
PLY_AKG_Channel1_Note:
PLY_AKG_BaseNoteIndex: add a,0                  ;The encoded note is only from a 4 octave range, but the first note depends on he best window, determined by the song generator.
PLY_AKG_Channel1_AfterNoteKnown:
PLY_AKG_Channel1_Transposition: add a,0           ;Adds the Track transposition.
        ld (PLY_AKG_Channel1_TrackNote + 1),a

        ;HL = next data. C = data byte.
        rl c                ;New Instrument?
        jr nc,PLY_AKG_Channel1_SameInstrument
        ;Gets the new Instrument.
        ld a,(hl)
        inc hl
        exx
                ld l,a
                ld h,0
                add hl,hl
PLY_AKG_InstrumentsTable: ld de,0           ;Points on the Instruments table of the music (set on song initialization).
                add hl,de
                ld sp,hl
                pop hl
          
                ld a,(hl)       ;Gets the speed.
                inc hl
                ld (PLY_AKG_Channel1_InstrumentSpeed + 1),a
                ld (PLY_AKG_Channel1_PtInstrument + 1),hl
                ld (PLY_AKG_Channel1_PtBaseInstrument + 1),hl   ;Useful when playing another note with the same instrument.
        exx
PLY_AKG_Channel1_AfterInstrument:

        ;There is a new note. The instrument pointer has already been reset.
        ;-------------------------------------------------------------------
        ;Instrument number is set.
        ;Arpeggio and Pitch Table are reset.
        
        ;HL must be preserved! But it is faster to use HL than DE when storing 16 bits value.
        ;So it is stored in DE for now.
        ex de,hl

        ;The track pitch and glide, intrument step are reset.
        xor a
        ld l,a
        ld h,a
        ld (PLY_AKG_Channel1_Pitch + 1),hl
        ld (PLY_AKG_Channel1_ArpeggioTableCurrentStep + 1),a
        ld (PLY_AKG_Channel1_PitchTableCurrentStep + 1),a
        ld (PLY_AKG_Channel1_InstrumentStep + 2),a
        
        ld a,PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel1_IsPitch),a
        
        ;Resets the speed of the Arpeggio and the Pitch.
        ld a,(PLY_AKG_Channel1_ArpeggioBaseSpeed)
        ld (PLY_AKG_Channel1_ArpeggioTableSpeed),a
        ld a,(PLY_AKG_Channel1_PitchBaseSpeed)
        ld (PLY_AKG_Channel1_PitchTableSpeed),a        

        ld hl,(PLY_AKG_Channel1_ArpeggioTableBase)              ;Points to the first value of the Arpeggio.
        ld (PLY_AKG_Channel1_ArpeggioTable + 1),hl
        ld hl,(PLY_AKG_Channel1_PitchTableBase)                 ;Points to the first value of the Pitch.
        ld (PLY_AKG_Channel1_PitchTable + 1),hl

        ex de,hl
        
        ;Effects?
        rl c
        jp c,PLY_AKG_Channel1_ReadEffects

        ;No effects. Nothing more to read for this cell.
PLY_AKG_Channel1_BeforeEnd_StoreCellPointer:
        ld (PLY_AKG_Channel1_PtTrack + 1),hl
PLY_AKG_Channel1_ReadCellEnd:






        ;-------------------------------------------------------------------------
        ;Reads the possible Cell of the Channel 2.
        ;-------------------------------------------------------------------------

PLY_AKG_Channel2_WaitCounter: ld a,0      ;Lines to wait?
        sub 1
        jr c,PLY_AKG_Channel2_PtTrack
        ;Still some lines to wait.
        ld (PLY_AKG_Channel2_WaitCounter + 1),a
        jp PLY_AKG_Channel2_ReadCellEnd
        
PLY_AKG_Channel2_PtTrack: ld hl,0      ;Points on the Cell to read.
        ;Reads note data. It can be a note, a wait...

        ld c,(hl)       ;C = data (b5-0) + effect? (b6) + new Instrument? (b7).
        inc hl
        ld a,c
        and %111111     ;A = data.
        cp 60           ;0-59: note. "cp" is preferred to "sub" so that the "note" branch (the slowest) is note-ready.
        jr c,PLY_AKG_Channel2_Note
        sub 60
        jp z,PLY_AKG_Channel2_MaybeEffects        ;60 = no note, but maybe effects.
        dec a
        jr z,PLY_AKG_Channel2_Wait                ;61 = wait, no effect.
        dec a
        jr z,PLY_AKG_Channel2_SmallWait           ;62 = small wait, no effect.
        ;63 = escape code for note, maybe effects.
        ;Reads the note in the next byte (HL has already been incremented).
        ld a,(hl)
        inc hl
        jr PLY_AKG_Channel2_AfterNoteKnown

        ;Small wait, no effect.
PLY_AKG_Channel2_SmallWait:
        ld a,c          ;Uses bit 6/7 to indicate how many lines to wait.
        rla
        rla
        rla
        and %11
        inc a         ;This wait start at 2 lines, to 5.
        ld (PLY_AKG_Channel2_WaitCounter + 1),a
        jr PLY_AKG_Channel2_BeforeEnd_StoreCellPointer

        ;Wait, no effect.
PLY_AKG_Channel2_Wait:
        ld a,(hl)   ;Reads the wait value on the next byte (HL has already been incremented).
        ld (PLY_AKG_Channel2_WaitCounter + 1),a
        inc hl
        jr PLY_AKG_Channel2_BeforeEnd_StoreCellPointer

        ;Little subcode put here, called just below. A bit dirty, but avoids long jump.
PLY_AKG_Channel2_SameInstrument:
        ;No new instrument. The instrument pointer must be reset.
PLY_AKG_Channel2_PtBaseInstrument: ld de,0
        ld (PLY_AKG_Channel2_PtInstrument + 1),de
        jr PLY_AKG_Channel2_AfterInstrument

        ;A note has been found, plus maybe an Instrument and effects. A = note. C = still has the New Instrument/Effects flags.
PLY_AKG_Channel2_Note:
        ld b,a
        ld a,(PLY_AKG_BaseNoteIndex + 1)
        add a,b                  ;The encoded note is only from a 4 octave range, but the first note depends on he best window, determined by the song generator.
PLY_AKG_Channel2_AfterNoteKnown:
PLY_AKG_Channel2_Transposition: add a,0           ;Adds the Track transposition.
        ld (PLY_AKG_Channel2_TrackNote + 1),a

        ;HL = next data. C = data byte.
        rl c                ;New Instrument?
        jr nc,PLY_AKG_Channel2_SameInstrument
        ;Gets the new Instrument.
        ld a,(hl)
        inc hl
        exx
                ld e,a
                ld d,0
                ld hl,(PLY_AKG_InstrumentsTable + 1)           ;Points on the Instruments table of the music (set on song initialization).
                add hl,de
                add hl,de
                ld sp,hl
                pop hl
          
                ld a,(hl)       ;Gets the speed.
                inc hl
                ld (PLY_AKG_Channel2_InstrumentSpeed + 1),a
                ld (PLY_AKG_Channel2_PtInstrument + 1),hl
                ld (PLY_AKG_Channel2_PtBaseInstrument + 1),hl   ;Useful when playing another note with the same instrument.
        exx
PLY_AKG_Channel2_AfterInstrument:

        ;There is a new note. The instrument pointer has already been reset.
        ;-------------------------------------------------------------------
        ;Instrument number is set.
        ;Arpeggio and Pitch Table are reset.
        
        ;HL must be preserved! But it is faster to use HL than DE when storing 16 bits value.
        ;So it is stored in DE for now.
        ex de,hl

        ;The track pitch and glide, intrument step are reset.
        xor a
        ld l,a
        ld h,a
        ld (PLY_AKG_Channel2_Pitch + 1),hl
        ld (PLY_AKG_Channel2_ArpeggioTableCurrentStep + 1),a
        ld (PLY_AKG_Channel2_PitchTableCurrentStep + 1),a
        ld (PLY_AKG_Channel2_InstrumentStep + 2),a
        
        ld a,PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel2_IsPitch),a
        
        ;Resets the speed of the Arpeggio and the Pitch.
        ld a,(PLY_AKG_Channel2_ArpeggioBaseSpeed)
        ld (PLY_AKG_Channel2_ArpeggioTableSpeed),a
        ld a,(PLY_AKG_Channel2_PitchBaseSpeed)
        ld (PLY_AKG_Channel2_PitchTableSpeed),a        

        ld hl,(PLY_AKG_Channel2_ArpeggioTableBase)              ;Points to the first value of the Arpeggio.
        ld (PLY_AKG_Channel2_ArpeggioTable + 1),hl
        ld hl,(PLY_AKG_Channel2_PitchTableBase)                 ;Points to the first value of the Pitch.
        ld (PLY_AKG_Channel2_PitchTable + 1),hl

        ex de,hl
        
        ;Effects?
        rl c
        jp c,PLY_AKG_Channel2_ReadEffects

        ;No effects. Nothing more to read for this cell.
PLY_AKG_Channel2_BeforeEnd_StoreCellPointer:
        ld (PLY_AKG_Channel2_PtTrack + 1),hl
PLY_AKG_Channel2_ReadCellEnd:










        ;-------------------------------------------------------------------------
        ;Reads the possible Cell of the Channel 3.
        ;-------------------------------------------------------------------------

PLY_AKG_Channel3_WaitCounter: ld a,0      ;Lines to wait?
        sub 1
        jr c,PLY_AKG_Channel3_PtTrack
        ;Still some lines to wait.
        ld (PLY_AKG_Channel3_WaitCounter + 1),a
        jp PLY_AKG_Channel3_ReadCellEnd
        
PLY_AKG_Channel3_PtTrack: ld hl,0      ;Points on the Cell to read.
        ;Reads note data. It can be a note, a wait...

        ld c,(hl)       ;C = data (b5-0) + effect? (b6) + new Instrument? (b7).
        inc hl
        ld a,c
        and %111111     ;A = data.
        cp 60           ;0-59: note. "cp" is preferred to "sub" so that the "note" branch (the slowest) is note-ready.
        jr c,PLY_AKG_Channel3_Note
        sub 60
        jp z,PLY_AKG_Channel3_MaybeEffects        ;60 = no note, but maybe effects.
        dec a
        jr z,PLY_AKG_Channel3_Wait                ;61 = wait, no effect.
        dec a
        jr z,PLY_AKG_Channel3_SmallWait           ;62 = small wait, no effect.
        ;63 = escape code for note, maybe effects.
        ;Reads the note in the next byte (HL has already been incremented).
        ld a,(hl)
        inc hl
        jr PLY_AKG_Channel3_AfterNoteKnown

        ;Small wait, no effect.
PLY_AKG_Channel3_SmallWait:
        ld a,c          ;Uses bit 6/7 to indicate how many lines to wait.
        rla
        rla
        rla
        and %11
        inc a         ;This wait start at 2 lines, to 5.
        ld (PLY_AKG_Channel3_WaitCounter + 1),a
        jr PLY_AKG_Channel3_BeforeEnd_StoreCellPointer

        ;Wait, no effect.
PLY_AKG_Channel3_Wait:
        ld a,(hl)   ;Reads the wait value on the next byte (HL has already been incremented).
        ld (PLY_AKG_Channel3_WaitCounter + 1),a
        inc hl
        jr PLY_AKG_Channel3_BeforeEnd_StoreCellPointer

        ;Little subcode put here, called just below. A bit dirty, but avoids long jump.
PLY_AKG_Channel3_SameInstrument:
        ;No new instrument. The instrument pointer must be reset.
PLY_AKG_Channel3_PtBaseInstrument: ld de,0
        ld (PLY_AKG_Channel3_PtInstrument + 1),de
        jr PLY_AKG_Channel3_AfterInstrument

        ;A note has been found, plus maybe an Instrument and effects. A = note. C = still has the New Instrument/Effects flags.
PLY_AKG_Channel3_Note:
        ld b,a
        ld a,(PLY_AKG_BaseNoteIndex + 1)
        add a,b                 ;The encoded note is only from a 4 octave range, but the first note depends on he best window, determined by the song generator.
PLY_AKG_Channel3_AfterNoteKnown:
PLY_AKG_Channel3_Transposition: add a,0           ;Adds the Track transposition.
        ld (PLY_AKG_Channel3_TrackNote + 1),a

        ;HL = next data. C = data byte.
        rl c                ;New Instrument?
        jr nc,PLY_AKG_Channel3_SameInstrument
        ;Gets the new Instrument.
        ld a,(hl)
        inc hl
        exx
                ld e,a
                ld d,0
                ld hl,(PLY_AKG_InstrumentsTable + 1)           ;Points on the Instruments table of the music (set on song initialization).
                add hl,de
                add hl,de
                ld sp,hl
                pop hl
          
                ld a,(hl)       ;Gets the speed.
                inc hl
                ld (PLY_AKG_Channel3_InstrumentSpeed + 1),a
                ld (PLY_AKG_Channel3_PtInstrument + 1),hl
                ld (PLY_AKG_Channel3_PtBaseInstrument + 1),hl   ;Useful when playing another note with the same instrument.
        exx
PLY_AKG_Channel3_AfterInstrument:

        ;There is a new note. The instrument pointer has already been reset.
        ;-------------------------------------------------------------------
        ;Instrument number is set.
        ;Arpeggio and Pitch Table are reset.
        
        ;HL must be preserved! But it is faster to use HL than DE when storing 16 bits value.
        ;So it is stored in DE for now.
        ex de,hl

        ;The track pitch and glide, intrument step are reset.
        xor a
        ld l,a
        ld h,a
        ld (PLY_AKG_Channel3_Pitch + 1),hl
        ld (PLY_AKG_Channel3_ArpeggioTableCurrentStep + 1),a
        ld (PLY_AKG_Channel3_PitchTableCurrentStep + 1),a
        ld (PLY_AKG_Channel3_InstrumentStep + 2),a
        
        ld a,PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel3_IsPitch),a
        
        ;Resets the speed of the Arpeggio and the Pitch.
        ld a,(PLY_AKG_Channel3_ArpeggioBaseSpeed)
        ld (PLY_AKG_Channel3_ArpeggioTableSpeed),a
        ld a,(PLY_AKG_Channel3_PitchBaseSpeed)
        ld (PLY_AKG_Channel3_PitchTableSpeed),a        

        ld hl,(PLY_AKG_Channel3_ArpeggioTableBase)              ;Points to the first value of the Arpeggio.
        ld (PLY_AKG_Channel3_ArpeggioTable + 1),hl
        ld hl,(PLY_AKG_Channel3_PitchTableBase)                 ;Points to the first value of the Pitch.
        ld (PLY_AKG_Channel3_PitchTable + 1),hl

        ex de,hl
        
        ;Effects?
        rl c
        jp c,PLY_AKG_Channel3_ReadEffects

        ;No effects. Nothing more to read for this cell.
PLY_AKG_Channel3_BeforeEnd_StoreCellPointer:
        ld (PLY_AKG_Channel3_PtTrack + 1),hl
PLY_AKG_Channel3_ReadCellEnd:














PLY_AKG_CurrentSpeed: ld a,0      ;>0.
PLY_AKG_SetSpeedBeforePlayStreams:
        ld (PLY_AKG_TickDecreasingCounter + 1),a







        ;-----------------------------------------------------------------------------------------
        ;Applies the trailing effects for channel 1.
        ;-----------------------------------------------------------------------------------------
        
        ;Use Volume slide?
PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal: ld hl,0
PLY_AKG_Channel1_InvertedVolumeInteger: equ PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + 2
PLY_AKG_Channel1_IsVolumeSlide: or a                   ;Is there a Volume Slide ? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel1_VolumeSlide_End

PLY_AKG_Channel1_VolumeSlideValue: ld de,0              ;May be negative.
        add hl,de
        ;Went below 0?
        bit 7,h
        jr z,PLY_AKG_Channel1_VolumeNotOverflow
        ld h,0                  ;No need to set L to 0... Shouldn't make any hearable difference.
        jr PLY_AKG_Channel1_VolumeSetAgain
PLY_AKG_Channel1_VolumeNotOverflow:
        ;Higher than 15?
        ld a,h
        cp 16
        jr c,PLY_AKG_Channel1_VolumeSetAgain
        ld h,15        
PLY_AKG_Channel1_VolumeSetAgain:
        ld (PLY_AKG_Channel1_InvertedVolumeIntegerAndDecimal + 1),hl
        
PLY_AKG_Channel1_VolumeSlide_End:
        ld a,h
        ld (PLY_AKG_Channel1_GeneratedCurrentInvertedVolume + 1),a
        
        ;Use Arpeggio table? OUT: C = value.
        ;--------------------
        ld c,0  ;Default value of the arpeggio.
        
PLY_AKG_Channel1_IsArpeggioTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel1_ArpeggioTable_End

        ;We can read the Arpeggio table for a new value.
PLY_AKG_Channel1_ArpeggioTable: ld hl,0                 ;Points on the data, after the header.
        ld a,(hl)
        cp -128                  ;Loop?
        jr nz,PLY_AKG_Channel1_ArpeggioTable_AfterLoopTest
        ;Loop. Where to?
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)               ;Reads the value. Safe, we know there is no loop here.
        
        ;HL = pointer on what is follows.
        ;A = value to use.
PLY_AKG_Channel1_ArpeggioTable_AfterLoopTest:
        ld c,a
        
        ;Checks the speed. If reached, the pointer can be saved to read a new value next time.
        ld a,(PLY_AKG_Channel1_ArpeggioTableSpeed)
        ld d,a
PLY_AKG_Channel1_ArpeggioTableCurrentStep: ld a,0
        inc a
        cp d               ;From 1 to 256.
        jr c,PLY_AKG_Channel1_ArpeggioTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Stores the pointer to read a new value next time.
        inc hl
        ld (PLY_AKG_Channel1_ArpeggioTable + 1),hl

        xor a
PLY_AKG_Channel1_ArpeggioTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel1_ArpeggioTableCurrentStep + 1),a
PLY_AKG_Channel1_ArpeggioTable_End:


        ;Use Pitch table? OUT: DE = pitch value.
        ;C must NOT be modified!
        ;-----------------------
        ld de,0         ;Default value.
PLY_AKG_Channel1_IsPitchTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel1_PitchTable_End
        
        ;Read the Pitch table for a value.
PLY_AKG_Channel1_PitchTable: ld sp,0                 ;Points on the data, after the header.
        pop de                  ;Reads the value.
        pop hl                  ;Reads the pointer to the next value. Manages the loop automatically!
        
        ;Checks the speed. If reached, the pointer can be saved (advance in the Pitch).
        ld a,(PLY_AKG_Channel1_PitchTableSpeed)
        ld b,a
PLY_AKG_Channel1_PitchTableCurrentStep: ld a,0
        inc a
        cp b                                                 ;From 1 to 256.
        jr c,PLY_AKG_Channel1_PitchTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Advances in the Pitch.
        ld (PLY_AKG_Channel1_PitchTable + 1),hl
        
        xor a
PLY_AKG_Channel1_PitchTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel1_PitchTableCurrentStep + 1),a
PLY_AKG_Channel1_PitchTable_End:        


        ;Pitch management. The Glide is embedded, but relies on the Pitch (Pitch can exist without Glide, but Glide can not run without Pitch).
        ;Do NOT modify C or DE.
PLY_AKG_Channel1_Pitch: ld hl,0
PLY_AKG_Channel1_IsPitch: or a                          ;Is there a Pitch? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel1_Pitch_End

        ;C must NOT be modified, stores it.
        ld ixl,c
PLY_AKG_Channel1_PitchTrack: ld bc,0                    ;Value from the user. ALWAYS POSITIVE. Does not evolve. B is always 0.

        or a                                            ;Required if the code is changed to sbc.
PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits: nop : add hl,bc          ;WILL BE AUTOMODIFIED to add or sbc. But SBC requires 2*8 bits! Damn.

        ;Makes the decimal part evolves.
PLY_AKG_Channel1_PitchTrackDecimalCounter: ld a,0
PLY_AKG_Channel1_PitchTrackDecimal: add a,0              ;Value from the user. WILL BE AUTOMODIFIED to add or sub.
        ld (PLY_AKG_Channel1_PitchTrackDecimalCounter + 1),a

        jr nc,$ + 3
PLY_AKG_Channel1_PitchTrackIntegerAddOrSub: inc hl                   ;WILL BE AUTOMODIFIED to inc hl/dec hl

        ld (PLY_AKG_Channel1_Pitch + 1),hl

PLY_AKG_Channel1_SoundStream_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.

        ;Glide?
PLY_AKG_Channel1_GlideDirection: ld a,0         ;0 = no glide. 1 = glide/pitch up. 2 = glide/pitch down.
        or a                                    ;Is there a Glide?
        jr z,PLY_AKG_Channel1_Glide_End

        ld (PLY_AKG_Channel1_Glide_SaveHLEnd + 1),hl
        ld c,l
        ld b,h
        ;Finds the period of the current note.
        ex af,af'
                ld a,(PLY_AKG_Channel1_TrackNote + 1)
                add a,a                                         ;Encoded on 7 bits, so no problem.
                ld l,a
        ex af,af'
        ld h,0
        ld sp,PLY_AKG_PeriodTable
        add hl,sp
        ld sp,hl
        pop hl                                          ;HL = current note period.
        dec sp
        dec sp                                          ;We will need this value if the glide is over, it is faster to reuse the stack.
        
        add hl,bc                                       ;HL is now the current period (note period + track pitch).
       
PLY_AKG_Channel1_GlideToReach: ld bc,0                  ;Period to reach (note given by the user, converted to period).
        ;Have we reached the glide destination?
        ;Depends on the direction.        
        rra                                             ;If 1, the carry is set. If 2, no.
        jr nc,PLY_AKG_Channel1_GlideDownCheck
        ;Glide up. Check.
        ;The glide period should be lower than the current pitch.
        or a
        sbc hl,bc
        jr nc,PLY_AKG_Channel1_Glide_SaveHLEnd           ;If not reached yet, continues the pitch.
        jr PLY_AKG_Channel1_GlideOver

PLY_AKG_Channel1_GlideDownCheck:
        ;The glide period should be higher than the current pitch.
        sbc hl,bc                                       ;No carry, no need to remove it.
        jr c,PLY_AKG_Channel1_Glide_SaveHLEnd           ;If not reached yet, continues the pitch.
PLY_AKG_Channel1_GlideOver:
        ;The glide is over. However, it may be over, so we can't simply use the current pitch period. We have to set the exact needed value.
        ld l,c
        ld h,b
        pop bc
        or a
        sbc hl,bc
        
        ld (PLY_AKG_Channel1_Pitch + 1),hl
        ld a,PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel1_IsPitch),a
        jr PLY_AKG_Channel1_Glide_End                   ;Skips the HL restoration, the one we have is fine and will give us the right pitch to use.
        ;A small place to stash some vars which have to be within relative range. Dirty, but no choice.
PLY_AKG_Channel1_ArpeggioTableSpeed: db 0
PLY_AKG_Channel1_ArpeggioBaseSpeed: db 0
PLY_AKG_Channel1_PitchTableSpeed: db 0
PLY_AKG_Channel1_PitchBaseSpeed: db 0
PLY_AKG_Channel1_ArpeggioTableBase: dw 0
PLY_AKG_Channel1_PitchTableBase: dw 0

PLY_AKG_Channel1_Glide_SaveHLEnd: ld hl,0               ;Restores HL.
PLY_AKG_Channel1_Glide_End:
        ld c,ixl                                        ;Restores C, saved before.


PLY_AKG_Channel1_Pitch_End:
        
        add hl,de                               ;Adds the Pitch Table value.
        ld (PLY_AKG_Channel1_GeneratedCurrentPitch + 1),hl
        ld a,c
        ld (PLY_AKG_Channel1_GeneratedCurrentArpNote + 1),a








        ;-----------------------------------------------------------------------------------------
        ;Applies the trailing effects for channel 2.
        ;-----------------------------------------------------------------------------------------
        
        ;Use Volume slide?
PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal: ld hl,0
PLY_AKG_Channel2_InvertedVolumeInteger: equ PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + 2
PLY_AKG_Channel2_IsVolumeSlide: or a                   ;Is there a Volume Slide ? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel2_VolumeSlide_End

PLY_AKG_Channel2_VolumeSlideValue: ld de,0              ;May be negative.
        add hl,de
        ;Went below 0?
        bit 7,h
        jr z,PLY_AKG_Channel2_VolumeNotOverflow
        ld h,0                  ;No need to set L to 0... Shouldn't make any hearable difference.
        jr PLY_AKG_Channel2_VolumeSetAgain
PLY_AKG_Channel2_VolumeNotOverflow:
        ;Higher than 15?
        ld a,h
        cp 16
        jr c,PLY_AKG_Channel2_VolumeSetAgain
        ld h,15        
PLY_AKG_Channel2_VolumeSetAgain:
        ld (PLY_AKG_Channel2_InvertedVolumeIntegerAndDecimal + 1),hl
        
PLY_AKG_Channel2_VolumeSlide_End:
        ld a,h
        ld (PLY_AKG_Channel2_GeneratedCurrentInvertedVolume + 1),a
        
        ;Use Arpeggio table? OUT: C = value.
        ;--------------------
        ld c,0  ;Default value of the arpeggio.
        
PLY_AKG_Channel2_IsArpeggioTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel2_ArpeggioTable_End

        ;We can read the Arpeggio table for a new value.
PLY_AKG_Channel2_ArpeggioTable: ld hl,0                 ;Points on the data, after the header.
        ld a,(hl)
        cp -128                  ;Loop?
        jr nz,PLY_AKG_Channel2_ArpeggioTable_AfterLoopTest
        ;Loop. Where to?
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)               ;Reads the value. Safe, we know there is no loop here.
        
        ;HL = pointer on what is follows.
        ;A = value to use.
PLY_AKG_Channel2_ArpeggioTable_AfterLoopTest:
        ld c,a
        
        ;Checks the speed. If reached, the pointer can be saved to read a new value next time.
        ld a,(PLY_AKG_Channel2_ArpeggioTableSpeed)
        ld d,a
PLY_AKG_Channel2_ArpeggioTableCurrentStep: ld a,0
        inc a
        cp d               ;From 1 to 256.
        jr c,PLY_AKG_Channel2_ArpeggioTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Stores the pointer to read a new value next time.
        inc hl
        ld (PLY_AKG_Channel2_ArpeggioTable + 1),hl

        xor a
PLY_AKG_Channel2_ArpeggioTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel2_ArpeggioTableCurrentStep + 1),a
PLY_AKG_Channel2_ArpeggioTable_End:


        ;Use Pitch table? OUT: DE = pitch value.
        ;C must NOT be modified!
        ;-----------------------
        ld de,0         ;Default value.
PLY_AKG_Channel2_IsPitchTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel2_PitchTable_End
        
        ;Read the Pitch table for a value.
PLY_AKG_Channel2_PitchTable: ld sp,0                 ;Points on the data, after the header.
        pop de                  ;Reads the value.
        pop hl                  ;Reads the pointer to the next value. Manages the loop automatically!
        
        ;Checks the speed. If reached, the pointer can be saved (advance in the Pitch).
        ld a,(PLY_AKG_Channel2_PitchTableSpeed)
        ld b,a
PLY_AKG_Channel2_PitchTableCurrentStep: ld a,0
        inc a
        cp b                                                 ;From 1 to 256.
        jr c,PLY_AKG_Channel2_PitchTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Advances in the Pitch.
        ld (PLY_AKG_Channel2_PitchTable + 1),hl
        
        xor a
PLY_AKG_Channel2_PitchTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel2_PitchTableCurrentStep + 1),a
PLY_AKG_Channel2_PitchTable_End:        


        ;Pitch management. The Glide is embedded, but relies on the Pitch (Pitch can exist without Glide, but Glide can not run without Pitch).
        ;Do NOT modify C or DE.
PLY_AKG_Channel2_Pitch: ld hl,0
PLY_AKG_Channel2_IsPitch: or a                          ;Is there a Pitch? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel2_Pitch_End

        ;C must NOT be modified, stores it.
        ld ixl,c
PLY_AKG_Channel2_PitchTrack: ld bc,0                    ;Value from the user. ALWAYS POSITIVE. Does not evolve. B is always 0.

        or a                                            ;Required if the code is changed to sbc.
PLY_AKG_Channel2_PitchTrackAddOrSbc_16bits: nop : add hl,bc          ;WILL BE AUTOMODIFIED to add or sbc. But SBC requires 2*8 bits! Damn.

        ;Makes the decimal part evolves.
PLY_AKG_Channel2_PitchTrackDecimalCounter: ld a,0
PLY_AKG_Channel2_PitchTrackDecimal: add a,0              ;Value from the user. WILL BE AUTOMODIFIED to add or sub.
        ld (PLY_AKG_Channel2_PitchTrackDecimalCounter + 1),a

        jr nc,$ + 3
PLY_AKG_Channel2_PitchTrackIntegerAddOrSub: inc hl                   ;WILL BE AUTOMODIFIED to inc hl/dec hl

        ld (PLY_AKG_Channel2_Pitch + 1),hl

PLY_AKG_Channel2_SoundStream_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.

        ;Glide?
PLY_AKG_Channel2_GlideDirection: ld a,0         ;0 = no glide. 1 = glide/pitch up. 2 = glide/pitch down.
        or a                                    ;Is there a Glide?
        jr z,PLY_AKG_Channel2_Glide_End

        ld (PLY_AKG_Channel2_Glide_SaveHLEnd + 1),hl
        ld c,l
        ld b,h
        ;Finds the period of the current note.
        ex af,af'
                ld a,(PLY_AKG_Channel2_TrackNote + 1)
                add a,a                                         ;Encoded on 7 bits, so no problem.
                ld l,a
        ex af,af'
        ld h,0
        ld sp,PLY_AKG_PeriodTable
        add hl,sp
        ld sp,hl
        pop hl                                          ;HL = current note period.
        dec sp
        dec sp                                          ;We will need this value if the glide is over, it is faster to reuse the stack.
        
        add hl,bc                                       ;HL is now the current period (note period + track pitch).

PLY_AKG_Channel2_GlideToReach: ld bc,0                  ;Period to reach (note given by the user, converted to period).
        ;Have we reached the glide destination?
        ;Depends on the direction.        
        rra                                             ;If 1, the carry is set. If 2, no.
        jr nc,PLY_AKG_Channel2_GlideDownCheck
        ;Glide up. Check.
        ;The glide period should be lower than the current pitch.
        or a
        sbc hl,bc
        jr nc,PLY_AKG_Channel2_Glide_SaveHLEnd           ;If not reached yet, continues the pitch.
        jr PLY_AKG_Channel2_GlideOver

PLY_AKG_Channel2_GlideDownCheck:
        ;The glide period should be higher than the current pitch.
        sbc hl,bc                                       ;No carry, no need to remove it.
        jr c,PLY_AKG_Channel2_Glide_SaveHLEnd           ;If not reached yet, continues the pitch.
PLY_AKG_Channel2_GlideOver:
        ;The glide is over. However, it may be over, so we can't simply use the current pitch period. We have to set the exact needed value.
        ld l,c
        ld h,b
        pop bc
        or a
        sbc hl,bc
        
        ld (PLY_AKG_Channel2_Pitch + 1),hl
        ld a,PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel2_IsPitch),a
        jr PLY_AKG_Channel2_Glide_End                   ;Skips the HL restoration, the one we have is fine and will give us the right pitch to use.
        ;A small place to stash some vars which have to be within relative range. Dirty, but no choice.
PLY_AKG_Channel2_ArpeggioTableSpeed: db 0
PLY_AKG_Channel2_ArpeggioBaseSpeed: db 0
PLY_AKG_Channel2_PitchTableSpeed: db 0
PLY_AKG_Channel2_PitchBaseSpeed: db 0
PLY_AKG_Channel2_ArpeggioTableBase: dw 0
PLY_AKG_Channel2_PitchTableBase: dw 0

PLY_AKG_Channel2_Glide_SaveHLEnd: ld hl,0               ;Restores HL.
PLY_AKG_Channel2_Glide_End:
        ld c,ixl                                        ;Restores C, saved before.


PLY_AKG_Channel2_Pitch_End:
        
        add hl,de                               ;Adds the Pitch Table value.
        ld (PLY_AKG_Channel2_GeneratedCurrentPitch + 1),hl
        ld a,c
        ld (PLY_AKG_Channel2_GeneratedCurrentArpNote + 1),a









        ;-----------------------------------------------------------------------------------------
        ;Applies the trailing effects for channel 3.
        ;-----------------------------------------------------------------------------------------
        
        ;Use Volume slide?
PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal: ld hl,0
PLY_AKG_Channel3_InvertedVolumeInteger: equ PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + 2
PLY_AKG_Channel3_IsVolumeSlide: or a                   ;Is there a Volume Slide ? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel3_VolumeSlide_End

PLY_AKG_Channel3_VolumeSlideValue: ld de,0              ;May be negative.
        add hl,de
        ;Went below 0?
        bit 7,h
        jr z,PLY_AKG_Channel3_VolumeNotOverflow
        ld h,0                  ;No need to set L to 0... Shouldn't make any hearable difference.
        jr PLY_AKG_Channel3_VolumeSetAgain
PLY_AKG_Channel3_VolumeNotOverflow:
        ;Higher than 15?
        ld a,h
        cp 16
        jr c,PLY_AKG_Channel3_VolumeSetAgain
        ld h,15        
PLY_AKG_Channel3_VolumeSetAgain:
        ld (PLY_AKG_Channel3_InvertedVolumeIntegerAndDecimal + 1),hl
        
PLY_AKG_Channel3_VolumeSlide_End:
        ld a,h
        ld (PLY_AKG_Channel3_GeneratedCurrentInvertedVolume + 1),a
        
        
        ;Use Arpeggio table? OUT: C = value.
        ;--------------------
        ld c,0  ;Default value of the arpeggio.
        
PLY_AKG_Channel3_IsArpeggioTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel3_ArpeggioTable_End

        ;We can read the Arpeggio table for a new value.
PLY_AKG_Channel3_ArpeggioTable: ld hl,0                 ;Points on the data, after the header.
        ld a,(hl)
        cp -128                  ;Loop?
        jr nz,PLY_AKG_Channel3_ArpeggioTable_AfterLoopTest
        ;Loop. Where to?
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)               ;Reads the value. Safe, we know there is no loop here.
        
        ;HL = pointer on what is follows.
        ;A = value to use.
PLY_AKG_Channel3_ArpeggioTable_AfterLoopTest:
        ld c,a
        
        ;Checks the speed. If reached, the pointer can be saved to read a new value next time.
        ld a,(PLY_AKG_Channel3_ArpeggioTableSpeed)
        ld d,a
PLY_AKG_Channel3_ArpeggioTableCurrentStep: ld a,0
        inc a
        cp d               ;From 1 to 256.
        jr c,PLY_AKG_Channel3_ArpeggioTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Stores the pointer to read a new value next time.
        inc hl
        ld (PLY_AKG_Channel3_ArpeggioTable + 1),hl

        xor a
PLY_AKG_Channel3_ArpeggioTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel3_ArpeggioTableCurrentStep + 1),a
PLY_AKG_Channel3_ArpeggioTable_End:


        ;Use Pitch table? OUT: DE = pitch value.
        ;C must NOT be modified!
        ;-----------------------
        ld de,0         ;Default value.
PLY_AKG_Channel3_IsPitchTable: or a                   ;Is there an arpeggio table? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel3_PitchTable_End
        
        ;Read the Pitch table for a value.
PLY_AKG_Channel3_PitchTable: ld sp,0                 ;Points on the data, after the header.
        pop de                  ;Reads the value.
        pop hl                  ;Reads the pointer to the next value. Manages the loop automatically!
        
        ;Checks the speed. If reached, the pointer can be saved (advance in the Pitch).
        ld a,(PLY_AKG_Channel3_PitchTableSpeed)
        ld b,a
PLY_AKG_Channel3_PitchTableCurrentStep: ld a,0
        inc a
        cp b                                                 ;From 1 to 256.
        jr c,PLY_AKG_Channel3_PitchTable_BeforeEnd_SaveStep  ;C, not NZ, because the current step may be higher than the limit if Force Speed effect is used.
        ;Advances in the Pitch.
        ld (PLY_AKG_Channel3_PitchTable + 1),hl
        
        xor a
PLY_AKG_Channel3_PitchTable_BeforeEnd_SaveStep:
        ld (PLY_AKG_Channel3_PitchTableCurrentStep + 1),a
PLY_AKG_Channel3_PitchTable_End:        


        ;Pitch management. The Glide is embedded, but relies on the Pitch (Pitch can exist without Glide, but Glide can not run without Pitch).
        ;Do NOT modify C or DE.
PLY_AKG_Channel3_Pitch: ld hl,0
PLY_AKG_Channel3_IsPitch: or a                          ;Is there a Pitch? Automodified. SCF if yes, OR A if not.
        jr nc,PLY_AKG_Channel3_Pitch_End

        ;C must NOT be modified, stores it.
        ld ixl,c
PLY_AKG_Channel3_PitchTrack: ld bc,0                    ;Value from the user. ALWAYS POSITIVE. Does not evolve. B is always 0.

        or a                                            ;Required if the code is changed to sbc.
PLY_AKG_Channel3_PitchTrackAddOrSbc_16bits: nop : add hl,bc          ;WILL BE AUTOMODIFIED to add or sbc. But SBC requires 2*8 bits! Damn.

        ;Makes the decimal part evolves.
PLY_AKG_Channel3_PitchTrackDecimalCounter: ld a,0
PLY_AKG_Channel3_PitchTrackDecimal: add a,0              ;Value from the user. WILL BE AUTOMODIFIED to add or sub.
        ld (PLY_AKG_Channel3_PitchTrackDecimalCounter + 1),a

        jr nc,$ + 3
PLY_AKG_Channel3_PitchTrackIntegerAddOrSub: inc hl                   ;WILL BE AUTOMODIFIED to inc hl/dec hl

        ld (PLY_AKG_Channel3_Pitch + 1),hl

PLY_AKG_Channel3_SoundStream_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.

        ;Glide?
PLY_AKG_Channel3_GlideDirection: ld a,0         ;0 = no glide. 1 = glide/pitch up. 2 = glide/pitch down.
        or a                                    ;Is there a Glide?
        jr z,PLY_AKG_Channel3_Glide_End

        ld (PLY_AKG_Channel3_Glide_SaveHLEnd + 1),hl
        ld c,l
        ld b,h
        ;Finds the period of the current note.
        ex af,af'
                ld a,(PLY_AKG_Channel3_TrackNote + 1)
                add a,a                                         ;Encoded on 7 bits, so no problem.
                ld l,a
        ex af,af'
        ld h,0
        ld sp,PLY_AKG_PeriodTable
        add hl,sp
        ld sp,hl
        pop hl                                          ;HL = current note period.
        dec sp
        dec sp                                          ;We will need this value if the glide is over, it is faster to reuse the stack.
        
        add hl,bc                                       ;HL is now the current period (note period + track pitch).
        
PLY_AKG_Channel3_GlideToReach: ld bc,0                  ;Period to reach (note given by the user, converted to period).
        ;Have we reached the glide destination?
        ;Depends on the direction.        
        rra                                             ;If 1, the carry is set. If 2, no.
        jr nc,PLY_AKG_Channel3_GlideDownCheck
        ;Glide up. Check.
        ;The glide period should be lower than the current pitch.
        or a
        sbc hl,bc
        jr nc,PLY_AKG_Channel3_Glide_SaveHLEnd           ;If not reached yet, continues the pitch.
        jr PLY_AKG_Channel3_GlideOver

PLY_AKG_Channel3_GlideDownCheck:
        ;The glide period should be higher than the current pitch.
        sbc hl,bc                                       ;No carry, no need to remove it.
        jr c,PLY_AKG_Channel3_Glide_SaveHLEnd           ;If not reached yet, continues the pitch.
PLY_AKG_Channel3_GlideOver:
        ;The glide is over. However, it may be over, so we can't simply use the current pitch period. We have to set the exact needed value.
        ld l,c
        ld h,b
        pop bc
        or a
        sbc hl,bc
        
        ld (PLY_AKG_Channel3_Pitch + 1),hl
        ld a,PLY_AKG_OPCODE_OR_A
        ld (PLY_AKG_Channel3_IsPitch),a
        jr PLY_AKG_Channel3_Glide_End                   ;Skips the HL restoration, the one we have is fine and will give us the right pitch to use.
        ;A small place to stash some vars which have to be within relative range. Dirty, but no choice.
PLY_AKG_Channel3_ArpeggioTableSpeed: db 0
PLY_AKG_Channel3_ArpeggioBaseSpeed: db 0
PLY_AKG_Channel3_PitchTableSpeed: db 0
PLY_AKG_Channel3_PitchBaseSpeed: db 0
PLY_AKG_Channel3_ArpeggioTableBase: dw 0
PLY_AKG_Channel3_PitchTableBase: dw 0

PLY_AKG_Channel3_Glide_SaveHLEnd: ld hl,0               ;Restores HL.
PLY_AKG_Channel3_Glide_End:
        ld c,ixl                                        ;Restores C, saved before.


PLY_AKG_Channel3_Pitch_End:
        
        add hl,de                               ;Adds the Pitch Table value.
        ld (PLY_AKG_Channel3_GeneratedCurrentPitch + 1),hl
        ld a,c
        ld (PLY_AKG_Channel3_GeneratedCurrentArpNote + 1),a











        ;The stack must NOT be diverted during the Play Streams!
        ld sp,(PLY_AKG_SaveSP + 1)


;-------------------------------------------------------------------------------------
;Plays the instrument on channel 1. The PSG registers related to the channels are set.
;-------------------------------------------------------------------------------------

PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.

        ;What note to play?
PLY_AKG_Channel1_GeneratedCurrentPitch: ld hl,0 ;The pitch to add to the real note, according to the Pitch Table + Pitch/Glide effect.
PLY_AKG_Channel1_TrackNote: ld a,0
PLY_AKG_Channel1_GeneratedCurrentArpNote: add 0                           ;Adds the arpeggio value.
                ld e,a
                ld d,0
        exx
PLY_AKG_Channel1_InstrumentStep: ld iyl,0
PLY_AKG_Channel1_PtInstrument: ld hl,0       ;Instrument data to read (past the header).
PLY_AKG_Channel1_GeneratedCurrentInvertedVolume: ld de,%11100000 * 256 + 15             ;R7, shift twice TO THE LEFT. By default, the noise is cut (111), the sound is on (most usual case).

;       D = Reg7
;       E = inverted volume.
;       D' = 0, E' = note (instrument + Track transposition).
;       HL' = track pitch.

        call PLY_AKG_ReadInstrumentCell

        ;The new and increased Instrument pointer is stored only if its speed has been reached.
        ld a,iyl
        inc a
PLY_AKG_Channel1_InstrumentSpeed: cp 0          ;(>0)
        jr c,PLY_AKG_Channel1_SetInstrumentStep         ;Checks C, not only NZ because since the speed can be changed via an effect, the step can get beyond the limit, this must be taken in account.
        ;The speed is reached. We can go to the next line on the next frame.
        ld (PLY_AKG_Channel1_PtInstrument + 1),hl
        xor a
PLY_AKG_Channel1_SetInstrumentStep:
        ld (PLY_AKG_Channel1_InstrumentStep + 2),a

        srl d           ;Shift D to the right to let room for the other channels. Use SRL, not RR, to make sure bit 6 is 0 at the end (else, no more keyboard on CPC!).
        
        ;Saves the software period and volume for the PSG to send later.
        ld a,e
        ld (PLY_AKG_PSGReg8),a
        exx
                ld (PLY_AKG_PSGReg01_Instr + 1),hl
        ;exx

     
        
        
;-------------------------------------------------------------------------------------
;Plays the instrument on channel 2. The PSG registers related to the channels are set.
;-------------------------------------------------------------------------------------

PLY_AKG_Channel2_PlayInstrument_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.

        ;What note to play?
PLY_AKG_Channel2_GeneratedCurrentPitch: ld hl,0 ;The pitch to add to the real note, according to the Pitch Table + Pitch/Glide effect.
PLY_AKG_Channel2_TrackNote: ld a,0
PLY_AKG_Channel2_GeneratedCurrentArpNote: add 0                          ;Adds the arpeggio value.
                ld e,a
                ld d,0
        exx
PLY_AKG_Channel2_InstrumentStep: ld iyl,0
PLY_AKG_Channel2_PtInstrument: ld hl,0       ;Instrument data to read (past the header).
PLY_AKG_Channel2_GeneratedCurrentInvertedVolume: ld e,15
        nop                     ;Stupid, but required for relative registers to reach some address independently of the channels.
;       D = Reg7
;       E = inverted volume.
;       D' = 0, E' = note (instrument + Track transposition).
;       HL' = track pitch.

        call PLY_AKG_ReadInstrumentCell

        ;The new and increased Instrument pointer is stored only if its speed has been reached.
        ld a,iyl
        inc a
PLY_AKG_Channel2_InstrumentSpeed: cp 0          ;(>0)
        jr c,PLY_AKG_Channel2_SetInstrumentStep         ;Checks C, not only NZ because since the speed can be changed via an effect, the step can get beyond the limit, this must be taken in account.
        ;The speed is reached. We can go to the next line on the next frame.
        ld (PLY_AKG_Channel2_PtInstrument + 1),hl
        xor a
PLY_AKG_Channel2_SetInstrumentStep:
        ld (PLY_AKG_Channel2_InstrumentStep + 2),a

        srl d           ;Shift D to the right to let room for the other channels. Use SRL, not RR, to make sure bit 6 is 0 at the end (else, no more keyboard on CPC!).
        
        ;Saves the software period and volume for the PSG to send later.
        ld a,e
        ld (PLY_AKG_PSGReg9),a
        exx
                ld (PLY_AKG_PSGReg23_Instr + 1),hl
        ;exx

       
       
       
       
;-------------------------------------------------------------------------------------
;Plays the instrument on channel 3. The PSG registers related to the channels are set.
;-------------------------------------------------------------------------------------

PLY_AKG_Channel3_PlayInstrument_RelativeModifierAddress:                   ;This must be placed at the any location to allow reaching the variables via IX/IY.

        ;What note to play?
PLY_AKG_Channel3_GeneratedCurrentPitch: ld hl,0 ;The pitch to add to the real note, according to the Pitch Table + Pitch/Glide effect.
PLY_AKG_Channel3_TrackNote: ld a,0
PLY_AKG_Channel3_GeneratedCurrentArpNote: add 0                           ;Adds the arpeggio value.
                ld e,a
                ld d,0
        exx
PLY_AKG_Channel3_InstrumentStep: ld iyl,0
PLY_AKG_Channel3_PtInstrument: ld hl,0       ;Instrument data to read (past the header).
PLY_AKG_Channel3_GeneratedCurrentInvertedVolume: ld e,15
        nop                     ;Stupid, but required for relative registers to reach some address independently of the channels.
;       D = Reg7
;       E = inverted volume.
;       D' = 0, E' = note (instrument + Track transposition).
;       HL' = track pitch.

        call PLY_AKG_ReadInstrumentCell

        ;The new and increased Instrument pointer is stored only if its speed has been reached.
        ld a,iyl
        inc a
PLY_AKG_Channel3_InstrumentSpeed: cp 0          ;(>0)
        jr c,PLY_AKG_Channel3_SetInstrumentStep         ;Checks C, not only NZ because since the speed can be changed via an effect, the step can get beyond the limit, this must be taken in account.
        ;The speed is reached. We can go to the next line on the next frame.
        ld (PLY_AKG_Channel3_PtInstrument + 1),hl
        xor a
PLY_AKG_Channel3_SetInstrumentStep:
        ld (PLY_AKG_Channel3_InstrumentStep + 2),a

        
        
        ;Saves the software period and volume for the PSG to send later.
        ld a,e
        ld (PLY_AKG_PSGReg10),a
        ;Gets the R7.
        ld a,d
        
        exx
                ld (PLY_AKG_PSGReg45_Instr + 1),hl
        
 
          
;Plays the sound effects, if desired.
;-------------------------------------------
        if PLY_AKG_MANAGE_SOUND_EFFECTS
                ;IN : A = R7
                ;OUT: A = R7, possibly modified.
                call PLY_AKG_PlaySoundEffectsStream
        endif
     


; -----------------------------------------------------------------------------------
; PSG access.
; -----------------------------------------------------------------------------------

;Sends the registers to the PSG. Only general registers are sent, the specific ones have already been sent.
;IN:    A = R7.
PLY_AKG_SendPSGRegisters:

                ld bc,#f680
                ld e,#c0
        	out (c),e	;#f6c0          ;Madram's trick requires to start with this. out (c),b works, but will activate K7's relay! Not clean.
        exx
        ld bc,#f401                     ;C is the PSG register.

        ;Register 0 and 1.
PLY_AKG_PSGReg01_Instr: ld hl,0
        out (c),0                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
     
        ;Register 2 and 3.
PLY_AKG_PSGReg23_Instr: ld hl,0
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 4 and 5.
PLY_AKG_PSGReg45_Instr: ld hl,0
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 6.
PLY_AKG_PSGReg6_8_Instr: ld hl,0          ;L is R6, H is R8. Faster to set a 16 bits register than 2 8-bit.
PLY_AKG_PSGReg6: equ PLY_AKG_PSGReg6_8_Instr + 1
PLY_AKG_PSGReg8: equ PLY_AKG_PSGReg6_8_Instr + 2
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 7. The value is A.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),a                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 8. The value is loaded above via HL.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx

PLY_AKG_PSGReg9_10_Instr: ld hl,0          ;L is R9, H is R10. Faster to set a 16 bits register than 2 8-bit.
PLY_AKG_PSGReg9: equ PLY_AKG_PSGReg9_10_Instr + 1
PLY_AKG_PSGReg10: equ PLY_AKG_PSGReg9_10_Instr + 2
        ;Register 9.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        ;Register 10.
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx
        
        
        ;Register 11 and 12.
PLY_AKG_PSGHardwarePeriod_Instr: ld hl,0
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),l                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx  

        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),h                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx  





        ;R13.
PLY_AKG_PSGReg13_OldValue: ld a,255
PLY_AKG_Retrig: or 0                    ;0 = no retrig. Else, should be >0xf to be sure the old value becomes a sentinel (i.e. unreachable) value.
PLY_AKG_PSGReg13_Instr: ld l,0          ;Register 13.
        cp l                            ;Is the new value still the same? If yes, the new value must not be set again.
        jr z,PLY_AKG_PSGReg13_End
        ;Different R13.
        ld a,l
        ld (PLY_AKG_PSGReg13_OldValue + 1),a
        
        inc c
        out (c),c                       ;#f400 + register.
        exx
                out (c),0               ;#f600.
        exx
        out (c),a                       ;#f400 + value.
        exx
                out (c),c               ;#f680.
                out (c),e               ;#f6c0.
        exx  
        
        xor a
        ld (PLY_AKG_Retrig + 1),a
PLY_AKG_PSGReg13_End:

PLY_AKG_SaveSP: ld sp,0
        ret
        














;Channel1 sub-codes.
;-----------------------
PLY_AKG_Channel1_MaybeEffects:
        ;There is one wait in all cases.
        xor a
        ld (PLY_AKG_Channel1_WaitCounter + 1),a
        
        bit 6,c         ;Effects?
        jp z,PLY_AKG_Channel1_BeforeEnd_StoreCellPointer
        ;Manage effects.

;Reads the effects.
;IN:    HL = Points on the effect blocks
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel1_ReadEffects:
        ld iy,PLY_AKG_Channel1_SoundStream_RelativeModifierAddress
        ld ix,PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress
        ld de,PLY_AKG_Channel1_BeforeEnd_StoreCellPointer
        jr PLY_AKG_Channel_ReadEffects



;Channel 2 sub-codes.
;-----------------------
PLY_AKG_Channel2_MaybeEffects:
        ;There is one wait in all cases.
        xor a
        ld (PLY_AKG_Channel2_WaitCounter + 1),a
        
        bit 6,c         ;Effects?
        jp z,PLY_AKG_Channel2_BeforeEnd_StoreCellPointer
        ;Manage effects.

;Reads the effects.
;IN:    HL = Points on the effect blocks
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel2_ReadEffects:
        ld iy,PLY_AKG_Channel2_SoundStream_RelativeModifierAddress
        ld ix,PLY_AKG_Channel2_PlayInstrument_RelativeModifierAddress
        ld de,PLY_AKG_Channel2_BeforeEnd_StoreCellPointer
        jr PLY_AKG_Channel_ReadEffects




;Channel 3 sub-codes.
;-----------------------
PLY_AKG_Channel3_MaybeEffects:
        ;There is one wait in all cases.
        xor a
        ld (PLY_AKG_Channel3_WaitCounter + 1),a
        
        bit 6,c         ;Effects?
        jp z,PLY_AKG_Channel3_BeforeEnd_StoreCellPointer
        ;Manage effects.

;Reads the effects.
;IN:    HL = Points on the effect blocks
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel3_ReadEffects:
        ld iy,PLY_AKG_Channel3_SoundStream_RelativeModifierAddress
        ld ix,PLY_AKG_Channel3_PlayInstrument_RelativeModifierAddress
        ld de,PLY_AKG_Channel3_BeforeEnd_StoreCellPointer
        ;jr PLY_AKG_Channel_ReadEffects


        
        
        
;IN:    HL = Points on the effect blocks
;       DE = Where to go to when over.
;       IX = Address from which the data of the instrument are modified.
;       IY = Address from which data of the channels (pitch, volume, etc) are modified.
;OUT:   HL = Points after on the effect blocks
PLY_AKG_Channel_ReadEffects:
        ld (PLY_AKG_Channel_ReadEffects_EndJump + 1),de
        ;HL will be very useful, so we store the pointer in DE.
        ex de,hl

        ;Reads the effect block. It may be an index or a relative address.        
        ld a,(de)
        inc de
        sla a
        jr c,PLY_AKG_Channel_ReadEffects_RelativeAddress
        ;Index.
        exx
                ld l,a
                ld h,0
PLY_AKG_Channel_ReadEffects_EffectBlocks1: ld de,0
                add hl,de               ;The index is already *2.
                ld e,(hl)               ;Gets the address referred by the table.
                inc hl
                ld d,(hl)
PLY_AKG_Channel_RE_EffectAddressKnown:
                ;DE points on the current effect block header/data.
                ld a,(de)               ;Gets the effect number/more effect flag.
                inc de
                ld (PLY_AKG_Channel_RE_ReadNextEffectInBlock + 1),a     ;Stores the flag indicating whether there are more effects.
                
                ;Gets the effect number.
                and %11111110
                ld l,a
                ld h,0
                ld sp,PLY_AKG_EffectTable
                add hl,sp                ;Effect is already * 2.
                ld sp,hl                ;Jumps to the effect code.
                ret
                ;All the effects return here.
PLY_AKG_Channel_RE_EffectReturn:
                ;Is there another effect?
PLY_AKG_Channel_RE_ReadNextEffectInBlock: ld a,0                ;Bit 0 indicates whether there are more effects.
                rra
                jr c,PLY_AKG_Channel_RE_EffectAddressKnown
                ;No more effects.
        exx
        
        ;Put back in HL the point on the Track Cells.
        ex de,hl
PLY_AKG_Channel_ReadEffects_EndJump: jp 0        ;PLY_AKG_Channel1/2/3_BeforeEnd_StoreCellPointer

PLY_AKG_Channel_ReadEffects_RelativeAddress:
        srl a           ;A was the relative MSB. Only 7 relevant bits.
        exx
                ld h,a
        exx
        ld a,(de)       ;Reads the relative LSB.
        inc de
        exx
                ld l,a
PLY_AKG_Channel_ReadEffects_EffectBlocks2: ld de,0
                add hl,de
                jr PLY_AKG_Channel_RE_EffectAddressKnown
        




;---------------------------------
;Codes that read InstrumentCells.
;IN:    HL = pointer on the Instrument data cell to read.
;       IX = can be modified.
;       IYL = Instrument step (>=0). Useful for retrig.
;       SP = normal use of the stack, do not pervert it!
;       D = register 7, as if it was the channel 3 (so, bit 2 and 5 filled only).
;             By default, the noise is OFF, the sound is ON, so no need to do anything if these values match.
;       E = inverted volume.
;       A = SET BELOW: first byte of the data, shifted of 3 bits to the right.
;       B = SET BELOW: first byte of the data, unmodified.
;       HL' = track pitch.
;       DE' = 0 / note (instrument + Track transposition).
;       BC' = temp, use at will.

;OUT:   HL = new pointer on the Instrument (may be on the empty sound). If not relevant, any value can be returned, it doesn't matter.
;       IYL = Not 0 if retrig for this channel.
;       D = register 7, updated, as if it was the channel 1 (so, bit 2 and 5 filled only).
;       E = volume to encode (0-16).
;       HL' = software period. If not relevant, do not set it.
;       DE' = output period.

PLY_AKG_BitForSound: equ 2
PLY_AKG_BitForNoise: equ 5


PLY_AKG_ReadInstrumentCell:
        ld a,(hl)               ;Gets the first byte of the cell.
        inc hl
        ld b,a                  ;Stores the first byte, handy in many cases.
        
        ;What type if the cell?
        rra
        jp c,PLY_AKG_S_Or_H_Or_SaH_Or_EndWithLoop
        ;No Soft No Hard, or Soft To Hard, or Hard To Soft, or End without loop.
        rra
        jr c,PLY_AKG_StH_Or_EndWithoutLoop
        ;No Soft No Hard, or Hard to Soft.
        rra
        jr c,PLY_AKG_HardToSoft
        
        
        
        
        
        
        ;-------------------------------------------------
        ;"No soft, no hard".
        ;-------------------------------------------------
PLY_AKG_NoSoftNoHard:
        and %1111               ;Necessary, we don't know what crap is in the 4th bit of A.
        sub e                   ;Decreases the volume, watching for overflow.
        jr nc,$ + 3
        xor a
        
        ld e,a                  ;Sets the volume.

        rl b            ;Noise?
        jr nc,PLY_AKG_NSNH_NoNoise
        ;Noise.
        ld a,(hl)
        inc hl
        ld (PLY_AKG_PSGReg6),a
        set PLY_AKG_BitForSound,d      ;Noise, no sound (both non-default values).
        res PLY_AKG_BitForNoise,d
        ret
PLY_AKG_NSNH_NoNoise:
        set PLY_AKG_BitForSound,d      ;No noise (default), no sound.
        ret







        ;-------------------------------------------------
        ;"Soft only".
        ;-------------------------------------------------        
PLY_AKG_Soft:
        ;Calculates the volume.
        and %1111               ;Necessary, we don't know what crap is in the 4th bit of A.
        
        sub e                   ;Decreases the volume, watching for overflow.
        jr nc,$ + 3             ;Checks for overflow.
        xor a
    
        ld e,a                  ;Sets the volume.

PLY_AKG_Soft_TestSimple_Common:        ;This code is also used by "Hard only".
        ;Simple sound? Gets the bit, let the subroutine do the job.
        rl b
        jr nc,PLY_AKG_S_NotSimple
        ;Simple.
        ld c,0                  ;This will force the noise to 0.
        jr PLY_AKG_S_AfterSimpleTest
PLY_AKG_S_NotSimple:
        ;Not simple. Reads and keeps the next byte, containing the noise. WARNING, the following code must NOT modify the Carry!
        ld b,(hl)
        ld c,b
        inc hl
PLY_AKG_S_AfterSimpleTest:

        call PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod
        
        ;Noise?
        ld a,c
        and %11111
        ret z                                   ;if noise not present, sound present, we can stop here, R7 is fine.
        ;Noise is present.
        ld (PLY_AKG_PSGReg6),a
        res PLY_AKG_BitForNoise, d              ;Noise present.
        ret
        
        




        ;-------------------------------------------------
        ;"Hard to soft".
        ;-------------------------------------------------
PLY_AKG_HardToSoft:
        call PLY_AKG_StoH_Or_HToS_Common
        ;We have the ratio jump calculated and the primary period too. It must be divided to get the software frequency.
        
        ld (PLY_AKG_HS_JumpRatio + 1),a
        ;Gets B, we need the bit to know if a hardware pitch shift is added.
        ld a,b
        exx
                ;The hardware period can be stored.
                ld (PLY_AKG_PSGHardwarePeriod_Instr + 1),hl
        
PLY_AKG_HS_JumpRatio: jr $ + 2               ;Automodified by the line above to jump on the right code.
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                sla l
                rl h
                ;Any Software pitch shift?
                rla
                jr nc,PLY_AKG_SH_NoSoftwarePitchShift
;Pitch shift. Reads it.
        exx
        ld a,(hl)
        inc hl
        exx
                add a,l
                ld l,a
        exx
        ld a,(hl)
        inc hl
        exx
                adc a,h
                ld h,a        
PLY_AKG_SH_NoSoftwarePitchShift:
        exx
        
        ret
        
        

        
        
PLY_AKG_StH_Or_EndWithoutLoop:
        rra
        jr c,PLY_AKG_EndWithoutLoop
        
        ;-------------------------------------------------
        ;"Soft to Hard".
        ;-------------------------------------------------

        call PLY_AKG_StoH_Or_HToS_Common
        ;We have the ratio jump calculated and the primary period too. It must be divided to get the hardware frequency.

        ld (PLY_AKG_SH_JumpRatio + 1),a
        ;Gets B, we need the bit to know if a hardware pitch shift is added.
        ld a,b
        exx
                ;Saves the original frequency in DE.
                ld e,l
                ld d,h
        
PLY_AKG_SH_JumpRatio: jr $ + 2               ;Automodified by the line above to jump on the right code.
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                srl h
                rr l
                jr nc,PLY_AKG_SH_JumpRatioEnd
                inc hl
PLY_AKG_SH_JumpRatioEnd:
                ;Any Hardware pitch shift?
                rla
                jr nc,PLY_AKG_SH_NoHardwarePitchShift
                ;Pitch shift. Reads it.
        exx
        ld a,(hl)
        inc hl
        exx
                add a,l
                ld l,a
        exx
        ld a,(hl)
        inc hl
        exx
                adc a,h
                ld h,a        
PLY_AKG_SH_NoHardwarePitchShift:
                ld (PLY_AKG_PSGHardwarePeriod_Instr + 1),hl
                
                ;Put back the frequency in HL.
                ex de,hl
        exx
        
        ret
        
        
        
        
       
PLY_AKG_S_Or_H_Or_SaH_Or_EndWithLoop:
        ;Second bit of the type.
        rra
        jr c,PLY_AKG_H_Or_EndWithLoop
        ;Third bit of the type.
        rra
        jp nc,PLY_AKG_Soft
        
        
        
        ;-------------------------------------------------
        ;"Soft and Hard".
        ;-------------------------------------------------
        exx
                push hl         ;Saves the note and track pitch, because the first pass below will modify it, we need it for the second pass.
                push de
        exx
        
        call PLY_AKG_StoH_Or_HToS_Common
        ;We have now calculated the hardware frequency. Stores it.
        exx
                ld (PLY_AKG_PSGHardwarePeriod_Instr + 1),hl
                
                pop de          ;Get back the note and track pitch for the second pass.
                pop hl
        exx
        
        
        ;Now calculate the software frequency.
        rl b            ;Simple sound? Used by the sub-code.
        jp PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod    ;That's all!
        
                
        
        

        
PLY_AKG_H_Or_EndWithLoop:
        ;Third bit of the type.
        rra
        jr c,PLY_AKG_EndWithLoop

        ;-------------------------------------------------
        ;"Hard only".
        ;-------------------------------------------------
        
        ld e,16                 ;Sets the hardware volume.

        ;Retrig?
        rra
        jr nc,PLY_AKG_H_AfterRetrig
        ;Retrig is only set if we are on the first step of the instrument!
        ld a,iyl
        or a
        jr nz,PLY_AKG_H_AfterRetrig
        ld a,e
        ld (PLY_AKG_Retrig + 1),a
PLY_AKG_H_AfterRetrig:

        ;Calculates the hardware envelope. The value given is from 8-15, but encoded as 0-7.
        and %111
        add a,8
        ld (PLY_AKG_PSGReg13_Instr + 1),a

        ;Use the code of Soft Only to calculate the period and the noise.
        call PLY_AKG_Soft_TestSimple_Common

        ;The period is actually an hardware period. We don't care about the software period, the sound channel is cut.
        exx
                ld (PLY_AKG_PSGHardwarePeriod_Instr + 1),hl
        exx
        
        ;Stops the sound.
        set PLY_AKG_BitForSound,d

        ret
        
        
        
        
        ;-------------------------------------------------
        ;End without loop.
        ;-------------------------------------------------
PLY_AKG_EndWithoutLoop:
        ;Loops to the "empty" instrument, and makes another iteration.
PLY_EmptyInstrumentDataPt: ld hl,0
        ;No need to read the data, consider a void value.
        inc hl
        xor a
        ld b,a
        jp PLY_AKG_NoSoftNoHard




        ;-------------------------------------------------
        ;End with loop.
        ;-------------------------------------------------
PLY_AKG_EndWithLoop:
        ;Loops to the encoded pointer, and makes another iteration.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp PLY_AKG_ReadInstrumentCell
     
     
;Common code for calculating the period, regardless of Soft or Hard. The same register constraints as the methods above apply.
;IN:    HL = the next bytes to read.
;       HL' = note + transposition.
;       B = contains three bits:
;               b7: forced period? (if yes, the two other bits are irrelevant)
;               b6: arpeggio?
;               b5: pitch?
;       C = do not modify.
;       Carry: Simple sound?
;OUT:   B = shift three times to the left.
;       C = unmodified.
;       HL = advanced.
;       HL' = calculated period.
PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod:

        ;Simple sound? Checks the carry.
        jr nc,PLY_AKG_S_Or_H_NextByte
        ;No more byte to read, the sound is "simple". The software period must still be calculated.
        ;Calculates the note period from the note of the track. This is the same code as below.
        exx
                ex de,hl                        ;Now HL = track note + transp, DE is track pitch.
                add hl,hl
                ld bc,PLY_AKG_PeriodTable
                add hl,bc
           
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                add hl,de                       ;Adds the track pitch.
        exx
        ;Important: the bits must be shifted so that B is in the same state as if it were not a "simple" sound.
        rl b
        rl b
        rl b
        ;No need to modify R7.
        ret
        
PLY_AKG_S_Or_H_NextByte:
        ;Not simple. Reads the next bits to know if there is pitch/arp/forced software period.        
        ;Forced software period?
        rl b
        jr c,PLY_AKG_S_Or_H_ForcedSoftPeriod
        ;No forced period. Arpeggio?
        rl b
        jr nc,PLY_AKG_S_Or_H_AfterArpeggio
        ld a,(hl)
        inc hl
        exx
                add a,e                         ;We don't care about overflow, no time for that.
                ld e,a
        exx
PLY_AKG_S_Or_H_AfterArpeggio:
        ;Pitch?
        rl b
        jr nc,PLY_AKG_S_Or_H_AfterPitch
        ;Reads the pitch. Slow, but shouldn't happen so often.
        ld a,(hl)
        inc hl
        exx
                add a,l
                ld l,a                          ;Adds the cell pitch to the track pitch, in two passes.
        exx
        ld a,(hl)
        inc hl
        exx
                adc a,h
                ld h,a
        exx
PLY_AKG_S_Or_H_AfterPitch:
        
        ;Calculates the note period from the note of the track.
        exx
                ex de,hl                        ;Now HL = track note + transp, DE is track pitch.
                add hl,hl
                ld bc,PLY_AKG_PeriodTable
                add hl,bc
                
                ld a,(hl)
                inc hl
                ld h,(hl)
                ld l,a
                add hl,de                       ;Adds the track pitch.
        exx

        ret


PLY_AKG_S_Or_H_ForcedSoftPeriod:
        ;Reads the software period. A bit slow, but doesn't happen often.
        ld a,(hl)
        inc hl
        exx
                ld l,a
        exx
        ld a,(hl)
        inc hl
        exx
                ld h,a
        exx

        ;The pitch and arpeggios have been skipped, since the period is forced, the bits must be compensated.
        rl b
        rl b
        ret
        
        
        ;------------------------------------------------------------------
;Common code for SoftToHard and HardToSoft, and even Soft And Hard. The same register constraints as the methods above apply.
;OUT:   HL' = frequency.
;       A = shifted inverted ratio (xxx000), ready to be used in a JR to multiply/divide the frequency.
;       B = bit states, shifted four times to the left (for StoH/HtoS, the msb will be "pitch shift?") (hardware for SoftTohard, software for HardToSoft).
PLY_AKG_StoH_Or_HToS_Common:
        ld e,16                 ;Sets the hardware volume.

        ;Retrig?
        rra
        jr nc,PLY_AKG_SHoHS_AfterRetrig
        ld c,a
        ;Retrig is only set if we are on the first step of the instrument!
        ld a,iyl
        or a
        jr nz,PLY_AKG_H_RetrigEnd
        dec a
        ld (PLY_AKG_Retrig + 1),a
PLY_AKG_H_RetrigEnd:
        ld a,c
PLY_AKG_SHoHS_AfterRetrig:

        ;Calculates the hardware envelope. The value given is from 8-15, but encoded as 0-7.
        and %111
        add a,8
        ld (PLY_AKG_PSGReg13_Instr + 1),a
        
        ;Noise? If yes, reads the next byte.
        rl b
        jr nc,PLY_AKG_SHoHS_AfterNoise
        ;Noise is present.
        ld a,(hl)
        inc hl
        ld (PLY_AKG_PSGReg6),a
        res PLY_AKG_BitForNoise, d              ;Noise present.
PLY_AKG_SHoHS_AfterNoise:

        ;Read the next data byte.
        ld c,(hl)               ;C = ratio, kept for later.
        ld b,c
        inc hl
        
        rl b                    ;Simple (no need to test the other bits)? The carry is transmitted to the called code below.
        ;Call another common subcode.
        call PLY_AKG_S_Or_H_CheckIfSimpleFirst_CalculatePeriod
        ;Let's calculate the hardware frequency from it.
        ld a,c                  ;Gets the ratio.
        rla
        rla
        and %11100
        
        ret
        
        

        




        
; -----------------------------------------------------------------------------------
; Effects management.
; -----------------------------------------------------------------------------------
        
;All the effects code.
PLY_AKG_EffectTable:
        dw PLY_AKG_Effect_ResetFullVolume                               ;0
        dw PLY_AKG_Effect_Reset                                         ;1
        dw PLY_AKG_Effect_Volume                                        ;2
        dw PLY_AKG_Effect_ArpeggioTable                                 ;3
        dw PLY_AKG_Effect_ArpeggioTableStop                             ;4
        dw PLY_AKG_Effect_PitchTable                                    ;5
        dw PLY_AKG_Effect_PitchTableStop                                ;6
        dw PLY_AKG_Effect_VolumeSlide                                   ;7
        dw PLY_AKG_Effect_VolumeSlideStop                               ;8
        
        dw PLY_AKG_Effect_PitchUp                                       ;9
        dw PLY_AKG_Effect_PitchDown                                     ;10
        dw PLY_AKG_Effect_PitchStop                                     ;11
        
        dw PLY_AKG_Effect_GlideWithNote                                 ;12
        dw PLY_AKG_Effect_GlideSpeed                                    ;13
        
        dw PLY_AKG_Effect_Legato                                        ;14

        dw PLY_AKG_Effect_ForceInstrumentSpeed                          ;15
        dw PLY_AKG_Effect_ForceArpeggioSpeed                            ;16
        dw PLY_AKG_Effect_ForcePitchSpeed                               ;17
        
        
;Effects.
;----------------------------------------------------------------
;For all effects:
;IN:    DE' = Points on the data of this effect.
;       IX = Address from which the data of the instrument are modified.
;       IY = Address from which the data of the channels (pitch, volume, etc) are modified.
;       HL = Must NOT be modified.
;       WARNING, we are on auxiliary registers!

;       SP = Can be modified at will.

;OUT:   DE' = Points after on the data of this effect.
;       WARNING, remains on auxiliary registers!
;----------------------------------------------------------------

PLY_AKG_Effect_ResetFullVolume:
        xor a           ;The inverted volume is 0 (full volume).
        jr PLY_AKG_Effect_ResetVolume_AfterReading
        
PLY_AKG_Effect_Reset:
        ld a,(de)       ;Reads the inverted volume.
        inc de
PLY_AKG_Effect_ResetVolume_AfterReading:
        ld (iy + PLY_AKG_Channel1_InvertedVolumeInteger - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        ;The current pitch is reset.
        xor a
        ld (iy + PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        ld (iy + PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2),a

        ld a,PLY_AKG_OPCODE_OR_A
        ld (iy + PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        ld (iy + PLY_AKG_Channel1_IsPitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        ld (iy + PLY_AKG_Channel1_IsArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        ld (iy + PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        jp PLY_AKG_Channel_RE_EffectReturn

PLY_AKG_Effect_Volume:
        ld a,(de)       ;Reads the inverted volume.
        inc de
        
        ld (iy + PLY_AKG_Channel1_InvertedVolumeInteger - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        
        ld (iy + PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
        
PLY_AKG_Effect_ArpeggioTable:
        ld a,(de)       ;Reads the arpeggio table index.
        inc de
        
        ;Finds the address of the Arpeggio.
        ld l,a
        ld h,0
        add hl,hl
PLY_AKG_ArpeggiosTable: ld bc,0
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        
        ;Reads the speed.
        ld a,(bc)
        inc bc
        ld (iy + PLY_AKG_Channel1_ArpeggioTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0),a
        ld (iy + PLY_AKG_Channel1_ArpeggioBaseSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0),a
        
        ld (iy + PLY_AKG_Channel1_ArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),c
        ld (iy + PLY_AKG_Channel1_ArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2),b
        ld (iy + PLY_AKG_Channel1_ArpeggioTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0),c
        ld (iy + PLY_AKG_Channel1_ArpeggioTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),b
        
        ld (iy + PLY_AKG_Channel1_IsArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_SCF
        xor a
        ld (iy + PLY_AKG_Channel1_ArpeggioTableCurrentStep - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        
        jp PLY_AKG_Channel_RE_EffectReturn

PLY_AKG_Effect_ArpeggioTableStop:
        ld (iy + PLY_AKG_Channel1_IsArpeggioTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn


;Pitch table. Followed by the Pitch Table index.
PLY_AKG_Effect_PitchTable:
        ld a,(de)       ;Reads the Pitch table index.
        inc de
        
        ;Finds the address of the Pitch.
        ld l,a
        ld h,0
        add hl,hl
PLY_AKG_PitchesTable: ld bc,0
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        
        ;Reads the speed.
        ld a,(bc)
        inc bc
        ld (iy + PLY_AKG_Channel1_PitchTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        ld (iy + PLY_AKG_Channel1_PitchBaseSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        
        ld (iy + PLY_AKG_Channel1_PitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),c
        ld (iy + PLY_AKG_Channel1_PitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2),b
        ld (iy + PLY_AKG_Channel1_PitchTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0),c
        ld (iy + PLY_AKG_Channel1_PitchTableBase - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),b
        
        ld (iy + PLY_AKG_Channel1_IsPitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_SCF
        
        xor a
        ld (iy + PLY_AKG_Channel1_PitchTableCurrentStep - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        
        jp PLY_AKG_Channel_RE_EffectReturn
        
;Stops the pitch table.        
PLY_AKG_Effect_PitchTableStop:
        ;Only the pitch is stopped, but the value remains.
        ld (iy + PLY_AKG_Channel1_IsPitchTable - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn

;Volume slide effect. Followed by the volume, as a word.
PLY_AKG_Effect_VolumeSlide:
        ld a,(de)               ;Reads the slide.
        inc de
        ld (iy + PLY_AKG_Channel1_VolumeSlideValue - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        ld a,(de)
        inc de
        ld (iy + PLY_AKG_Channel1_VolumeSlideValue - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2),a
        
        ld (iy + PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_SCF
        jp PLY_AKG_Channel_RE_EffectReturn
        
;Volume slide stop effect.
PLY_AKG_Effect_VolumeSlideStop:
        ;Only stops the slide, don't reset the value.
        ld (iy + PLY_AKG_Channel1_IsVolumeSlide - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
  
;Pitch track effect. Followed by the pitch, as a word.
PLY_AKG_Effect_PitchDown:
        ;Changes the sign of the operations.
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_ADD_HL_BC_MSB
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1), PLY_AKG_OPCODE_ADD_HL_BC_LSB
        ld (iy + PLY_AKG_Channel1_PitchTrackDecimal - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_ADD_A_IMMEDIATE
        ld (iy + PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_INC_HL
PLY_AKG_Effect_PitchUpDown_Common:              ;The Pitch up will jump here.
        ;Authorizes the pitch, disabled the glide.        
        ld (iy + PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_SCF
        ld (iy + PLY_AKG_Channel1_GlideDirection - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),0

        ld a,(de)       ;Reads the Pitch.
        inc de
        ld (iy + PLY_AKG_Channel1_PitchTrackDecimal - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        ld a,(de)
        inc de
        ld (iy + PLY_AKG_Channel1_PitchTrack - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        jp PLY_AKG_Channel_RE_EffectReturn
        
PLY_AKG_Effect_PitchUp:
        ;Changes the sign of the operations.
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_SBC_HL_BC_MSB
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1), PLY_AKG_OPCODE_SBC_HL_BC_LSB
        ld (iy + PLY_AKG_Channel1_PitchTrackDecimal - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_SUB_IMMEDIATE
        ld (iy + PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_DEC_HL
        jr PLY_AKG_Effect_PitchUpDown_Common

;Pitch track stop.
PLY_AKG_Effect_PitchStop:
        ;Only stops the pitch, don't reset the value. No need to reset the Glide either.
        ld (iy + PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),PLY_AKG_OPCODE_OR_A
        jp PLY_AKG_Channel_RE_EffectReturn
        
;Glide, with a note.
PLY_AKG_Effect_GlideWithNote:
        ;Reads the note to reach.
        ld a,(de)
        inc de
        ld (PLY_AKG_Effect_GlideWithNoteSaveDE + 1),de                        ;Have to save, no more registers. Damn.
        ;Finds the period related to the note, stores it.
        add a,a                 ;The note is 7 bits only, so it fits.
        ld l,a
        ld h,0
        ld bc,PLY_AKG_PeriodTable
        add hl,bc
        
        ld sp,hl
        pop de                  ;DE = period to reach.
        ld (iy + PLY_AKG_Channel1_GlideToReach - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),e
        ld (iy + PLY_AKG_Channel1_GlideToReach - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2),d
        
        ;Calculates the period of the current note to calculate the difference.
        ld a,(ix + PLY_AKG_Channel1_TrackNote - PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress + 1)
        add a,a
        ld l,a
        ld h,0
        add hl,bc
        
        ld sp,hl
        pop hl                  ;HL = current period.
        ;Adds the current Track Pitch to have the current period, else the direction may be biased.
        ld c,(iy + PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1)
        ld b,(iy + PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2)
        add hl,bc
        
        ;What is the difference?
        or a
        sbc hl,de
PLY_AKG_Effect_GlideWithNoteSaveDE: ld de,0                   ;Retrieves DE. This does not modified the Carry.
        jr c,PLY_AKG_Effect_Glide_PitchDown
        ;Pitch up.
        ld (iy + PLY_AKG_Channel1_GlideDirection - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),1
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_SBC_HL_BC_MSB
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1), PLY_AKG_OPCODE_SBC_HL_BC_LSB
        ld (iy + PLY_AKG_Channel1_PitchTrackDecimal - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_SUB_IMMEDIATE
        ld (iy + PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_DEC_HL
        
        ;Reads the Speed, which is actually the "pitch".
PLY_AKG_Effect_Glide_ReadSpeed:
PLY_AKG_Effect_GlideSpeed:                      ;This is an effect.
        ld a,(de)
        inc de
        ld (iy + PLY_AKG_Channel1_PitchTrackDecimal - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        ld a,(de)
        inc de
        ld (iy + PLY_AKG_Channel1_PitchTrack - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        
        ;Enables the pitch, as the Glide relies on it. The Glide is enabled below, via its direction.
        ld a,PLY_AKG_OPCODE_SCF
        ld (iy + PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a

        jp PLY_AKG_Channel_RE_EffectReturn
PLY_AKG_Effect_Glide_PitchDown:
        ;Pitch down.
        ld (iy + PLY_AKG_Channel1_GlideDirection - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),2
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_ADD_HL_BC_MSB
        ld (iy + PLY_AKG_Channel1_PitchTrackAddOrSbc_16bits - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1), PLY_AKG_OPCODE_ADD_HL_BC_LSB
        ld (iy + PLY_AKG_Channel1_PitchTrackDecimal - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_ADD_A_IMMEDIATE
        ld (iy + PLY_AKG_Channel1_PitchTrackIntegerAddOrSub - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 0), PLY_AKG_OPCODE_INC_HL
        jr PLY_AKG_Effect_Glide_ReadSpeed
        
        
        
;Legato. Followed by the note to play.        
PLY_AKG_Effect_Legato:
        ;Reads and sets the new note to play.
        ld a,(de)
        inc de
        ld (ix + PLY_AKG_Channel1_TrackNote - PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress + 1),a
        
        ;Stops the Pitch effect, resets the Pitch.
        ld a,PLY_AKG_OPCODE_OR_A
        ld (iy + PLY_AKG_Channel1_IsPitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        xor a
        ld (iy + PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 1),a
        ld (iy + PLY_AKG_Channel1_Pitch - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress + 2),a
        
        jp PLY_AKG_Channel_RE_EffectReturn

;Forces the Instrument Speed. Followed by the speed.
PLY_AKG_Effect_ForceInstrumentSpeed:
        ;Reads and sets the new speed.
        ld a,(de)
        inc de
        ld (ix + PLY_AKG_Channel1_InstrumentSpeed - PLY_AKG_Channel1_PlayInstrument_RelativeModifierAddress + 1),a
        
        jp PLY_AKG_Channel_RE_EffectReturn
        
;Forces the Arpeggio Speed. Followed by the speed.
PLY_AKG_Effect_ForceArpeggioSpeed:
        ;Reads and sets the new speed.
        ld a,(de)
        inc de
        ld (iy + PLY_AKG_Channel1_ArpeggioTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        
        jp PLY_AKG_Channel_RE_EffectReturn

;Forces the Pitch Speed. Followed by the speed.
PLY_AKG_Effect_ForcePitchSpeed:
        ;Reads and sets the new speed.
        ld a,(de)
        inc de
        ld (iy + PLY_AKG_Channel1_PitchTableSpeed - PLY_AKG_Channel1_SoundStream_RelativeModifierAddress),a
        
        jp PLY_AKG_Channel_RE_EffectReturn


        

        if PLY_AKG_MANAGE_EVENTS
PLY_AKG_Event: db 0         ;Possible event sent from the music for the caller to interpret.
        endif



        ;Includes the sound effects player, if wanted.
        if PLY_AKG_MANAGE_SOUND_EFFECTS
                include "PlayerAkg_SoundEffects.asm"
        endif
        
        
        

;The period table for each note (from 0 to 127 included).
PLY_AKG_PeriodTable:
        dw 3822,3608,3405,3214,3034,2863,2703,2551,2408,2273,2145,2025          ;0
        dw 1911,1804,1703,1607,1517,1432,1351,1276,1204,1136,1073,1012          ;12
        dw 956,902,851,804,758,716,676,638,602,568,536,506                      ;24
        dw 478,451,426,402,379,358,338,319,301,284,268,253                      ;36
        dw 239,225,213,201,190,179,169,159,150,142,134,127                      ;48
        dw 119,113,106,100,95,89,84,80,75,71,67,63                              ;60
        dw 60,56,53,50,47,45,42,40,38,36,34,32                                  ;72
        dw 30,28,27,25,24,22,21,20,19,18,17,16                                  ;84
        dw 15,14,13,13,12,11,11,10,9,9,8,8                                      ;96
        dw 7,7,7,6,6,6,5,5,5,4,4,4                                              ;108
        dw 4,4,3,3,3,3,3,2 ;,2,2,2,2                                            ;120 -> 127
PLY_AKG_PeriodTable_End:

PLY_AKG_NOTE_COUNT:         equ (PLY_AKG_PeriodTable_End - PLY_AKG_PeriodTable_End) / 2    ;How many notes there are.

PLY_AKG_End: