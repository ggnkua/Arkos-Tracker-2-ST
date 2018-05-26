;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

debug=0                             ;1=skips installing a timer for replay and instead calls the player in succession
                                    ;good for debugging the player but plays the tune in turbo mode :)
showcpu=0

tune_freq = 50                     ;tune frequency in ticks per second

	pea start(pc)                   ;go to start with supervisor mode on
	move.w #$26,-(sp)
	trap #14

	clr.w -(sp)                     ;terminate
	trap #1

start:

    move.b $484.w,-(sp)             ;save old keyclick state
    clr.b $484.w                    ;keyclick off, key repeat off

	bsr tune+0                      ;init player and tune

	move sr,-(sp)                   ;install our very own timer C
	move #$2700,sr
    move.l  $114.w,old_timer_c      ;so how do you turn the player on?
    move.l  #timer_c,$114.w         ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
	move (sp)+,sr                   ;enable interrupts - tune will start playing
	
.waitspace:

	cmp.b #57,$fffffc02.w           ;wait for space keypress
	bne.s .waitspace

    move sr,-(sp)
	move #$2700,sr
    move.l  old_timer_c,$114.w      ;restore timer c
    move.b  #$C0,$FFFFFA23.w        ;and how would you stop the ym?
	bsr tune+4
	move (sp)+,sr                   ;enable interrupts - tune will stop playing
    
    move.b (sp)+,$484.w             ;restore keyclick state

	rts                             ;bye!

    .if !debug
timer_c:
	sub.w #tune_freq,timer_c_ctr    ;is it giiiirooo day tom?
	bgt.s timer_c_jump              ;sadly derek, no it's not giro day
	add.w #200,timer_c_ctr          ;it is giro day, let's reset the 200Hz counter
	movem.l d0-a6,-(sp)             ;save all registers, just to be on the safe side
	.if showcpu
    not.w $ffff8240.w
	.endif
	bsr tune+8
	.if showcpu
    not.w $ffff8240.w
	.endif
	movem.l (sp)+,d0-a6             ;restore registers

old_timer_c=*+2
timer_c_jump:
	jmp 'AKY!'                      ;jump to the old timer C vector
timer_c_ctr: dc.w 200
    .endif



	.data
	
	.even
tune:
	.incbin "sndh.sndh"
;   .include "UltraSyd - Fractal.s"
;	.include "UltraSyd - YM Type.s"
;	.include "Targhan - Midline Process - Carpet.s"
;	.include "Targhan - Midline Process - Molusk.s"
;	.include "Pachelbel's Canon in D major 003.s"
;	.long				            ;pad to 4 bytes
;tune_end:

	.bss

