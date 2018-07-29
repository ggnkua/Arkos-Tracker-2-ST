;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

;--------------------------------------------------------------
;-- Pre-processing of events
;
; # Export "you_never_can_tell.events.s"
; # Copy that file to "you_never_can_tell.events.words.s"
; # The very last dc.w is the loopback label. Change the dc.w to dc.l
; # Change all dc.b's to dc.w
;
;-- Pre-processing of events
;--------------------------------------------------------------
;-- Using events to turn on/off SID on channels
;
; # In this file, set:
;     SID_VOICES=1
;     USE_EVENTS=1
;     USE_SID_EVENTS=1
; # In Arkos Tracker 2, all events starting with F (F0, F1, F2 etc up to FF)
;   are now SID events. The lowest three bits control which channels are SID-
;   enabled. Timers used are ABD (for channels ABC, respectively).
;   The bit pattern is 1111 xABC, which means:
;     %0000 : $F0 [unused]
;     %0001 : $F1 set channel C to SID off
;     %0010 : $F2 set channel B to SID off
;     %0011 : $F3 set channels B and C to SID off
;     %0100 : $F4 set channel A to SID off
;     %0101 : $F5 set channels A and C to SID off
;     %0110 : $F6 set channels A and B to SID off
;     %0111 : $F7 all channels SID off
;     %1000 : $F8 [unused]
;     %1001 : $F9 set channel C to SID on
;     %1010 : $FA set channel B to SID on
;     %1011 : $FB set channels B and C to SID on
;     %1100 : $FC set channel A to SID on
;     %1101 : $FD set channels A and C to SID on
;     %1110 : $FE set channels A and B to SID on
;     %1111 : $FF all channels SID on
;-- Using events to turn on/off SID on channels
;--------------------------------------------------------------


debug=0                             ;1=skips installing a timer for replay and instead calls the player in succession
                                    ;good for debugging the player but plays the tune in turbo mode :)
show_cpu=1                          ;if 1, display a bar showing CPU usage
use_vbl=0                           ;if 1, vbl is used instead of timer c
vbl_pause=0                         ;if 1, a small pause is inserted in the vbl code so the cpu usage is visible
disable_timers=0                    ;if 1, stops all MFP timers, for better CPU usage display
UNROLLED_CODE=0                     ;if 1, enable unrolled slightly faster YM register reading code
SID_VOICES=1                        ;if 1, enable SID voices (takes more CPU time!)
PC_REL_CODE=0                       ;if 1, make code PC relative (helps if you move the routine around, like for example SNDH)
AVOID_SMC=0                         ;if 1, assemble the player without SMC stuff, so it should be fine for CPUs with cache
tune_freq = 200                     ;tune frequency in ticks per second
USE_EVENTS=1                        ;if 1, include events, and parse them
USE_SID_EVENTS=1                    ;if 1, use events to control SID.
                                    ;  $Fn=sid setting, where n bits are xABC for which voice to use SID
DUMP_SONG=0                         ;if 1, produce a YM dump of the tune. DOES NOT WORK WITH SID OR EVENTS YET!
DUMP_SONG_SKIP_FRAMES_FROM_START=0  ;if dumping, how many frames we should skip from the start
DUMP_SONG_FRAMES_AMOUNT=50*60       ;if dumping, the number of frames to dump

; Include vasm compatible macros if we're assembling under it
    if _VASM_=1
    include "vasm.s"
    endif

  ; error checking illegal combination of SID_VOICES, USE_EVENTS and USE_SID_EVENTS
  if USE_SID_EVENTS=1
    if USE_EVENTS=0
      error "You can't use sid events if USE_EVENTS is 0"
    endif ; .if USE_EVENTS=0
    if SID_VOICES=0
      error "You can't use sid events if SID_VOICES is 0"
    endif ; .if USE_EVENTS=0
  endif ; .if USE_SID_EVENTS=1

EVENT_CHANNEL_A_MASK equ 8+4
EVENT_CHANNEL_B_MASK equ 8+2
EVENT_CHANNEL_C_MASK equ 8+1

;
; Event parser, in macro form (let's not waste a bsr and rts!)
; Note: movex macro is defined in PlayerAky.s
;
    if _RMAC_=1
    macro clrx dst
    if PC_REL_CODE
        clr\! \dst - PLY_AKYst_Init(a4)
    else
        clr\! \dst
    endif
    endm
    macro tstx dst
    if PC_REL_CODE
        tst\! \dst - PLY_AKYst_Init(a4)
    else
        tst\! \dst
    endif
    endm
    macro movex src,dst
    if PC_REL_CODE
        move\! \src,\dst - PLY_AKYst_Init(a4)
    else
        move\! \src,\dst
    endif
    endm

	macro parse_events
    ;########################################################
    ;## Parse tune events

    if USE_EVENTS
    if PC_REL_CODE
    movem.l d0/a0/a4,-(sp)
    lea PLY_AKYst_Init(pc),a4       ; base pointer for PC relative stores
    else
    movem.l d0/a0,-(sp)
    endif
    clrx.b event_flag
.event_do_count:
    move.w event_counter(pc),d0
    subq #1,d0
    bne.s .nohit
.event_read_val:
    ; time to read value
    move.l events_pos(pc),a0
    addq #2,a0
    move.w (a0)+,d0
    movex.b d0,event_byte
    movex.b #1,event_flag           ; there's a new event value to fetch
    move.w (a0),d0
    bne.s .noloopback
    ; loopback
    addq #2,a0
    move.l (a0),a0
    movex.l a0,events_pos
    movex.w (a0),event_counter
    bra.s .event_do_count
.noloopback:
    movex.l a0,events_pos
.nohit:
    movex.w d0,event_counter
    ;done
    if PC_REL_CODE
    movem.l (sp)+,d0/a0/a4
    else
    movem.l (sp)+,d0/a0
    endif
    endif ; .if USE_EVENTS

;
; SID events are in the range of $f0-$ff
; For opcodes $f0 and $f8 no write on channel enable registers is performed
; The rationale for this is that previous state will be unchanged
; The same applies for opcodes that shouldn't affect channels. For example, $f1
; will turn off channel C's SID voices, BUT it won't affect the other two!
;
    if USE_SID_EVENTS
    if PC_REL_CODE
    movem.l d0/d1/a4,-(sp)
    lea PLY_AKYst_Init(pc),a4       ; base pointer for PC relative stores
    else
    movem.l d0-d1,-(sp)
    endif
    tstx.b event_flag
    beq.s .no_event
    move.b event_byte(pc),d0
    move.b d0,d1
    and.b #$f0,d1
    cmp.b #$f0,d1
    bne.s .no_sid_event
    move.b d0,d1
; lsl.b #4 below explained:
; for sid events, d1 is going to be $f0 to $ff
; we mask this with the channel mask (bit 0, 1 or 2) and keep bit 3 intact too.
; if we shift this left by 4 places then it's $00 to $f0 with $10 increments.
; after this transformation, if we test d1 as a byte, the positive values will
; mean "turn channel off", the negative ones "turn channel on" and 0 value
; will do nothing.
    and.b #EVENT_CHANNEL_A_MASK,d1
    lsl.b #4,d1
    beq.s .skip_chan_a              ;don't write anything if it's 0 (keep old state)
    movex.b d1,chan_a_sid_on
.skip_chan_a:
    move.b d0,d1
    and.b #EVENT_CHANNEL_B_MASK,d1
    lsl.b #4,d1
    beq.s .skip_chan_b               ;don't write anything if it's 0 (keep old state)
    movex.b d1,chan_b_sid_on
.skip_chan_b:
    move.b d0,d1
    and.b #EVENT_CHANNEL_C_MASK,d1
    lsl.b #4,d1
    beq.s .skip_chan_c              ;don't write anything if it's 0 (keep old state)
    movex.b d1,chan_c_sid_on
.skip_chan_c:
.no_sid_event:
.no_event:
    if PC_REL_CODE
    movem.l (sp)+,d0/d1/a4
    else
    movem.l (sp)+,d0-d1
    endif     
    endif ; .if USE_SID_EVENTS

    ;## Parse tune events
    ;########################################################
	endm
    endif

    pea start(pc)                   ;go to start with supervisor mode on
    move.w #$26,-(sp)
    trap #14

    clr.w -(sp)                     ;terminate
    trap #1

start:

    if SID_VOICES & USE_SID_EVENTS
    lea PLY_AKYst_Init(pc),a4       ;base pointer for PC relative stores
    clrx.b chan_a_sid_on
    clrx.b chan_b_sid_on
    clrx.b chan_c_sid_on
    endif ; .if SID_VOICES
    
    if USE_EVENTS
    lea PLY_AKYst_Init(pc),a4       ;base pointer for PC relative stores
    ; reset event pos to start of event list
    lea tune_events(pc),a0
    movex.l a0,events_pos
    movex.w (a0),event_counter
    endif ; .if USE_EVENTS
    
    move.b $484.w,-(sp)             ;save old keyclick state
    clr.b $484.w                    ;keyclick off, key repeat off

    lea tune,a0
    bsr PLY_AKYst_Init              ;init player and tune
    if SID_VOICES
    bsr sid_ini                     ;init SID voices player
    endif ; .if SID_VOICES

    if DUMP_SONG                    ; Let's dump the tune!
    move.w $ffff8240.w,-(sp)
    lea tune(pc),a0
    ; First, skip as many frames as the user requested
    move.w #DUMP_SONG_SKIP_FRAMES_FROM_START-1,d7
    blt.s .skip_frames_done
.skip_frames:
    movem.l d0-a6,-(sp)
    bsr PLY_AKYst_Play
    movem.l (sp)+,d0-a6
    dbra d7,.skip_frames
.skip_frames_done:

    ; Now, start dumping
    ;TODO: error out if DUMP_SONG_FRAMES_AMOUNT<0!
    move.w #DUMP_SONG_FRAMES_AMOUNT-1,d7
    lea dump_buffer,a6
.dumpframes:
    clr.w (a6)
    movem.l d0-a6,-(sp)
    bsr PLY_AKYst_Play
    movem.l (sp)+,d0-a6
    moveq #13-1,d6
    move.w #(13)*4+2,d1
    moveq #0,d0
    tst.w (a6)+
    beq.s .fill_longs
    moveq #14-1,d6
    move.w #(14)*4+2,d1
.fill_longs:
    move.w 2(a6),d0
    move.l d0,(a6,d1.w)
    move.l d0,(a6)+
    add.l #$01000000,d0
    dbra d6,.fill_longs
    add.w #$135,$ffff8240.w
    dbra d7,.dumpframes
    move.w (sp)+,$ffff8240.w
    endif

    if !debug
    move sr,-(sp)
    move #$2700,sr
    if use_vbl=1                    ;install our very own vbl

    if disable_timers=1
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
    endif ; .if disable_timers=1
    
    move.l  $70.w,old_vbl           ;so how do you turn the player on?
    move.l  #vbl,$70.w              ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
    else ; .if use_vbl=1            ;install our very own timer C
    move.l  $114.w,old_timer_c      ;so how do you turn the player on?
    move.l  #timer_c,$114.w         ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
    endif ; .if use_vbl=1
    move (sp)+,sr                   ;enable interrupts - tune will start playing
    endif ; .if !debug
    
.waitspace:

    if debug
    lea tune,a0                     ;tell the player where to find the tune start
    bsr PLY_AKYst_Play              ;play that funky music
    if SID_VOICES
    lea values_store(pc),a0
    bsr sid_play
    endif ; .if SID_VOICES
    endif ; .if debug

    if DUMP_SONG
    cmp.w #DUMP_SONG_FRAMES_AMOUNT,current_frame
    beq.s exit
    endif

    cmp.b #57,$fffffc02.w           ;wait for space keypress
    bne.s .waitspace

exit:
    if !debug
    move sr,-(sp)
    move #$2700,sr
    if use_vbl=1
    move.l  old_vbl,$70.w           ;restore vbl

    if SID_VOICES
    bsr sid_exit
    endif
    if disable_timers=1
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
    endif

    else
    if SID_VOICES
    bsr sid_exit
    endif
    move.l  old_timer_c,$114.w      ;restore timer c
    move.b  #$C0,$FFFFFA23.w        ;and how would you stop the ym?
    endif
i set 0
    rept 14
    move.l  #i,$FFFF8800.w          ;(makes gesture of turning an engine key off) just turn it off!
i set i+$01000000
    endr
    move (sp)+,sr                   ;enable interrupts - tune will stop playing
    endif
    
    move.b (sp)+,$484.w             ;restore keyclick state

    rts                             ;bye!

    if !debug
    if use_vbl=1
vbl:
    movem.l d0-a6,-(sp)

    if vbl_pause
    move.w #2047,d0                 ;small software pause so we can see the cpu time
.wait: dbra d0,.wait
    endif ; .if vbl_pause

    if DUMP_SONG
    if show_cpu
    not.w $ffff8240.w
    endif ; .if show_cpu
    move.l song_buffer_pos(pc),a0
    tst.w (a0)+
    bne.s play_dump_14_regs
    lea $ffff8800.w,a1
    movem.l (a0)+,d0-d7/a2-a6
    movem.l d0-d7/a2-a6,(a1)
    move.l a0,song_buffer_pos
    bra.s play_dump_out
play_dump_14_regs:
    movem.l (a0)+,d0-d7/a1-a6
    move.l a0,song_buffer_pos
    lea $ffff8800.w,a0
    movem.l d0-d7/a1-a6,(a0)
play_dump_out:
    if show_cpu
    not.w $ffff8240.w
    endif ; .if show_cpu
    addq.w #1,current_frame

    else

    lea tune,a0                     ;tell the player where to find the tune start
    if show_cpu
    not.w $ffff8240.w
    endif ; .if show_cpu

	parse_events

    bsr.s PLY_AKYst_Play            ;play that funky music
    if SID_VOICES
    lea values_store(pc),a0
    bsr sid_play
    endif ; .if SID_VOICES
    if show_cpu
    not.w $ffff8240.w
    endif ; .if show_cpu
    endif ; if DUMP_SONG
    movem.l (sp)+,d0-a6    
    if disable_timers!=1
old_vbl=*+2
    jmp 'GGN!'
    else ; .if disable_timers!=1
    rte
old_vbl: ds.l 1
save_mfp:   ds.l 16
    endif ; .if disable_timers!=1
    else ; .if use_vbl=1
timer_c:
	move.w #$2500,sr                ;mask out all interrupts apart from MFP
    sub.w #tune_freq,timer_c_ctr    ;is it giiiirooo day tom?
    bgt timer_c_jump                ;sadly derek, no it's not giro day
    add.w #200,timer_c_ctr          ;it is giro day, let's reset the 200Hz counter
    movem.l d0-a6,-(sp)             ;save all registers, just to be on the safe side
    if show_cpu
    not.w $ffff8240.w
    endif ; .if show_cpu
    lea tune,a0                     ;tell the player where to find the tune start

	parse_events

    bsr.s PLY_AKYst_Play            ;play that funky music
    if SID_VOICES
    lea values_store(pc),a0
    bsr sid_play
    endif ; .if SID_VOICES
    if show_cpu
    not.w $ffff8240.w
    endif ; .if show_cpu
    movem.l (sp)+,d0-a6             ;restore registers

old_timer_c=*+2
timer_c_jump:
    jmp 'XIA!'                      ;jump to the old timer C vector
timer_c_ctr: dc.w 200
    endif ; .if use_vbl=1
    endif ; .if !debug

    include "PlayerAky.s"

    if SID_VOICES
    include "sid.s"
    endif ; .if SID_VOICES

    data

    if DUMP_SONG
song_buffer_pos:
    dc.l dump_buffer
    endif

  if USE_EVENTS
events_pos: ds.l 1
event_counter: ds.w 1
event_byte: dc.b 0
event_flag: dc.b 0
  even
tune_events:
;    .include "tunes/SID_Test_001.events.words.s"
    include "tunes/knightmare.events.words.s"
;    include "test_new_sid_event_002.events.words.s"
;    .include "tunes/you_never_can_tell.events.words.s"

;    .include "tunes/ten_little_endians.events.words.s"
;    .include "tunes/just_add_cream.events.words.s"
;    .include "tunes/interleave_this.events.words.s"
  even
  endif ; .if USE_EVENTS

tune:
;   .include "tunes/UltraSyd - Fractal.s"
;    .include "tunes/UltraSyd - YM Type.s"
;    .include "tunes/Targhan - Midline Process - Carpet.s"
;    .include "tunes/Targhan - Midline Process - Molusk.s"
;    .include "tunes/Targhan - DemoIzArt - End Part.s"
;    .include "tunes/Pachelbel's Canon in D major 003.s"
;    .include "tunes/Interleave THIS! 015.s"
;    .include "tunes/Knightmare 200Hz 017.s"
;    .include "tunes/Ten Little Endians_015.s"
;    .include "tunes/Just add cream 020.s"

;    .include "tunes/SID_Test_001.aky.s"
    include "tunes/knightmare.aky.s"
;    include "test_new_sid_event_002.aky.s"
;    .include "tunes/you_never_can_tell.aky.s"

;    .include "tunes/ten_little_endians.aky.s"
;    .include "tunes/just_add_cream.aky.s"
;    .include "tunes/interleave_this.aky.s"

    if _RMAC_=1
    long                            ;pad to 4 bytes
    endif
    if _VASM_=1
    even
    endif
tune_end:

    bss

    if DUMP_SONG
; Each YM dump frame consists of:
; 1 word that specifies wheter we load the hardware envelope values (0=no)
; Either: 13 longwords containing YM registers 0-12
;         14 longwords containing YM registers 0-13 (with hardware envelope)
current_frame:
    ds.w 1
dump_dummy:
    ds.l 1
dump_buffer:
    ds.w DUMP_SONG_FRAMES_AMOUNT*(14*2+1)
    endif
