        ;Tests the AKY player.

	;Uncomment this to build a SNApshot, handy for testing (RASM feature).
        ;buildsna
        ;bankset 0
		
        org #1000
Start:  equ $

        di
        ld hl,#c9fb
        ld (#38),hl

		;Initializes the music.
        ld hl,Music_Start
        call Main_Player_Start + 0

        ;Some dots on the screen to judge how much CPU takes the player.
        ld a,255
        ld hl,#c000 + 5 * #50
        ld (hl),a
        ld hl,#c000 + 6 * #50
        ld (hl),a
        ld hl,#c000 + 7 * #50
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

        ld bc,#7f10
        out (c),c
        ld a,#4b
        out (c),a
        
        call Main_Player_Start + 3                ;Play.
        
        ld bc,#7f10
        out (c),c
        ld a,#54
        out (c),a

        jr Sync

Main_Player_Start:
        ;What player to use?
        include "../PlayerAky.asm"
        ;include "../PlayerAkyAccurate.asm"
        ;include "../PlayerAky9Channels.asm"
        ;include "../PlayerAkyStabilized_CPC.asm"
Main_Player_End:

Music_Start:
        ;What music to play?
        ;include "../resources/MusicMolusk.asm"
        include "../resources/MusicBoulesEtBits.asm"
        ;include "../resources/Music9Channels.asm"		;Only for using the 9 Channels player, requires the PlayCity hardware.

Music_End: