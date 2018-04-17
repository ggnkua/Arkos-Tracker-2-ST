;       Player of sound effects, for LightWeight the player.

;Initializes the sound effects. It MUST be called at any times before a first sound effect is triggered.
;It doesn't matter whether the song is playing or not, or if it has been initialized or not.
;IN:    HL = Address to the sound effects data.
PLY_LW_InitSoundEffects:
        ld (PLY_LW_SE_PtSoundEffectTable + 1),hl
        ret


;Plays a sound effect. If a previous one was already playing on the same channel, it is replaced.
;This does not actually plays the sound effect, but programs its playing.
;The music player, when called, will call the PLY_LW_PlaySoundEffectsStream method below.
;IN:    A = Sound effect number (>0!).
;       C = The channel where to play the sound effect (0, 1, 2).
;       B = Inverted volume (0 = full volume, 16 = no sound). Hardware sounds are also lowered.
PLY_LW_PlaySoundEffect:

        ;Gets the address to the sound effect.
        dec a                   ;The 0th is not encoded.
PLY_LW_SE_PtSoundEffectTable: ld hl,0
        ld e,a
        ld d,0
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)

        ld a,b

        ;Finds the pointer to the sound effect of the desired channel.
        ld hl,PLY_LW_Track1_SoundEffectData
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
;IN:    A = The channel where to stop the sound effect (0, 1, 2).
PLY_LW_StopSoundEffectFromChannel:
        ;Puts 0 to the pointer of the sound effect.
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,PLY_LW_Track1_SoundEffectData
        add hl,de
        ld (hl),d               ;0 means "no sound".
        inc hl
        ld (hl),d
        ret

;Plays the sound effects, if any has been triggered by the user.
;This does not actually send registers to the PSG, it only overwrite the required values of the registers of the player.
;The sound effects initialization method must have been called before!
;As R7 is required, this must be called after the music has been played, but BEFORE the registers are sent to the PSG.
;IN:    A = R7.
PLY_LW_PlaySoundEffectsStream:
        ;Shifts the R7 to the left twice, so that bit 2 and 5 only can be set for each track, below.
        rla
	rla

        ;Plays the sound effects on every track.
        ld ix,PLY_LW_Track1_SoundEffectData
        ld iy,PLY_LW_Track1_Registers
        ld c,a
        call PLY_LW_PSES_Play
        ld ix,PLY_LW_Track2_SoundEffectData
        ld iy,PLY_LW_Track2_Registers
        srl c                                                   ;Not RR, to make sure bit 6 is 0 (else, no more keyboard on CPC!).
        call PLY_LW_PSES_Play
        ld ix,PLY_LW_Track3_SoundEffectData
        ld iy,PLY_LW_Track3_Registers
        rr c
        call PLY_LW_PSES_Play

        ld a,c
        and %111111
        ld (PLY_LW_MixerRegister),a
        ret


;Plays the sound stream from the given pointer to the sound effect. If 0, no sound is played.
;The given R7 is given shift twice to the left, so that this code MUST set/reset the bit 2 (sound), and maybe reset bit 5 (noise).
;This code MUST overwrite these bits because sound effects have priority over the music.
;IN:    IX = Points on the sound effect pointer. If the sound effect pointer is 0, nothing must be played.
;       IY = Points at the beginning of the register structure related to the channel.
;       C = R7, shifted twice to the left.
;OUT:   The pointed pointer by IX may be modified as the sound advances.
;       C = R7, MUST be modified if there is a sound effect.
PLY_LW_PSES_Play:
        ;Reads the pointer pointed by IX.
        ld l,(ix + 0)
        ld h,(ix + 1)
        ld a,l
        or h
        ret z           ;No sound to be played? Returns immediately.

        ;Reads the first byte. What type of sound is it?
PLY_LW_PSES_ReadFirstByte:
        ld a,(hl)
        inc hl
        ld b,a
        rra
        jr c,PLY_LW_PSES_SoftwareOrSoftwareAndHardware
        rra
        jr c,PLY_LW_PSES_HardwareOnly

        ;No software, no hardware, or end/loop.
        ;-------------------------------------------
        ;End or loop?
        rra
        jr c,PLY_LW_PSES_S_EndOrLoop

        ;Real sound.
        ;Gets the volume.
        call PLY_LW_PSES_ManageVolumeFromA_Filter4Bits

        ;Noise?
        rl b
        call c,PLY_LW_PSES_ReadNoiseAndOpenNoiseChannel

        jr PLY_LW_PSES_SavePointerAndExit


PLY_LW_PSES_S_EndOrLoop:
        ;Is it an end?
        rra
        jr c,PLY_LW_PSES_S_Loop
        ;End of the sound. Marks the sound pointer with 0, meaning "no sound".
        xor a
        ld (ix + 0),a
        ld (ix + 1),a
        ret
PLY_LW_PSES_S_Loop:
        ;Loops. Reads the pointer and directly uses it.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr PLY_LW_PSES_ReadFirstByte


;Saves HL into IX, and exits. This must be called at the end of each Cell.
PLY_LW_PSES_SavePointerAndExit:
        ld (ix + 0),l
        ld (ix + 1),h
        ret

        ;Hardware only.
        ;-------------------------------------------
PLY_LW_PSES_HardwareOnly:
        ;Calls the shared code that manages everything.
        call PLY_LW_PSES_Shared_ReadRetrigHardwareEnvPeriodNoise
        ;Cuts the sound.
        set 2,c

        jr PLY_LW_PSES_SavePointerAndExit




PLY_LW_PSES_SoftwareOrSoftwareAndHardware:
        ;Software only?
        rra
        jr c,PLY_LW_PSES_SoftwareAndHardware

        ;Software.
        ;-------------------------------------------

        ;Volume.
        call PLY_LW_PSES_ManageVolumeFromA_Filter4Bits

        ;Noise?
        rl b
        call c,PLY_LW_PSES_ReadNoiseAndOpenNoiseChannel

        ;Opens the "sound" channel.
        res 2,c

        ;Reads the software period.
        call PLY_LW_PSES_ReadSoftwarePeriod

        jr PLY_LW_PSES_SavePointerAndExit


        ;Software and Hardware.
        ;-------------------------------------------
PLY_LW_PSES_SoftwareAndHardware:
        ;Calls the shared code that manages everything.
        call PLY_LW_PSES_Shared_ReadRetrigHardwareEnvPeriodNoise

        ;Reads the software period.
        call PLY_LW_PSES_ReadSoftwarePeriod

        ;Opens the sound.
        res 2,c

        jr PLY_LW_PSES_SavePointerAndExit



        ;Shared code used by the "hardware only" and "software and hardware" part.
        ;Reads the Retrig flag, the Hardware Envelope, the possible noise, the hardware period,
        ;and sets the volume to 16. The R7 sound channel is NOT modified.
PLY_LW_PSES_Shared_ReadRetrigHardwareEnvPeriodNoise:
        ;Retrig?
        rra
        ld d,a
        jr nc,PLY_LW_PSES_H_AfterRetrig
        ld a,255
        ld (PLY_LW_SetReg13Old + 1),a
PLY_LW_PSES_H_AfterRetrig:

        ;Can't use A anymore, it may have been destroyed by the retrig.

        ;The hardware envelope can be set (8-15).
        ld a,d
        and %111
        add a,8
        ld (PLY_LW_SetReg13 + 1),a

        ;Noise?
        rl b
        call c,PLY_LW_PSES_ReadNoiseAndOpenNoiseChannel

        ;Reads the hardware period.
        call PLY_LW_PSES_ReadHardwarePeriod

        ;Sets the volume to "hardware". It still may be decreased.
	ld a,16
        jp PLY_LW_PSES_ManageVolumeFromA_Hard


;Reads the noise pointed by HL, increases HL, and opens the noise channel.
PLY_LW_PSES_ReadNoiseAndOpenNoiseChannel:
        ;Reads the noise.
        ld a,(hl)
        ld (PLY_LW_NoiseRegister),a
        inc hl

        ;Opens noise channel.
        res 5,c
        ret

;Reads the hardware period from HL and sets the R11/R12 registers. HL is incremented of 2.
PLY_LW_PSES_ReadHardwarePeriod:
        ld a,(hl)
        ld (PLY_LW_Reg11),a
        inc hl
        ld a,(hl)
        ld (PLY_LW_Reg12),a
        inc hl
        ret

;Reads the software period from HL and sets the period registers thanks to IY. HL is incremented of 2.
PLY_LW_PSES_ReadSoftwarePeriod:
        ld a,(hl)
        ld (iy + PLY_LW_Registers_OffsetSoftwarePeriodLSB),a
        inc hl
        ld a,(hl)
        ld (iy + PLY_LW_Registers_OffsetSoftwarePeriodMSB),a
        inc hl
        ret

;Reads the volume in A, decreases it from the inverted volume of the channel, and sets the volume via IY.
;IN:    A = volume, from 0 to 15 (no hardware envelope).
PLY_LW_PSES_ManageVolumeFromA_Filter4Bits:
        and %1111
;After the filtering. Useful for hardware sound (volume has been forced to 16).
PLY_LW_PSES_ManageVolumeFromA_Hard:
        ;Decreases the volume, checks the limit.
        sub (ix + PLY_LW_SoundEffectData_OffsetInvertedVolume)
        jr nc,PLY_LW_PSES_MVFA_NoOverflow
        xor a
PLY_LW_PSES_MVFA_NoOverflow:
        ld (iy + PLY_LW_Registers_OffsetVolume),a
        ret


;The data of the Tracks MUST be consecutive.
PLY_LW_Track1_SoundEffectData:
        dw 0                                            ;Points to the sound effect for the track 1, or 0 if not playing.
PLY_LW_Track1_SoundEffectInvertedVolume:
        db 0                                            ;Inverted volume.
        db 0                                            ;Padding.
PLY_LW_Track2_SoundEffectData:
        dw 0                                            ;Points to the sound effect for the track 2, or 0 if not playing.
        db 0                                            ;Inverted volume.
        db 0                                            ;Padding.
PLY_LW_Track3_SoundEffectData:
        dw 0                                            ;Points to the sound effect for the track 3, or 0 if not playing.
        db 0                                            ;Inverted volume.
        db 0                                            ;Padding.

;Offset from the beginning of the data, to reach the inverted volume.
PLY_LW_SoundEffectData_OffsetInvertedVolume: equ PLY_LW_Track1_SoundEffectInvertedVolume - PLY_LW_Track1_SoundEffectData

        ;Checks that the pointers are consecutive.
        assert (PLY_LW_Track2_SoundEffectData - PLY_LW_Track1_SoundEffectData) == 4
        assert (PLY_LW_Track3_SoundEffectData - PLY_LW_Track2_SoundEffectData) == 4