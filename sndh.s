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


;---------------------------------------------------------------------------
;Example of a complete SNDH header/file
;---------------------------------------------------------------------------
;
;      section text
;
      bra.w  sndh_init
      bra.w  sndh_exit
      bra.w  sndh_vbl

      dc.b   'SNDH'
      dc.b   'TITL','Remote entry #2',0
      dc.b   'COMM','Who knows',0
      dc.b   'RIPP','GGN',0
      dc.b   'CONV','Arkos2-2-SNDH',0
;      dc.b   '##01',0
      dc.b   'TC050',0
;      dc.b   '!#01',0
      even
;.subt dc.b   '!#SN'             ; Subtune names
;      dc.w   .t1-.subt          ; Offset from .subt
;      dc.w   .t2-.subt
;      dc.w   .t3-.subt
;      dc.w   .t4-.subt
;      dc.w   .t5-.subt
;      dc.w   .t6-.subt

;.t1   dc.b   'What a Bummer',0
;.t2   dc.b   'Paninaro',0
;.t3   dc.b   'Fade to a Pinkish Red',0
;.t4   dc.b   'Revenge of the Mutant Wafer Biscuits',0
;.t5   dc.b   'Mind Bomb (Theme)',0
;.t6   dc.b   'In The Night',0
	
      even
  dc.b  'YEAR','2018',0
  dc.b  'TIME'
  dc.w  $e1,$60,$78,$11c,$40,$5f
  even
  dc.b  'HDNS',0
  even


sndh_init:
  movem.l d0-a6,-(sp)

align_song:
	lea tune(pc),a0                 ;move tune to a 64k aligned buffer
	lea align_song(pc),a1
	add.l #tune_buf-align_song,a1
	move.l a1,d0                    ;not the most memory efficient thing ever but eh :)
	clr.w d0                        ;align buffer
	move.l d0,a1
	move.l d0,d1
	lea tune_aligned_address(pc),a2
	move.l d0,(a2)                  ;sooper high powered copy!
	move.l #(tune_end+3-tune)/4-1,d0
.copy_tune:
	move.l (a0)+,(a1)+
	dbra d0,.copy_tune 
  
  move.l d1,a0
  bsr.w PLY_AKYst_Init
  movem.l  (sp)+,d0-a6
  rts

sndh_exit:
  movem.l d0-a6,-(sp)
    move.l  #$00000000,$FFFF8800
    move.l  #$01010000,$FFFF8800
    move.l  #$02020000,$FFFF8800
    move.l  #$03030000,$FFFF8800
    move.l  #$04040000,$FFFF8800
    move.l  #$05050000,$FFFF8800
    move.l  #$06060000,$FFFF8800
    move.l  #$07070000,$FFFF8800
    move.l  #$08080000,$FFFF8800
    move.l  #$090A0000,$FFFF8800
    move.l  #$0A0A0000,$FFFF8800
    move.l  #$0B0B0000,$FFFF8800
    move.l  #$0C0C0000,$FFFF8800
  movem.l  (sp)+,d0-a6
  rts

sndh_vbl:
  movem.l d0-a6,-(sp)
  move.l tune_aligned_address(pc),a0
  bsr.w  PLY_AKYst_Play
  movem.l  (sp)+,d0-a6
  rts
tune_aligned_address:    .ds.l 1

player:
  even
  include  'p_sndh.s'
  even

tune:
	.include "tune_filename.s"
tune_end:

	ds.b 65536
tune_buf:ds.b 65535


;http://phf.atari.org

;(EOF)