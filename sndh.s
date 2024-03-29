;
; SNDH header
; based on the official source from http://sndh.atari.org
;

.org 0

PC_REL_CODE=1                   ; DO NOT CHANGE if 1, make code PC relative (helps if you move the routine around, like for example SNDH)
AVOID_SMC=1                     ; DO NOT CHANGE if 1, assemble the player without SMC stuff, so it should be fine for CPUs with cache
;SID_VOICES=0                    ; if 1, enable SID voices (takes more CPU time!)
UNROLLED_CODE=1                 ; if 1, enable unrolled slightly faster YM register reading code
;USE_EVENTS=1                    ; if 1, include events, and parse them
;USE_SID_EVENTS=0                ; if 1, use events to control SID.
                                ;   $Fn=sid setting, where n bits are xABC for which voice to use SID
DUMP_SONG=0                     ; if 1, produce a YM dump of the tune. DOES NOT WORK WITH SID OR EVENTS YET!

EVENT_CHANNEL_A_MASK equ 8+4
EVENT_CHANNEL_B_MASK equ 8+2
EVENT_CHANNEL_C_MASK equ 8+1

;
; Macros that ensure PC relative code
;
    .macro clrx dst
    .if PC_REL_CODE
        clr\! \dst - PLY_AKYst_Init(a4)
    .else
        clr\! \dst
    .endif
    .endm
    .macro tstx dst
    .if PC_REL_CODE
        tst\! \dst - PLY_AKYst_Init(a4)
    .else
        tst\! \dst
    .endif
    .endm
    .macro movex src,dst
    .if PC_REL_CODE
        move\! \src,\dst - PLY_AKYst_Init(a4)
    .else
        move\! \src,\dst
    .endif
    .endm

;
; Event parser, in macro form (let's not waste a bsr and rts!)
;
	.macro parse_events
    ;########################################################
    ;## Parse tune events

    .if USE_EVENTS
    .if PC_REL_CODE
    movem.l d0/a0/a1/a4,-(sp)
    lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
    .else
    movem.l d0/a0/a1,-(sp)
    .endif
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
    movex.b #1,event_flag ; there's a new event value to fetch
    move.w (a0),d0
    bne.s .noloopback
    ; loopback
    addq #2,a0
    move.w (a0),a0
    lea tune_events(pc),a1
    add.l a1,a0
    movex.l a0,events_pos
    movex.w (a0),event_counter
    bra.s .event_do_count
.noloopback:
    movex.l a0,events_pos
.nohit:
    movex.w d0,event_counter
    ;done
    .if PC_REL_CODE
    movem.l (sp)+,d0/a0/a1/a4
    .else
    movem.l (sp)+,d0/a0/a1
    .endif
    .endif ; .if USE_EVENTS

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
	.endm

    bra.w  sndh_init
    bra.w  sndh_exit
    bra.w  sndh_vbl

    dc.b   'SNDH'
;    dc.b   'TITL','Love Potion Level 4 (Hello)',0
;    dc.b   'COMM','XiA',0
;    dc.b   'RIPP','Nobody',0
;    dc.b   'CONV','Arkos2-2-SNDH',0
;    dc.b   'VBL',0
    include "sndh_header.s"
    even
	
    dc.b  'YEAR','2018',0
    dc.b  'HDNS',0
    even

  .if USE_EVENTS
events_pos: ds.l 1
event_counter: ds.w 1
event_byte: dc.b 0
event_flag: dc.b 0
  .even
  .endif

sndh_init:
    movem.l d0-a6,-(sp)

    .if SID_VOICES & USE_SID_EVENTS
    lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
    clrx.b chan_a_sid_on
    clrx.b chan_b_sid_on
    clrx.b chan_c_sid_on
    .endif ; .if SID_VOICES

    .if PC_REL_CODE
    lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
    .endif
    
    .if USE_EVENTS
    ; reset event pos to start of event list
    lea tune_events(pc),a0
    movex.l a0,events_pos
    movex.w (a0),event_counter
    .endif ; .if USE_EVENTS

    move.b #7,$ffff8800.w                                   ;let's behave and save I/O port settings
    movex.b $ffff8800.w,old_io_port_value

    lea tune(pc),a0
    bsr.w PLY_AKYst_Init
    .if SID_VOICES
	bsr sid_ini
    .endif
    movem.l  (sp)+,d0-a6
    rts

old_io_port_value: ds.b 1
    even

sndh_exit:
    movem.l d0-a6,-(sp)
    .if SID_VOICES
	bsr sid_exit
    .endif
    moveq #14-1,d0
    moveq #0,d1
reset_psg: move.l d1,$ffff8800.w
    add.l #$01000000,d1
    dbra d0,reset_psg
    move.b #7,$ffff8800.w                                   ;let's behave and restore I/O port settings
    move.b old_io_port_value(pc),$ffff8802.w
    movem.l  (sp)+,d0-a6
    rts

sndh_vbl:
    movem.l d0-a6,-(sp)
    lea tune(pc),a0
    parse_events
    bsr.w  PLY_AKYst_Play
    .if SID_VOICES
    lea values_store(pc),a0
	bsr sid_play
    .endif
    movem.l  (sp)+,d0-a6
    rts

player:
    even
    include  'PlayerAky.s'
    even

    include "sndh_filenames.s"

	.if SID_VOICES
	include "sid.s"
	.endif

    .dc.b "ARKOS2-2-SNDH - The tune data ended at the start of this message"

;http://phf.atari.org

;(EOF)


; SNDH file structure, Revision 2.10

; Original SNDH Format devised by Jochen Knaus
; SNDH V1.1 Updated/Created by Anders Eriksson and Odd Skancke 
; SNDH V2.0 by Phil Graham
; SNDH V2.1 by Phil Graham

; This document was originally created by Anders Eriksson, updated and 
; adapted with SNDH v2 structures by Phil Graham.

; October, 2012
; 
;
; All values are in MOTOROLA BIG ENDIAN format


;---------------------------------------------------------------------------
;Offset         Size    Function                    Example
;---------------------------------------------------------------------------
;0              4       INIT music driver           bra.w  init_music_driver
;                       (subtune number in d0.w)
;4              4       EXIT music driver           bra.w  exit_music_driver
;8              4       music driver PLAY           bra.w  vbl_play
;12             4       SNDH head                   dc.b   'SNDH'



;---------------------------------------------------------------------------
;Beneath follows the different TAGS that can (should) be used.
;The order of the TAGS is not important.
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; TAG   Description      Example                           Termination
;---------------------------------------------------------------------------
; TITL  Title of Song    dc.b 'TITL','Led Storm',0         0 (Null)
; COMM  Composer Name    dc.b 'COMM','Tim Follin',0        0 (Null)
; RIPP  Ripper Name      dc.b 'RIPP','Me the hacker',0     0 (Null)
; CONV  Converter Name   dc.b 'CONV','Me the converter',0  0 (Null)
; ##??  Sub Tunes        dc.b '##04',0                     0 (Null)
; TA???  Timer A         dc.b 'TA50',0                     0 (Null)
; TB???  Timer B         dc.b 'TB60',0                     0 (Null)
; TC???  Timer C         dc.b 'TC50',0                     0 (Null)
; TD???  Timer D         dc.b 'TD100',0                    0 (Null)
; !V??  VBL              dc.b '!V50',0                     0 (Null)
; YEAR  Year of release  dc.b '1996',0                     0 (Null) SNHDv2
; #!??  Default Sub tune dc.b '#!02',0                     0 (Null) SNDHv21
; #!SN  Sub tune names	 dc.w x1,x2,x3,x4                  None
;                        dc.b "Subtune Name 1",0	   0 (Null) SNDHv21
;                        dc.b "Subtune Name 2",0	   0 (Null) SNDHv21
;                        dc.b "Subtune Name 3",0	   0 (Null) SNDHv21
;                        dc.b "Subtune Name 4",0	   0 (Null) SNDHv21
; TIME  (sub) tune time  dc.b 'TIME'                       None     SNDHv2
;       (in seconds)     dc.w x1,x2,x3,x4      
; HDNS  End of Header    dc.b 'HDNS'                       None     SNDHv2

;---------------------------------------------------------------------------
;Calling method and speed
;---------------------------------------------------------------------------
;This a very important part to do correctly.
;Here you specify what hardware interrupt to use for calling the music 
;driver.
;
;These options are available;
;dc.b  '!Vnn'       VBL (nn=frequency)
;dc.b  'TAnnn',0    Timer A (nnn=frequency)
;dc.b  'TBnnn',0    Timer B (nnn=frequency)
;dc.b  'TCnnn',0    Timer C (nnn=frequency)
;dc.b  'TDnnn',0    Timer D (nnn=frequency)
;
;VBL           - Is NOT recommended for use. There is no change made to the 
;                VBL frequency so it will play at the current VBL speed.
;
;Timer A       - Is only recommended if Timer C is not accurate enough. Use 
;                with caution, many songs are using Timer A for special
;                effects.
;
;Timer B       - Is only recommended if Timer C is not accurate enough. Use
;                with caution, many songs are using Timer B for special
;                effects.
;
;Timer C       - The default timer if nothing is specified. Default speed
;                is 50Hz. Use Timer C playback wherever possible. It hooks
;                up to the OS 200Hz Timer C interrupt and leaves all other
;                interrupts free for special effects.
;
;                For songs with a replay speed uneven of 200Hz, SND Player
;                uses a smart routine to correct for the wrong speed. The
;                result is usually very good. If the result isn't good 
;                enough,then consider another Timer, but be careful with
;                Timer collisions!
;
;Timer D       - Is only recommended if Timer C is not accurate enough. 
;                Use with caution, many songs are using Timer D for 
;                special effects.

;---------------------------------------------------------------------------
; Default Tune Tag (!#??)
;---------------------------------------------------------------------------
; The !# Tag is followed by a two character ascii value signifying the
; default sub-tune to be played. If this tag is null then a sub-tune of
; 1 is assumed. 
;---------------------------------------------------------------------------

;---------------------------------------------------------------------------
; Sub Tune Names (!#SN)
;---------------------------------------------------------------------------
; The !#SN Tag is followed by a table of word offsets pointing to the ascii
; text of sub tune names. The base offset is the actaul !#SN tag. See 
; example header below. 
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
; TIME Tag
;---------------------------------------------------------------------------
; The TIME tag is followed by 'x' short words ('x' being the number of 
; tunes). Each word contains the length of each sub tune in seconds. If the
; word is null then it is assumed that the tune endlessly loops.
;---------------------------------------------------------------------------


;---------------------------------------------------------------------------
; HDNS Tag
;---------------------------------------------------------------------------
; The HDNS signifies the end of the SNDH header and the start of the actual 
; music data. This tag must be on an even boundary.
;---------------------------------------------------------------------------


