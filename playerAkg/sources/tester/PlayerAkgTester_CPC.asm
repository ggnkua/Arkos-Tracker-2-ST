        ;Tests the AKG player.

	;Uncomment this to build a SNApshot, handy for testing (RASM feature).
        ;buildsna
        ;bankset 0
		
        org #1000
Start:  equ $

        di
        ld hl,#c9fb
        ld (#38),hl

        ld hl,Music_Start
        xor a                   ;Subsong 0.
        call PLY_AKG_Init

        ;Some dots on the screen to judge how much CPU takes the player.
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
        di

        ld sp,#38

        ld b,90
        djnz $

        ;Calls the player, shows some colors to see the consumed CPU.
        ld bc,#7f10
        out (c),c
        ld a,#4b
        out (c),a
        call PLY_AKG_Play
        ld bc,#7f10
        out (c),c
        ld a,#54
        out (c),a

        ;If space is pressed, stops the music.
        ld a,5 + 64
        call Keyboard
        cp #7f
        jr nz,Sync

        ;Stops the music.
        call PLY_AKG_Stop
        ;Endless loop!
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

Main_Player_Start:
        include "../PlayerAkg.asm"
Main_Player_End:

Music_Start:
        include "../resources/Music_AHarmlessGrenade.asm"
Music_End:
