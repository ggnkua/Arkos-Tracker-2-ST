sample_tester=1

    .if sample_tester
    ; just enough code to test the sample player stand alone,
    ; do not expect a masterclass in clean code!

    ; init
    move.l #sample_player_raw_linear_data,sample_player_current_event
    clr.w sample_player_wait_frames

    ; who's super? You're super!
    clr.l   -(SP)
    move.w  #$20,-(SP)
    trap    #1
    addq.l  #6,SP
    ;move.l d0,old_sp

    move sr,-(sp)
    move #$2700,sr
    ; Init MFP


    ;move.l  $0134.w,old_timera                         ; Save old routine
    move.l  #sample_player_interrupt_routine,$0134.w    ; Insert new routine
    ;move.b  $FFFFFA07.w,old_iera                       ; Save old enable register
    ;move.b  $FFFFFA13.w,old_imra                       ; Save old mask register

    move.b  #18,$FFFFFA1F.w                                 ; timer data
    move.b  #6,$FFFFFA19.w                                  ; tacr, 6=timer/100, 7=timer/200

    bclr #5,$FFFFFA0B.w                                     ; Clear timer A pending bit

    bclr #5,$fffffa07.w                                 ; stop timer a just in case
    ;bset    #5,$FFFA07                                 ; Start timer interrupt
    bset    #5,$FFFFFA13.w                                  ; unmask

    move.l vbl,$70.w    ; set our vbl
    move (sp)+,sr

    bclr #0,$484.w      ; kill keyclick

wait_loop:
    cmp.b #57,$fffffc02.w
    bne.s wait_loop

    illegal

vbl:
    movem.l d0-a6,-(sp)
    move.l sample_player_current_event,a0
    bsr sample_player_tick_routine
    move.l a0,sample_player_current_event
    movem.l (sp)+,d0-a6
    rte
    .endif

; a0 points to current "raw linear" event
;
; Some command numbers that are noteworthy:
; 0=do something in channel A - 7 bytes block
; 1=do something in channel B - 7 bytes block
; 2=do something in channel C - 7 bytes block
; 254=wait (next .w has the amount of frames to wait) - 3 bytes block
; 253=end of song, loop (next.w has the offset from the start to jump to) - 3 bytes block
; 255=wait 1 frame

; All effect bytes are currently ignored

; If instrument=255 then do nothing

; If instrument=0 then stop playing sample (if applicable)

sample_player_tick_routine:
; Firstly, check if a pause is imposed on us, if true then
; decrease wait counter and get out
    tst.w sample_player_wait_frames
    beq.s sample_player_get_event
    subq.w #1,sample_player_wait_frames
    rts

; Let's grab an event!
sample_player_get_event:
    move.b (a0)+,d0
    
; Ooh, what did we get, what did we get?
    cmp.b #2,d0
    blo.s sample_player_play_sample
    cmp.b #254,d0
    beq.s sample_player_wait_n_frames
    cmp.b #255,d0
    beq.s sample_player_wait_1_frame
    cmp.b #253,d0
    bne.s sample_player_exit    ; currently unsupported command, go away

; End of song marker, just loop back to where we're told
    move.w (a0),a0
    add.l #arkos_samplesloop,a0
    bra.s sample_player_get_event

sample_player_wait_1_frame:
    move.w #1,sample_player_wait_frames
sample_player_exit:
    rts

sample_player_wait_n_frames:
    move.w (a0)+,sample_player_wait_frames
    rts

; At last, time for this source file to earn its living!
sample_player_play_sample:
    moveq #0,d0
    move.b (a0)+,d0             ; get note
    cmp.b #255,d0               
    bne.s sample_player_actually_play_sample
    addq.l #5,a0                ; broooooo, we got duped! ignore command and continue
    bra.s sample_player_get_event
sample_player_actually_play_sample: ; this is it, we're doing it now for reals!
    moveq #0,d1
    move.b (a0)+,d1             ; get instrument
    cmp.b #255,d1
    bne.s sample_player_play_sample_for_sure
    addq.l #4,a0                ; oh nooo brooooooo, we got duped again! skip command again
    bra.s sample_player_get_event
sample_player_play_sample_for_sure:
    addq.l #4,a0                ; skip effect values as they're ignored by the z80 player too
    lea SampleTableIndex,a1     ; everything's relative to this address
    add.w d1,d1
    move.l a1,a2
    add.w (a2,d1.w),a2          ; point to sample's info
    movem.w (a2)+,d1-d3         ; sample start offset, end offset, loop offset
    ; NOTE: ugh, if there's more than 32k of samples, the movem.w will sign extend to negative offsets
    add.l a1,d1
    add.l a1,d2
    add.l a1,d3
    movem.l d1-d3,sample_player_info
    ; TODO some magic LUT here to convert note value to timer frequency
    ; TODO also, start timer

sample_player_interrupt_routine:


    rte

sample_player_current_event:    .dc.l 1    
sample_player_wait_frames:      .dc.w 0
sample_player_info:             .ds.l 3     ; start address, end address, loop address

sample_player_raw_linear_data:
    .include "m.raw.linear.s"
    .even
    .include "m.samples.s"
