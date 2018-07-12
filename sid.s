
; Usage -    +0 Init passing music driver address A0
;    +4 Quit
;    +8 Call per frame passing A0 (YM table)

values_store:
i set 0
    rept 16
    dc.l i
i set i+$01000000
    endr

chan_a_sid_on:  ds.b 1
chan_b_sid_on:  ds.b 1
chan_c_sid_on:  ds.b 1
  even

sid_emu:
    dc.b    'Grazey 3 Sid Voice Player.'
    dc.b    'SID voices install on TA,TB,TD.'
    dc.b    'Extensions by GGN and XiA"
    dc.b    0
    even
flag:    dc.w    0

sid_ini:
    bsr    INITC
    rts

sid_exit:    bsr    CBACK
    rts


sid_play:    

    bsr.s    SIDEMU

    if USE_SID_EVENTS
    tstx.b chan_a_sid_on
    beq.s .skip_a
    endif

;pat1:
    clr.l    d0
    clr.l    d1
    move.b    ((4*8)+2)(a0),d0
    move.b    ((4*1)+2)(a0),d1
    lsl    #8,d1
    add.b    ((4*0)+2)(a0),d1
    bsr    CALC_A
    
    if USE_SID_EVENTS
.skip_a:
    tstx.b chan_b_sid_on
    beq.s .skip_b
    endif

    clr.l    d0
    clr.l    d1
    move.b    ((4*9)+2)(a0),d0
    move.b    ((4*3)+2)(a0),d1
    lsl    #8,d1
    add.b    ((4*2)+2)(a0),d1
    bsr    CALC_B

    if USE_SID_EVENTS
.skip_b:
    tstx.b chan_c_sid_on
    beq.s .skip_c
    endif

    clr.l    d0
    clr.l    d1
    move.b    ((4*10)+2)(a0),d0
    move.b    ((4*5)+2)(a0),d1
    lsl    #8,d1
    add.b    ((4*4)+2)(a0),d1
    bsr    CALC_D

    if USE_SID_EVENTS
.skip_c:
    endif

    RTS


    
*    SID-Voice extension by Cream    *
*-----------------------------------------------------------*
BASE:
SIDEMU:    

; Spacing    YM +2
; eg     Reg 0 +0
;    Reg 1 +2

spc    equ    2

    MOVE    SR,-(SP)
    MOVE    #$2700,SR

    LEA    $FFFF8800.w,A1
    movem.l (a0),d0-d7
    or.w #$c000,d7
    movem.l d0-d7,(a1)


    MOVE.B    ((4*8)+2)(A0),D1
    MOVE.B    ((4*9)+2)(A0),D2
    MOVE.B    ((4*10)+2)(A0),D3

    if USE_SID_EVENTS
    move.b #8,(a1)
    tstx.b chan_a_sid_on
    bgt.s OK1          ;turn sid channel off
    blt.s .NORAU0      ;turn sid channel on
    move.b d1,2(a1)    ;just write value to the PSG and don't touch timer
    bra.s channel_b
.chan_a_sid:
    endif

.NORAU0:
    BTST    #3+8,D7
    BNE.S    .NORAU1
    MOVE.B    #$08,(A1)
    SUB.B    #1,D1
    BPL.S    .OK1
    MOVEQ    #0,D1
.OK1:
    MOVE.B    D1,2(A1)
    BSR    NO_TA

channel_b:
    if USE_SID_EVENTS
    move.b #9,(a1)
    tstx.b chan_b_sid_on
    bgt.s OK2          ;turn sid channel off
    blt.s .NORAU1      ;turn sid channel on
    move.b d1,2(a1)    ;just write value to the PSG and don't touch timer
    bra.s channel_c
.chan_b_sid:
    endif

.NORAU1:
    BTST    #4+8,D7
    BNE.S    .NORAU2
    MOVE.B    #$09,(A1)
    SUB.B    #1,D2
    BPL.S    .OK2
    MOVEQ    #0,D2
.OK2:
    MOVE.B    D2,2(A1)
    BSR    NO_TB

channel_c:
    if USE_SID_EVENTS
    move.b #10,(a1)
    tstx.b chan_c_sid_on
    bgt.s OK3          ;turn sid channel off
    blt.s .NORAU2      ;turn sid channel on
    move.b d1,2(a1)    ;just write value to the PSG and don't touch timer
    bra.s .NORAU3
.chan_c_sid:
    endif

.NORAU2:
    BTST    #5+8,D7
    BNE.S    .NORAU3
    MOVE.B    #$0A,(A1)
    SUB.B    #1,D3
    BPL.S    .OK3
    MOVEQ    #0,D3
.OK3:
    MOVE.B    D3,2(A1)
    BSR    NO_TD
.NORAU3:

    MOVE    (SP)+,SR
    RTS
    
INITC:
                ; Init timers for    SID-Voice
    MOVE    SR,-(SP)
    MOVEM.L A0/A4,-(SP)
    LEA    BASE(PC),A4

    TST.W    CFLAG-BASE(A4)
    BNE    NONEWC
    MOVE.W    #$0001,CFLAG-BASE(A4)

    MOVE    #$2700,SR

    LEA    RETTE(PC),A0
    MOVE.L    $00000134.w,(A0)+
    MOVE.L    $00000120.w,(A0)+
    MOVE.L    $00000110.w,(A0)+
    move.B    $FFFFFA07.w,(A0)+
    move.B    $FFFFFA09.w,(A0)+
    move.B    $FFFFFA13.w,(A0)+
    move.B    $FFFFFA15.w,(A0)+
    move.B    $FFFFFA17.w,(A0)+
    move.B    $FFFFFA19.w,(A0)+ ;TA control
    move.B    $FFFFFA1B.w,(A0)+ ;TB control
    move.B    $FFFFFA1D.w,(A0)+ ;TD control

    BCLR    #1,$FFFFFA07.w

    ANDI.B    #$F0,$FFFFFA19.w ;stop a
    CLR.B    $FFFFFA1B.w    ;stop b
    ANDI.B    #$F0,$FFFFFA1D.w ;stop d
    move.B    $FFFFFA1F.w,(A0)+ ;TA Data
    move.B    $FFFFFA21.w,(A0)+ ;TB Data
    move.B    $FFFFFA25.w,(A0)+ ;TD Data

    lea    TIMER_A1(pc),a0
    lea    TIMER_B1(pc),a1
    lea    TIMER_D1(pc),a2
    MOVE.L    a0,$00000134.w
    MOVE.L    a1,$00000120.w
    MOVE.L    a2,$00000110.w

    move.B    #$08,$FFFFFA19.w
    move.B    #$08,$FFFFFA21.w
    move.B    #$08,$FFFFFA25.w

    BSET    #5,$FFFFFA07.w    ;    Enable Timer A
    BSET    #5,$FFFFFA13.w
    BSET    #0,$FFFFFA07.w    ;    Enable Timer B
    BSET    #0,$FFFFFA13.w
    BSET    #4,$FFFFFA09.w    ;    Enable Timer D
    BSET    #4,$FFFFFA15.w
    BCLR    #$03,$FFFFFA17.w ; Automatic EOI

NONEWC:    MOVEM.L (SP)+,A0/A4
    MOVE    (SP)+,SR
    RTS


CBACK:    MOVE    SR,-(SP)
    MOVEM.L D0/A0/A4,-(SP)
    LEA    BASE(PC),A4

    TST.W    CFLAG-BASE(A4)
    BEQ.S    NOCBACK
    CLR.W    CFLAG-BASE(A4)

    MOVE    #$2700,SR
    LEA    RETTE(PC),A0
    MOVE.L    (A0)+,$00000134.w
    MOVE.L    (A0)+,$00000120.w
    MOVE.L    (A0)+,$00000110.w
    move.B    (A0)+,$FFFFFA07.w
    move.B    (A0)+,$FFFFFA09.w
    move.B    (A0)+,$FFFFFA13.w
    move.B    (A0)+,$FFFFFA15.w
    move.B    (A0)+,$FFFFFA17.w
    move.B    (A0)+,$FFFFFA19.w
    move.B    (A0)+,$FFFFFA1B.w
    move.B    (A0)+,D0
    AND.B    #$0F,D0
    ANDI.B    #$F0,$FFFFFA1D.w
    OR.B    D0,$FFFFFA1D.w
    MOVE.B    (A0)+,$FFFFFA1F.w
    MOVE.B    (A0)+,$FFFFFA21.w
    MOVE.B    (A0)+,$FFFFFA25.w

NOCBACK:    
    MOVEM.L (SP)+,D0/A0/A4
    MOVE    (SP)+,SR
    RTS

CFLAG:    DC.W 0
RETTE:    DS.L 10
DUMMYC:    DC.W 0
    
CALC_A:                    ; Timer routs
    AND.L    #$00000FFF,D1
    CMP.W    #$0010,D1
    BLE.S    NO_TA

    lea    TIMER_A1+4(pc),a4
    MOVE.B    D0,(a4)    

    LEA    TIMER_TAB(PC),A2
    CLR.L    D2
AGAIN_TIMER:    CMP.W    (A2),D1
    BLT.S    USE_TIMER
    LEA    6(A2),A2
    BRA.S    AGAIN_TIMER

USE_TIMER:
    MOVE.W    2(A2),D2    ;MFP - Vorteiler
    MOVE.L    #160822,D0
    DIVU    D2,D0    ;/ Vorteiler
    MULU    D1,D0    ;* Periode
    ADD.L    #$00002000,D0    ;Finetuning
    LSL.L    #2,D0
    SWAP    D0    ;/131072 (PSG Takt -> swap)

    MOVE.W    4(A2),D1
    move.B    D0,$FFFFFA1F.w    ;
    move.B    D1,$FFFFFA19.w    ;
    RTS

NO_TA:    ANDI.B    #$F0,$FFFFFA19.w
    RTS


TIMER_TAB:
    DC.W $0068,$0004,$0001    ;
    DC.W $0105,$000A,$0002    ;
    DC.W $01A2,$0010,$0003    ;
    DC.W $051A,$0032,$0004    ;
    DC.W $0688,$0040,$0005    ;
    DC.W $0A35,$0064,$0006    ;
    DC.W $0EEF,$00C8,$0007    ;
    DC.W $0FFF,$00C8,$0007    ;
    DC.W $FFFF

TIMER_A1:
    move.L    #$08000000,$FFFF8800.w
    add.l    #$12,$134.w
    RTE
TIMER_A2:
    move.L    #$08000000,$FFFF8800.w
    sub.l    #$12,$134.w
    RTE

    
CALC_B:    
MAKE_TIMER_B:

    AND.L    #$00000FFF,D1
    CMP.W    #$0010,D1
    BLE.S    NO_TB

    lea    TIMER_B1+4(pc),a4
    move.b    d0,(a4)

    LEA    TIMER_TAB(PC),A2
    CLR.L    D2
AGAIN_TB:
    CMP.W    (A2),D1
    BLT.S    USE_TBX
    LEA    6(A2),A2
    BRA.S    AGAIN_TB

USE_TBX:
    MOVE.W    2(A2),D2    ;MFP - Vorteiler
    MOVE.L    #160822,D0
    DIVU    D2,D0    ;/ Vorteiler
    MULU    D1,D0    ;* Periode
    ADD.L    #$00002000,D0    ;Finetuning
    LSL.L    #2,D0
    SWAP    D0    ;/131072 (PSG Takt -> swap)

    MOVE.W    4(A2),D1
    move.B    $FFFFFA1B.w,D2
    ANDI.B    #$F0,D2
    OR.B    D1,D2
    move.B    D0,$FFFFFA21.w    ;38
    move.B    D2,$FFFFFA1B.w    ;1
    RTS

NO_TB:    ANDI.B    #$F0,$FFFFFA1B.w
    RTS

TIMER_B1:
    move.L    #$09000000,$FFFF8800.w
    add.l    #$12,$120.w
    RTE
TIMER_B2:
    move.L    #$09000000,$FFFF8800.w
    sub.l    #$12,$120.w
    RTE

CALC_D:    
MAKE_TIMER_D:
    AND.L    #$00000FFF,D1
    CMP.W    #$0010,D1
    BLE.S    NO_TD

    lea    TIMER_D1+4(pc),a4
    move.b    d0,(a4)

    LEA    TIMER_TAB(PC),A2
    CLR.L    D2
AGAIN_TD:
    CMP.W    (A2),D1
    BLT.S    USE_TDX
    LEA    6(A2),A2
    BRA.S    AGAIN_TD

USE_TDX:
    MOVE.W    2(A2),D2    ;MFP - Vorteiler
    MOVE.L    #160822,D0
    DIVU    D2,D0    ;/ Vorteiler
    MULU    D1,D0    ;* Periode
    ADD.L    #$00002000,D0    ;Finetuning
    LSL.L    #2,D0
    SWAP    D0    ;/131072 (PSG Takt -> swap)

    MOVE.W    4(A2),D1
    move.B    D0,$FFFFFA25.w    ;
    ANDI.B    #$F0,$FFFFFA1D.w
    OR.B    D1,$FFFFFA1D.w
    RTS

NO_TD:    ANDI.B    #$F0,$FFFFFA1D.w
    RTS

TIMER_D1:
    move.L    #$0A000000,$FFFF8800.w
    add.l    #$12,$110.w
    RTE
TIMER_D2:
    move.L    #$0A000000,$FFFF8800.w
    sub.l    #$12,$110.w
    RTE

endmus:

