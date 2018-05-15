;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

debug=0                             ;1=skips installing a timer for replay and instead calls the player in succession
                                    ;good for debugging the player but plays the tune in turbo mode :)
show_cpu=1

use_vbl=1                           ;if enabled, vbl is used instead of timer c

UNROLLED_CODE=1                     ;Uncomment this line to enable unrolled slightly faster YM register reading code

tune_freq = 200                     ;tune frequency in ticks per second

    pea start(pc)                   ;go to start with supervisor mode on
    move.w #$26,-(sp)
    trap #14

    clr.w -(sp)                     ;terminate
    trap #1

start:

    move.b $484.w,-(sp)             ;save old keyclick state
    clr.b $484.w                    ;keyclick off, key repeat off

    move.l #tune,a0
    bsr PLY_AKYst_Start+0           ;init player and tune

    .if !debug
    move sr,-(sp)
    move #$2700,sr
    .if use_vbl=1                   ;install our very own vbl
    move.l  $70.w,old_vbl           ;so how do you turn the player on?
    move.l  #vbl,$70.w              ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
    .else                           ;install our very own timer C
    move.l  $114.w,old_timer_c      ;so how do you turn the player on?
    move.l  #timer_c,$114.w         ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
    .endif
    move (sp)+,sr                   ;enable interrupts - tune will start playing
    .endif
    
.waitspace:

    .if debug
    move.l #tune,a0  ;tell the player where to find the tune start
    bsr PLY_AKYst_Start+2           ;play that funky music
    .endif

    cmp.b #57,$fffffc02.w           ;wait for space keypress
    bne.s .waitspace

    .if !debug
    move sr,-(sp)
    move #$2700,sr
    .if use_vbl=1
    move.l  old_vbl,$70.w           ;restore vbl
    .else
    move.l  old_timer_c,$114.w      ;restore timer c
    move.b  #$C0,$FFFFFA23.w        ;and how would you stop the ym?
    .endif
i set 0
    rept 14
    move.l  #i,$FFFF8800.w          ;(makes gensture of turning an engine key off) just turn it off!
i set i+$01010000
    endr
    move (sp)+,sr                   ;enable interrupts - tune will stop playing
    .endif
    
    move.b (sp)+,$484.w             ;restore keyclick state

    rts                             ;bye!

    .if !debug
    .if use_vbl=1
vbl:
    movem.l d0-a6,-(sp)

    move.w #2047,d0                 ;small softwre pause so we can see the cpu time
.wait: dbra d0,.wait
    move.l #tune,a0  ;tell the player where to find the tune start
    .if show_cpu
    not.w $ffff8240.w
    .endif
    bsr.s PLY_AKYst_Start+2         ;play that funky music
    .if show_cpu
    not.w $ffff8240.w
    .endif
    movem.l (sp)+,d0-a6    
old_vbl=*+2
    jmp 'GGN!'
    .else
timer_c:
    sub.w #tune_freq,timer_c_ctr    ;is it giiiirooo day tom?
    bgt.s timer_c_jump              ;sadly derek, no it's not giro day
    add.w #200,timer_c_ctr          ;it is giro day, let's reset the 200Hz counter
    movem.l d0-a6,-(sp)             ;save all registers, just to be on the safe side
    .if show_cpu
    not.w $ffff8240.w
    .endif
    move.l #tune,a0  ;tell the player where to find the tune start
    .if show_cpu
    bsr.s PLY_AKYst_Start+2         ;play that funky music
    .endif
    not.w $ffff8240.w
    movem.l (sp)+,d0-a6             ;restore registers

old_timer_c=*+2
timer_c_jump:
    jmp 'AKY!'                      ;jump to the old timer C vector
timer_c_ctr: dc.w 200
    .endif
    .endif

    .include "PlayerAky.s"

    .data

tune:
;   .include "tunes/UltraSyd - Fractal.s"
;    .include "tunes/UltraSyd - YM Type.s"
;    .include "tunes/Targhan - Midline Process - Carpet.s"
;    .include "tunes/Targhan - Midline Process - Molusk.s"
    .include "tunes/Targhan - DemoIzArt - End Part.s"
;    .include "tunes/Pachelbel's Canon in D major 003.s"
;    .include "tunes/Interleave THIS! 015.s"
;    .include "tunes/Knightmare 200Hz 017.s"
;    .include "tunes/Ten Little Endians_015.s"
;    .include "tunes/Just add cream 020.s"
    .long                            ;pad to 4 bytes
tune_end:

    .bss

