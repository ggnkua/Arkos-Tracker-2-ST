;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

debug=1                    ;1=skips installing a timer for replay and instead calls the player in succession - good for debugging the player

tune_freq = 50             ;not sure if this will ever change

	lea tune,a0            ;move tune to a 64k aligned buffer
	move.l #tune_buf,d0    ;not the most memory efficient thing ever but eh :)
	clr.w d0               ;align buffer
	move.l d0,a1
	move.l d0,tune_aligned_address ;sooper high powered copy!
	move.l #(tune_end+3-tune)/4-1,d0
.copy_tune:
	move.l (a0)+,(a1)+
	dbra d0,.copy_tune
		

	pea start(pc)          ;go to start with supervisor mode on
	move.w #$26,-(sp)
	trap #14

	clr.w -(sp)            ;terminate
	trap #1

start:

	move.l tune_aligned_address,a0
	bsr PLY_AKYst_Start+0  ;init player and tune

    .if !debug
	move sr,-(sp)          ;install our very own timer C
	move #$2700,sr
    move.l  $114.w,old_timer_c
    move.l  #timer_c,$114.w
	move (sp)+,sr          ;enable interrupts - tune will start playing
    .endif
	
.waitspace:

    .if debug
    move.l tune_aligned_address,a0  ;tell the player where to find the aligned tune start
	bsr PLY_AKYst_Start+2  ;play that funky music
    .endif

	cmp.b #57,$fffffc02.w  ;wait for space keypress
	bne.s .waitspace

;TODO: silence the YM

    .if !debug
	move #$2700,sr
    move.l  old_timer_c,$114.w ;restore timer c
	move (sp)+,sr          ;enable interrupts - tune will start playing
    .endif

	rts                    ;bye!

timer_c:
	sub.w #tune_freq,timer_c_ctr ;is it giro day tom?
	bgt.s timer_c_jump     ;no derek, sadly it is not giro day
	add.w #200,timer_c_ctr ;it is gyro day, let's reset the 200Hz counter
	movem.l d0-a6,-(sp)    ;save all registers, just to be on the safe side
    move.l tune_aligned_address,a0  ;tell the player where to find the aligned tune start
	bsr PLY_AKYst_Start+2  ;play that funky music
	movem.l (sp)+,d0-a6    ;restore registers

old_timer_c=*+2
timer_c_jump:
	jmp 'AKY!'             ;jump to the old timer C vector

timer_c_ctr: dc.w 200

	.include "PlayerAky.s"

	.data

tune:
	.include "ymtype.s"
	.long				;pad to 4 bytes
tune_end:

	.bss

tune_aligned_address:    .ds.l 1

	ds.b 65536
tune_buf:ds.b 65535
