;       Stand-alone player of sound effects player.

;       By Targhan/Arkos, January 2017.
;       Psg optimization trick on CPC by Madram/Overlanders.

;       If you want to play sound effects along with music, check the related sound effects player besides the player!

;Initializes the sound effects. It MUST be called at any times before a first sound effect is triggered.
;It doesn't matter whether the song is playing or not, or if it has been initialized or not.
;IN:    HL = Address to the sound effects data.
PLY_SE_InitSoundEffects:
        ld (PLY_SE_PtSoundEffectTable + 1),hl
        ret


;Programs the playing of a sound effect. If a previous one was already playing on the same channel, it is replaced.
;This does not actually plays the sound effect, but programs its playing.
;Once done, call PLY_SE_Play, every frame.
;IN:    A = Sound effect number (>0!).
;       C = The channel where to play the sound effect (0, 1, 2).
;       B = Inverted volume (0 = full volume, 16 = no sound). Hardware sounds are also lowered.
PLY_SE_PlaySoundEffect:
        ;Gets the address to the sound effect.
        dec a                   ;The 0th is not encoded.
PLY_SE_PtSoundEffectTable: ld hl,0
        ld e,a
        ld d,0
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)

        ld a,b

        ;Finds the pointer to the sound effect of the desired channel.
        ld hl,PLY_SE_Channel1_SoundEffectData
        ld b,0
        sla c
        sla c
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d

        ;Now stores the inverted volume.
        inc hl
        ld (hl),a
        ret

;Stops a sound effect. Nothing happens if there was no sound effect.
;Only when the PLY_SE_Play is called are the results heard.
;IN:    A = The channel where to stop the sound effect (0, 1, 2).
PLY_SE_StopSoundEffectFromChannel:
        ;Puts 0 to the pointer of the sound effect.
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,PLY_SE_Channel1_SoundEffectData
        add hl,de
        ld (hl),d               ;0 means "no sound".
        inc hl
        ld (hl),d
        ret

;Plays the sound effects, if any has been triggered by the user.
;This must be played every frame.
;This sends new data to the PSG. Of course, nothing will be heard unless some sound effects are programmed (via PLY_SE_ProgramSoundEffect).
;The sound effects initialization method must have been called before!
PLY_SE_PlaySoundEffectsStream:
        ;Plays the sound effects on every track.
        ld ix,PLY_SE_Channel1_SoundEffectData
        ld iy,PLY_SE_PSGReg8
        ld hl,PLY_SE_PSGReg01_Instr + 1
        exx
        ld c,%11111100                  ;Shifts the R7 to the left twice, so that bit 2 and 5 only can be set for each track, below.
        call PLY_SE_PSES_Play
        ld ix,PLY_SE_Channel2_SoundEffectData
        ld iy,PLY_SE_PSGReg9
        exx
                ld hl,PLY_SE_PSGReg23_Instr + 1
        exx
        srl c                                                   ;Not RR, to make sure bit 6 is 0 (else, no more keyboard on CPC!).
        call PLY_SE_PSES_Play
        ld ix,PLY_SE_Channel3_SoundEffectData
        ld iy,PLY_SE_PSGReg10
        exx
                ld hl,PLY_SE_PSGReg45_Instr + 1
        exx
        rr c
        call PLY_SE_PSES_Play

        ld a,c
        and %111111


; -----------------------------------------------------------------------------------
; PSG access.
; -----------------------------------------------------------------------------------

;Sends the registers to the PSG. Only general registers are sent, the specific ones have already been sent.
;IN:    A = R7.
PLY_SE_SendPSGRegisters:
                ld e,#c0
                ld bc,#f680
        	out (c),e	;#f6c0          ;Madram's trick requires to start with this.
        exx
        ld bc,#f401                     ;C is the PSG register.
        
        ;Register 0 and 1.
PLY_SE_PSGReg01_Instr: ld hl,0
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
PLY_SE_PSGReg23_Instr: ld hl,0
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
PLY_SE_PSGReg45_Instr: ld hl,0
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
PLY_SE_PSGReg6_8_Instr: ld hl,0          ;L is R6, H is R8. Faster to set a 16 bits register than 2 8-bit.
PLY_SE_PSGReg6: equ PLY_SE_PSGReg6_8_Instr + 1
PLY_SE_PSGReg8: equ PLY_SE_PSGReg6_8_Instr + 2
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

PLY_SE_PSGReg9_10_Instr: ld hl,0          ;L is R9, H is R10. Faster to set a 16 bits register than 2 8-bit.
PLY_SE_PSGReg9: equ PLY_SE_PSGReg9_10_Instr + 1
PLY_SE_PSGReg10: equ PLY_SE_PSGReg9_10_Instr + 2
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
PLY_SE_PSGHardwarePeriod_Instr: ld hl,0
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
PLY_SE_PSGReg13_OldValue: ld a,255
PLY_SE_Retrig: or 0                    ;0 = no retrig. Else, should be >0xf to be sure the old value becomes a sentinel (i.e. unreachable) value.
PLY_SE_PSGReg13_Instr: ld l,0          ;Register 13.
        cp l                           ;Is the new value still the same? If yes, the new value must not be set again.
        ret z
        ;Different R13.
        ld a,l
        ld (PLY_SE_PSGReg13_OldValue + 1),a
        
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
        ld (PLY_SE_Retrig + 1),a
        ret
        





;Plays the sound stream from the given pointer to the sound effect. If 0, no sound is played.
;The given R7 is given shift twice to the left, so that this code MUST set/reset the bit 2 (sound), and maybe reset bit 5 (noise).
;This code MUST overwrite these bits because sound effects have priority over the music.
;IN:    IX = Points on the sound effect pointer. If the sound effect pointer is 0, nothing must be played.
;       IY = Points on the address where to store the volume for this channel.
;       HL'= POints on the address where to store the software period for this channel.
;       C = R7, shifted twice to the left.
;OUT:   The pointed pointer by IX may be modified as the sound advances.
;       C = R7, MUST be modified if there is a sound effect.
PLY_SE_PSES_Play:
        ;Reads the pointer pointed by IX.
        ld l,(ix + 0)
        ld h,(ix + 1)
        ld a,l
        or h
        jr nz,PLY_SE_PSES_ReadFirstByte
        ;No sound to be played. Sets the volume to 0 (else, nothing will stop the sound from continuing, contrary to the non-standalone players).
        ld (iy + 0),a
        ret

        ;Reads the first byte. What type of sound is it?
PLY_SE_PSES_ReadFirstByte:
        ld a,(hl)
        inc hl
        ld b,a
        rra
        jr c,PLY_SE_PSES_SoftwareOrSoftwareAndHardware
        rra
        jr c,PLY_SE_PSES_HardwareOnly

        ;No software, no hardware, or end/loop.
        ;-------------------------------------------
        ;End or loop?
        rra
        jr c,PLY_SE_PSES_S_EndOrLoop

        ;Real sound.
        ;Gets the volume.
        call PLY_SE_PSES_ManageVolumeFromA_Filter4Bits

        ;Noise?
        rl b
        call c,PLY_SE_PSES_ReadNoiseAndOpenNoiseChannel

        jr PLY_SE_PSES_SavePointerAndExit


PLY_SE_PSES_S_EndOrLoop:
        ;Is it an end?
        rra
        jr c,PLY_SE_PSES_S_Loop
        ;End of the sound. Marks the sound pointer with 0, meaning "no sound".
        xor a
        ld (ix + 0),a
        ld (ix + 1),a
        ret
PLY_SE_PSES_S_Loop:
        ;Loops. Reads the pointer and directly uses it.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr PLY_SE_PSES_ReadFirstByte


;Saves HL into IX, and exits. This must be called at the end of each Cell.
PLY_SE_PSES_SavePointerAndExit:
        ld (ix + 0),l
        ld (ix + 1),h
        ret

        ;Hardware only.
        ;-------------------------------------------
PLY_SE_PSES_HardwareOnly:
        ;Calls the shared code that manages everything.
        call PLY_SE_PSES_Shared_ReadRetrigHardwareEnvPeriodNoise
        ;Cuts the sound.
        set 2,c

        jr PLY_SE_PSES_SavePointerAndExit




PLY_SE_PSES_SoftwareOrSoftwareAndHardware:
        ;Software only?
        rra
        jr c,PLY_SE_PSES_SoftwareAndHardware

        ;Software.
        ;-------------------------------------------

        ;Volume.
        call PLY_SE_PSES_ManageVolumeFromA_Filter4Bits

        ;Noise?
        rl b
        call c,PLY_SE_PSES_ReadNoiseAndOpenNoiseChannel

        ;Opens the "sound" channel.
        res 2,c

        ;Reads the software period.
        call PLY_SE_PSES_ReadSoftwarePeriod

        jr PLY_SE_PSES_SavePointerAndExit


        ;Software and Hardware.
        ;-------------------------------------------
PLY_SE_PSES_SoftwareAndHardware:
        ;Calls the shared code that manages everything.
        call PLY_SE_PSES_Shared_ReadRetrigHardwareEnvPeriodNoise

        ;Reads the software period.
        call PLY_SE_PSES_ReadSoftwarePeriod

        ;Opens the sound.
        res 2,c

        jr PLY_SE_PSES_SavePointerAndExit



        ;Shared code used by the "hardware only" and "software and hardware" part.
        ;Reads the Retrig flag, the Hardware Envelope, the possible noise, the hardware period,
        ;and sets the volume to 16. The R7 sound channel is NOT modified.
PLY_SE_PSES_Shared_ReadRetrigHardwareEnvPeriodNoise:
        ;Retrig?
        rra
        ld d,a
        jr nc,PLY_SE_PSES_H_AfterRetrig
        ld a,255
        ld (PLY_SE_PSGReg13_OldValue + 1),a
PLY_SE_PSES_H_AfterRetrig:

        ;Can't use A anymore, it may have been destroyed by the retrig.

        ;The hardware envelope can be set (8-15).
        ld a,d
        and %111
        add a,8
        ld (PLY_SE_PSGReg13_Instr + 1),a

        ;Noise?
        rl b
        call c,PLY_SE_PSES_ReadNoiseAndOpenNoiseChannel

        ;Reads the hardware period.
        call PLY_SE_PSES_ReadHardwarePeriod

        ;Sets the volume to "hardware". It still may be decreased.
        ld a,16
        jp PLY_SE_PSES_ManageVolumeFromA_Hard


;Reads the noise pointed by HL, increases HL, and opens the noise channel.
PLY_SE_PSES_ReadNoiseAndOpenNoiseChannel:
        ;Reads the noise.
        ld a,(hl)
        ld (PLY_SE_PSGReg6),a
        inc hl

        ;Opens noise channel.
        res 5,c
        ret

;Reads the hardware period from HL and sets the R11/R12 registers. HL is incremented of 2.
PLY_SE_PSES_ReadHardwarePeriod:
        ld a,(hl)
        ld (PLY_SE_PSGHardwarePeriod_Instr + 1),a
        inc hl
        ld a,(hl)
        ld (PLY_SE_PSGHardwarePeriod_Instr + 2),a
        inc hl
        ret

;Reads the software period from HL and sets the period registers thanks to IY. HL is incremented of 2.
PLY_SE_PSES_ReadSoftwarePeriod:
        ld a,(hl)
        inc hl
        exx
                ld (hl),a
                inc hl
        exx
        ld a,(hl)
        inc hl
        exx
                ld (hl),a
        exx
        ret

;Reads the volume in A, decreases it from the inverted volume of the channel, and sets the volume via IY.
;IN:    A = volume, from 0 to 15 (no hardware envelope).
PLY_SE_PSES_ManageVolumeFromA_Filter4Bits:
        and %1111
;After the filtering. Useful for hardware sound (volume has been forced to 16).
PLY_SE_PSES_ManageVolumeFromA_Hard:
        ;Decreases the volume, checks the limit.
        sub (ix + PLY_SE_SoundEffectData_OffsetInvertedVolume)
        jr nc,PLY_SE_PSES_MVFA_NoOverflow
        xor a
PLY_SE_PSES_MVFA_NoOverflow:
        ld (iy + 0),a
        ret


;The data of the Channels MUST be consecutive.
PLY_SE_Channel1_SoundEffectData:
        dw 0                                            ;Points to the sound effect for the track 1, or 0 if not playing.
PLY_SE_Channel1_SoundEffectInvertedVolume:
        db 0                                            ;Inverted volume.
        db 0                                            ;Padding.
PLY_SE_Channel2_SoundEffectData:
        dw 0                                            ;Points to the sound effect for the track 2, or 0 if not playing.
        db 0                                            ;Inverted volume.
        db 0                                            ;Padding.
PLY_SE_Channel3_SoundEffectData:
        dw 0                                            ;Points to the sound effect for the track 3, or 0 if not playing.
        db 0                                            ;Inverted volume.
        db 0                                            ;Padding.

;Offset from the beginning of the data, to reach the inverted volume.
PLY_SE_SoundEffectData_OffsetInvertedVolume: equ PLY_SE_Channel1_SoundEffectInvertedVolume - PLY_SE_Channel1_SoundEffectData

        ;Checks that the pointers are consecutive.
        assert (PLY_SE_Channel2_SoundEffectData - PLY_SE_Channel1_SoundEffectData) == 4
        assert (PLY_SE_Channel3_SoundEffectData - PLY_SE_Channel2_SoundEffectData) == 4