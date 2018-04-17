        ;Little code that plays a song, with the addition of sound effects, all this using the Lightweight player.

        ;Don't forget to set the PLY_LW_MANAGE_SOUND_EFFECTS to 1 in the PlayerLightweight.asm! It is set to 0 by default.

        ;Use F1, F2, F3 to play the current sound effect on channel 1, 2, 3 respectively.
        ;Use F4, F5, F6 to stop a sound on channel 1, 2, 3 respectively (if there was any).
        ;Use F0/F. to decrease/increase the sound effect number.

        ;The music and sound effects are from the game "Dead on time", which runs at 25 hz. Don't be frightened by the flickering raster, then.

        ;Uncomment this to build a SNApshot, handy for testing (RASM feature).
        ;buildsna
        ;bankset 0

        org #1000

LAST_SOUND_EFFECT_INDEX: equ 13                 ;Index of the last sound effect.
SOUND_EFFECT_TO_SKIP: equ 9                     ;This one doesn't exist, skip it.

FLAG_25Hz: equ 1                                ;Watch out for this in your test! Should be 0 most of the time.

        di
        ld hl,#c9fb
        ld (#38),hl
        ld sp,#38

        ;Initializes the music.
        ld hl,Music
        xor a                                   ;Subsong 0.
        call PLY_LW_Init

        ;Initializes the sound effects.
        ld hl,SoundEffects
        call PLY_LW_InitSoundEffects

        ;Puts some markers to see the CPU.
        ld a,255
        ld hl,#c000 + 5 * #50
        ld (hl),a
        ld hl,#c000 + 6 * #50
        ld (hl),a
        ld hl,#c000 + 7 * #50
        ld (hl),a
        ld hl,#c000 + 8 * #50
        ld (hl),a
        ld hl,#c000 + 9 * #50
        ld (hl),a
        
        ld bc,#7f03
        out (c),c
        ld a,#4c
        out (c),a

Sync:   ld b,#f5
        in a,(c)
        rra
        jr nc,Sync + 2

        ei
        nop
        halt
        halt

        ;If 25 hz.
        if FLAG_25Hz
                halt
                halt
                halt
                halt
                halt
                halt
        endif

        di

        ld b,90
        djnz $

        ld bc,#7f10
        out (c),c
        ld a,#4b
        out (c),a

        call PLY_LW_Play

        ld bc,#7f10
        out (c),c
        ld a,#54
        out (c),a

        ;Reads the keyboard lines 0-2, plus 5 for space.
        ld a,0 + 64
        call Keyboard
        ld (KeyboardMaskLine0),a
        ld a,1 + 64
        call Keyboard
        ld (KeyboardMaskLine1),a
        ld a,2 + 64
        call Keyboard
        ld (KeyboardMaskLine2),a
        ld a,5 + 64
        call Keyboard
        ld (KeyboardMaskLine5),a

        ;Don't test the keyboard if a key was pressed before.
IsKeyPressed: ld a,0
        or a
        jr z,TestKeyboard
        ;Checks the keys, nothing is done if one of them is pressed.
        ld a,(KeyboardMaskLine0)
        cp #ff
        jr nz,EndKeyboard
        ld a,(KeyboardMaskLine1)
        cp #ff
        jr nz,EndKeyboard
        ld a,(KeyboardMaskLine2)
        cp #ff
        jr nz,EndKeyboard
        ld a,(KeyboardMaskLine5)
        cp #ff
        jr nz,EndKeyboard

        ;No key is pressed. We can check for a new one.
TestKeyboard:
        ;Space? Stops the song and exits (infinite loop).
        ld a,(KeyboardMaskLine5)
        cp %01111111
        jr z,StopMusicAndInfiniteLoop

        ld a,(KeyboardMaskLine1)
        cp %01111111
        jr z,PreviousSoundEffect
        cp %11011111
        jr z,PlayOnChannel1
        cp %10111111
        jp z,PlayOnChannel2
        cp %11101111
        jp z,StopChannel2

        ld a,(KeyboardMaskLine0)
        cp %01111111
        jr z,NextSoundEffect
        cp %11011111
        jr z,PlayOnChannel3
        cp %11101111
        jr z,StopChannel3

        ld a,(KeyboardMaskLine2)
        cp %11101111
        jr z,StopChannel1

        ;No key was pressed.
        xor a
        ld (IsKeyPressed + 1),a
EndKeyboard:
        jp Sync

EndKeyboardPressed:
        ld a,1
        ld (IsKeyPressed + 1),a
        jr EndKeyboard

;Stops the music, loops infinitely.
StopMusicAndInfiniteLoop:
	call PLY_LW_Stop
	jr $

;Checks a line of the keyboard.
;IN:    A = line + 64.
;OUT:   A = key mask.
Keyboard:
        ld bc,#f782
        out (c),c
        ld bc,#f40e
        out (c),c
        ld bc,#f6c0
        out (c),c
        out (c),0
        ld bc,#f792
        out (c),c
        dec b
        out (c),a
        ld b,#f4
        in a,(c)
        ld bc,#f782
        out (c),c
        dec b
        out (c),0
        ret

PreviousSoundEffect:
        ;Reaching 0 if forbidden.
        ld a,(SelectedSoundEffect)
PreviousSoundEffectNext: dec a
        jr z,EndKeyboardPressed
        cp SOUND_EFFECT_TO_SKIP         ;There is a hole in the list, skips it.
        jr z,PreviousSoundEffectNext

        ld (SelectedSoundEffect),a
        jr EndKeyboardPressed

NextSoundEffect:
        ld a,(SelectedSoundEffect)
NextSoundEffectNext: inc a
        cp LAST_SOUND_EFFECT_INDEX + 1
        jr z,EndKeyboardPressed
        cp SOUND_EFFECT_TO_SKIP         ;There is a hole in the list, skips it.
        jr z,NextSoundEffectNext

        ld (SelectedSoundEffect),a
        jr EndKeyboardPressed

PlayOnChannel1:
        ld c,0          ;Channel 1
PlayOnChannelShared:
        ld a,(SelectedSoundEffect)
        ld b,0          ;Full volume.
        call PLY_LW_PlaySoundEffect
        jr EndKeyboardPressed
PlayOnChannel2:
        ld c,1
        jr PlayOnChannelShared
PlayOnChannel3:
        ld c,2
        jr PlayOnChannelShared

StopChannel1:
        xor a
StopChannelShared:
        call PLY_LW_StopSoundEffectFromChannel
        jr EndKeyboardPressed
StopChannel2:
        ld a,1
        jr StopChannelShared
StopChannel3:
        ld a,2
        jr StopChannelShared

SelectedSoundEffect: db 1                       ;The selected sound effect (>=1).

KeyboardMaskLine0: db 255
KeyboardMaskLine1: db 255
KeyboardMaskLine2: db 255
KeyboardMaskLine5: db 255

Player:
        include "../PlayerLightweight.asm"

Music:
        ;Choose a music, or maybe silence?
        include "../resources/MusicDeadOnTime.asm"                     ;25Hz! Change the flag at the top to 1.
        ;include "../resources/MusicEmpty.asm"
        ;include "../resources/MusicMolusk.asm"                         ;50Hz! Change the flag at the top to 1.

SoundEffects:
        include "../resources/SoundEffectsDeadOnTime.asm"

