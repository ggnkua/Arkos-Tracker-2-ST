;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

USE_EVENTS=1

  .if USE_EVENTS
  .abs
events_pos: ds.l 1
event_counter: ds.w 1
event_byte: ds.b 1
event_flag: ds.b 1
events_size: ds.b 1
  .68000
  .even
  .endif


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

  .if USE_EVENTS
    lea tune,a0
    move.w 2(a0),d0
    lea 2(a0,d0.w),a0                ;point to sndh_init
    ;lea -events_size(a0),d0         ;point to events struct inside the sndh
    lea -events_size(a0),a0         ;point to events struct inside the sndh
    move.l a0,events_ptr            ;save address for use by the replay interrupt
  .endif

	bsr tune+0                    ;init player and tune

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
	bsr.s tune+4
	move (sp)+,sr                   ;enable interrupts - tune will stop playing
    
    move.b (sp)+,$484.w             ;restore keyclick state

	rts                             ;bye!

    .if !debug
timer_c:
	sub.w #tune_freq,timer_c_ctr    ;is it giiiirooo day tom?
	bgt.s timer_c_jump              ;sadly derek, no it's not giro day
	add.w #200,timer_c_ctr          ;it is giro day, let's reset the 200Hz counter
  .if USE_EVENTS
    move.w #$fff,$ffff8240.w
  .endif
	movem.l d0-a6,-(sp)             ;save all registers, just to be on the safe side
	.if showcpu
    not.w $ffff8240.w
	.endif
	bsr.s tune+8
	.if showcpu
    not.w $ffff8240.w
	.endif

  .if USE_EVENTS
    move.l events_ptr,a0
    tst.b event_flag(a0)
    beq.s no_event_yet
    clr.b event_flag(a0)
    cmp.b #2,event_byte(a0)         ;we have used #2 as our sync event number so we check for that (non-zero event_flag might be a loop point)
    bne.s no_event_yet   
    move.w #$00f,$ffff8240.w         ;visual signal
no_event_yet:
  .endif

	movem.l (sp)+,d0-a6             ;restore registers

old_timer_c=*+2
timer_c_jump:
	jmp 'AKY!'                      ;jump to the old timer C vector
timer_c_ctr: dc.w 200
    .endif


  .if USE_EVENTS
events_ptr: dc.l 0
  .endif

	.data
	
	.even
tune:
	.incbin "tunes/Love Potion Level 4 (Hello) 001 (looped) with events.sndh"
tune_end:

	.bss

