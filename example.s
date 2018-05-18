;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

debug=0                             ;1=skips installing a timer for replay and instead calls the player in succession
                                    ;good for debugging the player but plays the tune in turbo mode :)
show_cpu=1                          ;if 1, display a bar showing CPU usage
use_vbl=1                           ;if enabled, vbl is used instead of timer c
disable_timers=0                    ;if 1, stops all MFP timers, for better CPU usage display
UNROLLED_CODE=0                     ;if 1, enable unrolled slightly faster YM register reading code
SID_VOICES=1                        ;if 1, enable SID voices (takes more CPU time!)
SNDH_PLAYER=0                       ;if 1, turn all player code PC relative
AVOID_SMC=0                         ;if 1, assemble the player without SMC stuff, so it should be fine for CPUs with cache
tune_freq = 050                     ;tune frequency in ticks per second

    pea start(pc)                   ;go to start with supervisor mode on
    move.w #$26,-(sp)
    trap #14

    clr.w -(sp)                     ;terminate
    trap #1

start:

    move.b $484.w,-(sp)             ;save old keyclick state
    clr.b $484.w                    ;keyclick off, key repeat off

    lea tune,a0
    bsr PLY_AKYst_Start+0           ;init player and tune
    .if SID_VOICES
    bsr sid_emu+0                   ;init SID voices player
    .endif

    .if !debug
    move sr,-(sp)
    move #$2700,sr
    .if use_vbl=1                   ;install our very own vbl

    .if disable_timers=1
    lea save_mfp(pc),a0
    move.b $fffffa07.w,(a0)+        ;save MFP timer status
    move.b $fffffa0b.w,(a0)+
    move.b $fffffa0f.w,(a0)+
    move.b $fffffa13.w,(a0)+
    move.b $fffffa09.w,(a0)+
    move.b $fffffa0d.w,(a0)+
    move.b $fffffa11.w,(a0)+
    move.b $fffffa15.w,(a0)+
    clr.b $fffffa07.w               ;disable all timers
    clr.b $fffffa0b.w
    clr.b $fffffa0f.w
    clr.b $fffffa13.w
    clr.b $fffffa09.w
    clr.b $fffffa0d.w
    clr.b $fffffa11.w
    clr.b $fffffa15.w
    .endif
    
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
    lea tune,a0                     ;tell the player where to find the tune start
    bsr PLY_AKYst_Start+2           ;play that funky music
    .if SID_VOICES
    lea values_store(pc),a0
    bsr as+8
    .endif
    .endif

    cmp.b #57,$fffffc02.w           ;wait for space keypress
    bne.s .waitspace

    .if !debug
    move sr,-(sp)
    move #$2700,sr
    .if use_vbl=1
    move.l  old_vbl,$70.w           ;restore vbl

    .if SID_VOICES
    bsr sid_emu+4
    .endif
    .if disable_timers=1
    lea save_mfp(pc),a0
    move.b (a0)+,$fffffa07.w        ;restore MFP timer status
    move.b (a0)+,$fffffa0b.w
    move.b (a0)+,$fffffa0f.w
    move.b (a0)+,$fffffa13.w
    move.b (a0)+,$fffffa09.w
    move.b (a0)+,$fffffa0d.w
    move.b (a0)+,$fffffa11.w
    move.b (a0)+,$fffffa15.w
    move.b #192,$fffffa23.w         ;kick timer C back into activity
    .endif

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

    .if 0
    move.w #2047,d0                 ;small softwre pause so we can see the cpu time
.wait: dbra d0,.wait
    .endif

    lea tune,a0                 ;tell the player where to find the tune start
    .if show_cpu
    not.w $ffff8240.w
    .endif
    bsr.s PLY_AKYst_Start+2         ;play that funky music
    .if SID_VOICES
    lea values_store(pc),a0
    bsr sid_emu+8
    .endif
    .if show_cpu
    not.w $ffff8240.w
    .endif
    movem.l (sp)+,d0-a6    
    .if disable_timers!=1
old_vbl=*+2
    jmp 'GGN!'
    .else
    rte
old_vbl: ds.l 1
save_mfp:   ds.l 16
    .endif
    .else
timer_c:
    sub.w #tune_freq,timer_c_ctr    ;is it giiiirooo day tom?
    bgt.s timer_c_jump              ;sadly derek, no it's not giro day
    add.w #200,timer_c_ctr          ;it is giro day, let's reset the 200Hz counter
    movem.l d0-a6,-(sp)             ;save all registers, just to be on the safe side
    .if show_cpu
    not.w $ffff8240.w
    .endif
    lea tune,a0                     ;tell the player where to find the tune start
    .if show_cpu
    bsr.s PLY_AKYst_Start+2         ;play that funky music
    .if SID_VOICES
    lea values_store(pc),a0
    bsr as+8
    .endif
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

    .if SID_VOICES
    .include "sid.s"
    .endif

    .data

tune:
;   .include "tunes/UltraSyd - Fractal.s"
;    .include "tunes/UltraSyd - YM Type.s"
;    .include "tunes/Targhan - Midline Process - Carpet.s"
;    .include "tunes/Targhan - Midline Process - Molusk.s"
;    .include "tunes/Targhan - DemoIzArt - End Part.s"
    .include "tunes/Pachelbel's Canon in D major 003.s"
;    .include "tunes/Interleave THIS! 015.s"
;    .include "tunes/Knightmare 200Hz 017.s"
;    .include "tunes/Ten Little Endians_015.s"
;    .include "tunes/Just add cream 020.s"
    .long                            ;pad to 4 bytes
tune_end:

    .bss

