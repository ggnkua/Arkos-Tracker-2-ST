        ;Tests the Lightweight player.

        ;Uncomment this to build a SNApshot, handy for testing (RASM feature).
        ;buildsna
        ;bankset 0

        org #1000

FLAG_25Hz: equ 0                                ;Watch out for this in your test! Should be 0 most of the time.

        di
        ld hl,#c9fb
        ld (#38),hl
        ld sp,#38

        ;Initializes the music.
        ld hl,Music
        xor a                                   ;Subsong 0.
        call PLY_LW_Init

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

	;Plays the music.
        call PLY_LW_Play

        ld bc,#7f10
        out (c),c
        ld a,#54
        out (c),a

        jr Sync


Player:
        include "../PlayerLightweight.asm"

Music:
        ;What music to play?
        ;include "../resources/MusicDeadOnTime.asm"			;25Hz! Change the flag at the top to 1.
        include "../resources/MusicMolusk.asm"                    	;50Hz! Change the flag at the top to 0.
