; Z80 with SID

; Usage -	+0 Init passing music driver address A0
;	+4 Quit
;	+8 Call per frame passing A0 (YM table)

;	opt	x+,p+

    pea start
    move.w #$26,-(sp)
    trap #14
    addq.l #6,sp

    clr.w -(sp)
    trap #1

start:
    bsr sndh_init
    lea sndh_vbl,a0
    bsr as+0

    move.l #ourvbl,$70.w

.wait:  cmp.b #57,$fffffc02.w
    bne.s .wait

    bsr as+4
    bsr sndh_exit
    rts

ourvbl:
    movem.l d0-a6,-(sp)
    bsr sndh_vbl
    lea values_store,a0
;    move.l a0,a1
;    move.b #0,$ffff8800.w   ;freq low A
;    move.l $ffff8800.w,(a1)+
;    move.b #1,$ffff8800.w   ;freq hi A
;    move.l $ffff8800.w,(a1)+
;    move.b #2,$ffff8800.w   ;freq low B
;    move.l $ffff8800.w,(a1)+
;    move.b #3,$ffff8800.w   ;freq hi B
;    move.l $ffff8800.w,(a1)+
;    move.b #4,$ffff8800.w   ;freq low C
;    move.l $ffff8800.w,(a1)+
;    move.b #5,$ffff8800.w   ;freq hi C
;    move.l $ffff8800.w,(a1)+
;    move.b #6,$ffff8800.w   ;noise freq
;    move.l $ffff8800.w,(a1)+
;    move.b #7,$ffff8800.w   ;mixer control
;    move.l $ffff8800.w,(a1)+
;    move.b #8,$ffff8800.w   ;amplitude A
;    move.l $ffff8800.w,(a1)+
;    move.b #9,$ffff8800.w   ;amplitude B
;    move.l $ffff8800.w,(a1)+
;    move.b #10,$ffff8800.w   ;amplitude C
;    move.l $ffff8800.w,(a1)+
;    move.b #11,$ffff8800.w   ;envelope hi
;    move.l $ffff8800.w,(a1)+
;    move.b #12,$ffff8800.w   ;envelope low
;    move.l $ffff8800.w,(a1)+
;    move.b #13,$ffff8800.w   ;envelope shape 
;    move.l $ffff8800.w,(a1)+
    bsr as+8
    movem.l (sp)+,d0-a6
    rte


values_store:   ds.l 16

as:
	bra	ini	; the three branches at the top of file.
	bra	exit
	bra	play

	dc.b	'Grazey 3 Sid Voice Player'
	dc.b	"SID voices install on TA,TB,TD"
	dc.b	0
	even
flag:	dc.w	0

ini:
	bsr	INITC
	rts
    bsr sndh_vbl

exit:	bsr	CBACK
	;include	h:\sndh\clrym.s
        rts

play:	

	bsr	SIDEMU

pat1:		;lea	0,a0
	clr.l	d0
	clr.l	d1
	move.b	((4*8)+0)(a0),d0
	move.b	((4*1)+0)(a0),d1
	lsl	#8,d1
	add.b	((4*0)+0)(a0),d1
	bsr	CALC_A

	clr.l	d0
	clr.l	d1
	move.b	((4*9)+0)(a0),d0
	move.b	((4*3)+0)(a0),d1
	lsl	#8,d1
	add.b	((4*2)+0)(a0),d1
	bsr	CALC_B

	clr.l	d0
	clr.l	d1
	move.b	((4*10)+0)(a0),d0
	move.b	((4*5)+0)(a0),d1
	lsl	#8,d1
	add.b	((4*4)+0)(a0),d1
	bsr	CALC_D
	RTS


	
*	SID-Voice extension by Cream	*
*-----------------------------------------------------------*
BASE:
SIDEMU:	

; Spacing	YM +2
; eg 	Reg 0 +0
;	Reg 1 +2

spc	equ	2

	MOVE	SR,-(SP)
	MOVE	#$2700,SR

	LEA	$FFFF8800.w,A1
;pat2	lea	0,a0
	MOVE.B	#$00,(A1)
	MOVE.B	((4*0)+0)(A0),2(A1)

	MOVE.B	#$01,(A1)
	MOVE.B	((4*1)+0)(A0),2(A1)

	MOVE.B	#$02,(A1)
	MOVE.B	((4*2)+0)(A0),2(A1)

	MOVE.B	#$03,(A1)
	MOVE.B	((4*3)+0)(A0),2(A1)

	MOVE.B	#$04,(A1)
	MOVE.B	((4*4)+0)(A0),2(A1)

	MOVE.B	#$05,(A1)
	MOVE.B	((4*5)+0)(A0),2(A1)

	MOVE.B	#$06,(A1)
	MOVE.B	((4*6)+0)(A0),2(A1)

	MOVE.B	#$07,(A1)
	MOVE.B	((4*7)+0)(A0),D0
	OR.B	#$C0,D0
	MOVE.B	D0,2(A1)


	MOVE.B	((4*8)+0)(A0),D1
	MOVE.B	((4*9)+0)(A0),D2
	MOVE.B	((4*10)+0)(A0),D3

NORAU0:	BTST	#3,D0
	BNE.S	NORAU1
	MOVE.B	#$08,(A1)
	SUB.B	#1,D1
	BPL.S	OK1
	MOVEQ	#0,D1
OK1:	MOVE.B	D1,2(A1)
	BSR	NO_TA

NORAU1:	BTST	#4,D0
	BNE.S	NORAU2
	MOVE.B	#$09,(A1)
	SUB.B	#1,D2
	BPL.S	OK2
	MOVEQ	#0,D2
OK2:	MOVE.B	D2,2(A1)
	BSR	NO_TB

NORAU2:	BTST	#5,D0
	BNE.S	NORAU3
	MOVE.B	#$0A,(A1)
	SUB.B	#1,D3
	BPL.S	OK3
	MOVEQ	#0,D3
OK3:	MOVE.B	D3,2(A1)
	BSR	NO_TD
NORAU3:

	MOVE	(SP)+,SR
	RTS
	
INITC:
				; Init timers for	SID-Voice
	MOVE	SR,-(SP)
	MOVEM.L A0/A4,-(SP)
	LEA	BASE(PC),A4

	TST.W	CFLAG-BASE(A4)
	BNE	NONEWC
	MOVE.W	#$0001,CFLAG-BASE(A4)

	MOVE	#$2700,SR

	LEA	RETTE(PC),A0
	MOVE.L	$00000134.w,(A0)+
	MOVE.L	$00000120.w,(A0)+
	MOVE.L	$00000110.w,(A0)+
	MOVE.B	$FFFFFA07.w,(A0)+
	MOVE.B	$FFFFFA09.w,(A0)+
	MOVE.B	$FFFFFA13.w,(A0)+
	MOVE.B	$FFFFFA15.w,(A0)+
	MOVE.B	$FFFFFA17.w,(A0)+
	MOVE.B	$FFFFFA19.w,(A0)+ ;TA control
	MOVE.B	$FFFFFA1B.w,(A0)+ ;TB control
	MOVE.B	$FFFFFA1D.w,(A0)+ ;TD control

	BCLR	#1,$FFFFFA07.w

	ANDI.B	#$F0,$FFFFFA19.w ;stop a
	CLR.B	$FFFFFA1B.w	;stop b
	ANDI.B	#$F0,$FFFFFA1D.w ;stop d
	MOVE.B	$FFFFFA1F.w,(A0)+ ;TA Data
	MOVE.B	$FFFFFA21.w,(A0)+ ;TB Data
	MOVE.B	$FFFFFA25.w,(A0)+ ;TD Data

	lea	TIMER_A1(pc),a0
	lea	TIMER_B1(pc),a1
	lea	TIMER_D1(pc),a2
	MOVE.L	a0,$00000134.w
	MOVE.L	a1,$00000120.w
	MOVE.L	a2,$00000110.w

	MOVE.B	#$08,$FFFFFA19.w
	MOVE.B	#$08,$FFFFFA21.w
	MOVE.B	#$08,$FFFFFA25.w

	BSET	#5,$FFFFFA07.w	;	Enable Timer A
	BSET	#5,$FFFFFA13.w
	BSET	#0,$FFFFFA07.w	;	Enable Timer B
	BSET	#0,$FFFFFA13.w
	BSET	#4,$FFFFFA09.w	;	Enable Timer D
	BSET	#4,$FFFFFA15.w
	BCLR	#$03,$FFFFFA17.w ; Automatic EOI

NONEWC:	MOVEM.L (SP)+,A0/A4
	MOVE	(SP)+,SR
	RTS


CBACK:	MOVE	SR,-(SP)
	MOVEM.L D0/A0/A4,-(SP)
	LEA	BASE(PC),A4

	TST.W	CFLAG-BASE(A4)
	BEQ.S	NOCBACK
	CLR.W	CFLAG-BASE(A4)

	MOVE	#$2700,SR
	LEA	RETTE(PC),A0
	MOVE.L	(A0)+,$00000134.w
	MOVE.L	(A0)+,$00000120.w
	MOVE.L	(A0)+,$00000110.w
	MOVE.B	(A0)+,$FFFFFA07.w
	MOVE.B	(A0)+,$FFFFFA09.w
	MOVE.B	(A0)+,$FFFFFA13.w
	MOVE.B	(A0)+,$FFFFFA15.w
	MOVE.B	(A0)+,$FFFFFA17.w
	MOVE.B	(A0)+,$FFFFFA19.w
	MOVE.B	(A0)+,$FFFFFA1B.w
	MOVE.B	(A0)+,D0
	AND.B	#$0F,D0
	ANDI.B	#$F0,$FFFFFA1D.w
	OR.B	D0,$FFFFFA1D.w
	MOVE.B	(A0)+,$FFFFFA1F.w
	MOVE.B	(A0)+,$FFFFFA21.w
	MOVE.B	(A0)+,$FFFFFA25.w

NOCBACK:	
	MOVEM.L (SP)+,D0/A0/A4
	MOVE	(SP)+,SR
	RTS

CFLAG:	DC.W 0
RETTE:	DS.L 10
DUMMYC:	DC.W 0
	
CALC_A:					; Timer routs
	AND.L	#$00000FFF,D1
	CMP.W	#$0010,D1
	BLE.S	NO_TA

	lea	TIMER_A1+4(pc),a4
	MOVE.B	D0,(a4)	

	LEA	TIMER_TAB(PC),A2
	CLR.L	D2
AGAIN_TIMER:	CMP.W	(A2),D1
	BLT.S	USE_TIMER
	LEA	6(A2),A2
	BRA.S	AGAIN_TIMER

USE_TIMER:
	MOVE.W	2(A2),D2	;MFP - Vorteiler
	MOVE.L	#160822,D0
	DIVU	D2,D0	;/ Vorteiler
	MULU	D1,D0	;* Periode
	ADD.L	#$00002000,D0	;Finetuning
	LSL.L	#2,D0
	SWAP	D0	;/131072 (PSG Takt -> swap)

	MOVE.W	4(A2),D1
	MOVE.B	D0,$FFFFFA1F.w	;
	MOVE.B	D1,$FFFFFA19.w	;
	RTS

NO_TA:	ANDI.B	#$F0,$FFFFFA19.w
	RTS


TIMER_TAB:
	DC.W $0068,$0004,$0001	;
	DC.W $0105,$000A,$0002	;
	DC.W $01A2,$0010,$0003	;
	DC.W $051A,$0032,$0004	;
	DC.W $0688,$0040,$0005	;
	DC.W $0A35,$0064,$0006	;
	DC.W $0EEF,$00C8,$0007	;
	DC.W $0FFF,$00C8,$0007	;
	DC.W $FFFF

TIMER_A1:
	MOVE.L	#$08000000,$FFFF8800.w
	add.l	#$12,$134.w
	RTE
TIMER_A2:
	MOVE.L	#$08000000,$FFFF8800.w
	sub.l	#$12,$134.w
	RTE

	
CALC_B:	
MAKE_TIMER_B:

	AND.L	#$00000FFF,D1
	CMP.W	#$0010,D1
	BLE.S	NO_TB

	lea	TIMER_B1+4(pc),a4
	move.b	d0,(a4)

	LEA	TIMER_TAB(PC),A2
	CLR.L	D2
AGAIN_TB:
	CMP.W	(A2),D1
	BLT.S	USE_TBX
	LEA	6(A2),A2
	BRA.S	AGAIN_TB

USE_TBX:
	MOVE.W	2(A2),D2	;MFP - Vorteiler
	MOVE.L	#160822,D0
	DIVU	D2,D0	;/ Vorteiler
	MULU	D1,D0	;* Periode
	ADD.L	#$00002000,D0	;Finetuning
	LSL.L	#2,D0
	SWAP	D0	;/131072 (PSG Takt -> swap)

	MOVE.W	4(A2),D1
	MOVE.B	$FFFFFA1B.w,D2
	ANDI.B	#$F0,D2
	OR.B	D1,D2
	MOVE.B	D0,$FFFFFA21.w	;38
	MOVE.B	D2,$FFFFFA1B.w	;1
	RTS

NO_TB:	ANDI.B	#$F0,$FFFFFA1B.w
	RTS

TIMER_B1:
	MOVE.L	#$09000000,$FFFF8800.w
	add.l	#$12,$120.w
	RTE
TIMER_B2:
	MOVE.L	#$09000000,$FFFF8800.w
	sub.l	#$12,$120.w
	RTE

CALC_D:	
MAKE_TIMER_D:
	AND.L	#$00000FFF,D1
	CMP.W	#$0010,D1
	BLE.S	NO_TD

	lea	TIMER_D1+4(pc),a4
	move.b	d0,(a4)

	LEA	TIMER_TAB(PC),A2
	CLR.L	D2
AGAIN_TD:
	CMP.W	(A2),D1
	BLT.S	USE_TDX
	LEA	6(A2),A2
	BRA.S	AGAIN_TD

USE_TDX:
	MOVE.W	2(A2),D2	;MFP - Vorteiler
	MOVE.L	#160822,D0
	DIVU	D2,D0	;/ Vorteiler
	MULU	D1,D0	;* Periode
	ADD.L	#$00002000,D0	;Finetuning
	LSL.L	#2,D0
	SWAP	D0	;/131072 (PSG Takt -> swap)

	MOVE.W	4(A2),D1
	MOVE.B	D0,$FFFFFA25.w	;
	ANDI.B	#$F0,$FFFFFA1D.w
	OR.B	D1,$FFFFFA1D.w
	RTS

NO_TD:	ANDI.B	#$F0,$FFFFFA1D.w
	RTS

TIMER_D1:
	MOVE.L	#$0A000000,$FFFF8800.w
	add.l	#$12,$110.w
	RTE
TIMER_D2:
	MOVE.L	#$0A000000,$FFFF8800.w
	sub.l	#$12,$110.w
	RTE

blah:	ds.l	16
ym:	ds.l	11


endmus:
zx:

    include "sndh.s"
