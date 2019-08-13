; vasm specific code (mostly macros)

    if _VASM_=1

    macro clrx dst
    if PC_REL_CODE
        clr.\0 \1-PLY_AKYst_Init(a4)
    else
        clr.\0 \1
    endif
    endm
    macro tstx dst
    if PC_REL_CODE
        tst.\0 \1-PLY_AKYst_Init(a4)
    else
        tst.\0 \1
    endif
    endm
    macro movex src,dst
    if PC_REL_CODE
        move.\0 \1,\2-PLY_AKYst_Init(a4)
    else
        move.\0 \1,\2
    endif
    endm

    macro dcbx
    dc.b \1
    even
    endm

	macro parse_events
      ;########################################################
      ;## Parse tune events

      if USE_EVENTS
      if PC_REL_CODE
      movem.l d0/a0/a4,-(sp)
      lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
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
      movex.b #1,event_flag ; there's a new event value to fetch
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

      if USE_SID_EVENTS
      if PC_REL_CODE
      movem.l d0/d1/a4,-(sp)
      lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
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
      and.b #EVENT_CHANNEL_A_MASK,d1
      movex.b d1,chan_a_sid_on
      move.b d0,d1
      and.b #EVENT_CHANNEL_B_MASK,d1
      movex.b d1,chan_b_sid_on
      move.b d0,d1
      and.b #EVENT_CHANNEL_C_MASK,d1
      movex.b d1,chan_c_sid_on
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


	macro readregs volume,frequency,subroutine

;Generic code interpreting the RegisterBlock
;IN:    a1 = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYst_ReadRegisterBlock\@:
        ;Gets the first byte of the line. What type? Jump to the matching code thanks to the zero flag.
PLY_AKYst_RRB_BranchOnNonInitailState\@:
        bne PLY_AKYst_RRB_NonInitialState\@

        ; Code from the bcs and above copied here so nothing will screw with the zero flag
        move.b (a1)+,d1
        
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTable\@(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTable\@(pc,a5.w)
PLY_AKYst_IS_JPTable\@:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardware\@-PLY_AKYst_IS_JPTable\@
        dc.w PLY_AKYst_RRB_IS_SoftwareOnly\@-PLY_AKYst_IS_JPTable\@
        dc.w PLY_AKYst_RRB_IS_HardwareOnly\@-PLY_AKYst_IS_JPTable\@
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardware\@-PLY_AKYst_IS_JPTable\@

;Generic code interpreting the RegisterBlock - Initial state.
;----------------------------------------------------------------
;IN:    a1 = Points after the first byte.
;       d3 = Register 7. All sounds are open (0) by default, all noises closed (1). The code must put ONLY bit 2 and 5 for sound and noise respectively. NOT any other bits!
;       d4 = f680
;       d7 (low byte) = Volume register.
;       d7 (high byte) = LSB frequency register.

;OUT:   a1 MUST point after the structure.
;       d3 = updated (ONLY bit 2 and 5).
;       d7 (low byte) = Volume register increased of 1 (*** IMPORTANT! The code MUST increase it, even if not using it! ***)
;       d7 (high byte) = LSB frequency register, increased of 2 (see above).


PLY_AKYst_RRB_IS_NoSoftwareNoHardware\@:

        ;No software no hardware.
        lsr.b #1,d1             ;Noise?
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise\@
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End\@
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise\@:
        ;There is a noise. Reads it.
        movex.b (a1)+,PLY_AKYst_PsgRegister6

        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End\@:
        
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolume\@:
        ;The volume is now in b0-b3.
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d1,(a3)
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    endif
        add.w #(2<<8)+1,d7                                      ;Increases the volume register (low byte) and frequency register (high byte).
        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        rts
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d1,(a3)
    else
        move.b d1,4*\volume(a3)
    endif
        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3
        bra readregs_out\@
  endif

;---------------------
PLY_AKYst_RRB_IS_HardwareOnly\@:

        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Retrig\@
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrig\@
PLY_AKYst_RRB_IS_HO_Retrig\@:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet A can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrig\@:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Noise\@
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoise\@
PLY_AKYst_RRB_IS_HO_Noise\@:                                      ;Reads the noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
 
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoise\@:
        ;The envelope.
        and.b #%1111,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Copies the hardware period.
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    endif
        add.w #$201,d7                                          ;Increases the volume register (low byte), and frequency register (high byte - mandatory!).
        rts
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    else
        move.b d4,4*\volume(a3)
    endif
        bra readregs_out\@
  endif

;---------------------
PLY_AKYst_RRB_IS_SoftwareOnly\@:

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_Noise\@
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise\@
PLY_AKYst_RRB_IS_SoftwareOnly_Noise\@:
        ;Noise. Reads it.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise\@:

        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d1,(a3)
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    endif
        addq.w #1,d7                                            ;Increases the volume register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d1,(a3)
    else
        move.b d1,4*\volume(a3)
    endif
  endif

        ;Reads the software period.
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\frequency,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*\frequency(a3)
    endif
  endif

  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
        rts
  else
    if !(SID_VOICES|DUMP_SONG)
		move.b #\frequency+1,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*(\frequency+1)(a3)
    endif
        bra readregs_out\@
  endif



;---------------------
PLY_AKYst_RRB_IS_SoftwareAndHardware\@:
        
        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Retrig\@
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrig\@
PLY_AKYst_RRB_IS_SAH_Retrig\@:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet d1 can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrig\@:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Noise\@
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoise\@
PLY_AKYst_RRB_IS_SAH_Noise\@:
        ;Reads the noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoise\@:

        ;The envelope.
        and.b #%1111,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Reads the software period.
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif       
        add.w #1<<8,d7                                          ;Increases the frequency register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\frequency,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*\frequency(a3)
    endif
  endif       
         
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\frequency+1,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*(\frequency+1)(a3)
    endif
  endif

  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    endif
        addq.w #1,d7                                            ;Increases the volume register.
        ;Copies the hardware period.
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1
        rts
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    else
        move.b d4,4*\volume(a3)
    endif
        ;Copies the hardware period.
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1
        bra readregs_out\@
  endif





;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKYst_RRB_NonInitialState\@:

        ; Code from the start of PLY_AKYst_ReadRegisterBlock copied here so nothing will screw with the zero flag        
        move.b (a1)+,d1

        move.b d1,d2
        and.b #%00001111,d2                                      ;Keeps 4 bits to be able to detect the loop. (%1000)
        add.b d2,d2

        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTable\@(pc),a5
        add.w PLY_AKYst_NIS_JPTable\@(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTable\@:

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\@-PLY_AKYst_NIS_JPTable\@          ;%0000
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%0001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%0010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\@-PLY_AKYst_NIS_JPTable\@          ;%0011

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\@-PLY_AKYst_NIS_JPTable\@          ;%0100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%0101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%0110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\@-PLY_AKYst_NIS_JPTable\@          ;%0111
        
        dc.w PLY_AKYst_RRB_NIS_ManageLoop\@-PLY_AKYst_NIS_JPTable\@          ;%1000. Loop!
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%1001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%1010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\@-PLY_AKYst_NIS_JPTable\@          ;%1011
        
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\@-PLY_AKYst_NIS_JPTable\@          ;%1100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%1101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\@-PLY_AKYst_NIS_JPTable\@          ;%1110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\@-PLY_AKYst_NIS_JPTable\@          ;%1111
        

PLY_AKYst_RRB_NIS_ManageLoop\@:
        ;Loops. Reads the next pointer to this RegisterBlock.
;Check if address is odd, and make it even if so
;Auto-even address. Not the best thing we could do performance wise but it'll do for now
        move.l a1,d1
        addq.l #1,d1
        bclr #0,d1
        move.l d1,a1
        move.w (a1),a1
        lea (a0,a1.w),a1

        ;Makes another iteration to read the new data.
        ;Since we KNOW it is not an initial state (because no jump goes to an initial state), we can directly go to the right branching.
        ;Reads the first byte.
        move.b (a1)+,d1
        
        ;Reads the next NIS state. We know there won't be any loop.
        move.b d1,d2                                            ;d1 must be saved!
        and.b #%00000011,d2
        add.b d2,d2

        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTable_NoLoop\@(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoop\@(pc,a5.w)




        ;This table jumps at each state, but AFTER the loop compensation.
PLY_AKYst_NIS_JPTable_NoLoop\@:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop\@-PLY_AKYst_NIS_JPTable_NoLoop\@     ;%00
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_Loop\@-PLY_AKYst_NIS_JPTable_NoLoop\@     ;%01
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_Loop\@-PLY_AKYst_NIS_JPTable_NoLoop\@     ;%10
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop\@-PLY_AKYst_NIS_JPTable_NoLoop\@     ;%11
        
        


PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\@:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop\@:
        ;No software, no hardware.
        ;NO NEED to test the loop! It has been tested before. We can optimize from the original code.
        move.b d1,d2                                            ;Used below.

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        ;Volume? bit 2 - 2.
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Volume\@
        bra.s PLY_AKYst_RRB_NIS_AfterVolume\@
PLY_AKYst_RRB_NIS_Volume\@:
        and.b #%1111,d1
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d1,(a3)
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    endif
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d1,(a3)
    else
        move.b d1,4*\volume(a3)
    endif
  endif
PLY_AKYst_RRB_NIS_AfterVolume\@:
  if \3
        add.w #$201,d7                                          ;Next volume register (low byte) and frequency registers (high byte)
  endif
        ;Noise? Was on bit 7, but there has been two shifts. We can't use d1, it may have been modified by the volume AND.
        btst #7-2,d2
        bne.s PLY_AKYst_RRB_NIS_Noise\@
  if \3
        rts
  else
        bra readregs_out\@
  endif       
PLY_AKYst_RRB_NIS_Noise\@:
        ;Noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
  if \3
        rts
  else
        bra readregs_out\@
  endif





;---------------------
PLY_AKYst_RRB_NIS_SoftwareOnly\@:
PLY_AKYst_RRB_NIS_SoftwareOnly_Loop\@:
        
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        move.b d1,d2
        ;Gets the volume (already shifted).
        and.b #%1111,d1
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d1,(a3)
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    endif
        addq.w #1,d7                                            ;Increases the volume register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d1,(a3)
    else
        move.b d1,4*\volume(a3)
    endif
  endif

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        btst #6-2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSP\@
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP\@
PLY_AKYst_RRB_NIS_SoftwareOnly_LSP\@:
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif
                                                                ;d7 high byte not incremented on purpose.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\frequency,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*\frequency(a3)
    endif
  endif

PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP\@:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        btst #7-2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise\@
  if \3
        add.w #2<<8,d7
        rts
  else
        bra readregs_out\@
  endif
        
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise\@:
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        move.b (a1)+,d1                                         ;Useless bits at the end, not a problem.
                                                                ;Sends the MSB software frequency.

  if \3
        add.w #1<<8,d7                                          ;Was not increased before.
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b d1,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\frequency+1,(a2)
        move.b d1,(a3)
    else
        move.b d1,4*(\frequency+1)(a3)
    endif
  endif
        
        rol.b #1,d1                                             ;Carry is isNoise?
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent\@
  if \3
        rts
  else
        bra readregs_out\@
  endif
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent\@:
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
       
        ;Is there a new noise value? If yes, gets the noise.
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_Noise\@
  if \3
        rts
  else
        bra readregs_out\@
  endif
PLY_AKYst_RRB_NIS_SoftwareOnly_Noise\@:
        ;Gets the noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
  if \3
        rts
  else
        bra readregs_out\@
  endif

;---------------------
PLY_AKYst_RRB_NIS_HardwareOnly\@:

PLY_AKYst_RRB_NIS_HardwareOnly_Loop\@:

        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rol.b #1,d1
        move.b d1,d2
        and.b #%1110,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        ;Hardware volume.
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    endif
        add.w #$201,d7                                          ;Increases the volume register (low byte), frequency register (high byte)
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    else
        move.b d4,4*\volume(a3)
    endif
  endif
        move.b d2,d1

        ;LSB for hardware period? Currently on b6.
        rol.b #2,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSB\@
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB\@
PLY_AKYst_RRB_NIS_HardwareOnly_LSB\@:
        movex.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB\@:

        ;MSB for hardware period?
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSB\@
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB\@
PLY_AKYst_RRB_NIS_HardwareOnly_MSB\@:
        movex.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB\@:
        
        ;Noise or retrig?
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop\@
  if \3
        rts
  else
        bra.s readregs_out\@
  endif

;---------------------
PLY_AKYst_RRB_NIS_SoftwareAndHardware\@:

PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop\@:

        ;Hardware volume.
                                                                ;Sends the volume.
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    endif
        addq.w #1,d7                                            ;Increases the volume register.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    else
        move.b d4,4*\volume(a3)
    endif
  endif
        ;LSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBH\@
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBH\@
PLY_AKYst_RRB_NIS_SAHH_LSBH\@:
        movex.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBH\@:

        ;MSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBH\@
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBH\@
PLY_AKYst_RRB_NIS_SAHH_MSBH\@:
        movex.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBH\@:
        
        ;LSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBS\@
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBS\@
PLY_AKYst_RRB_NIS_SAHH_LSBS\@:
  if \3
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif
                                                                ;d7 high byte not increased on purpose.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.w #\frequency,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*\frequency(a3)
    endif
  endif

PLY_AKYst_RRB_NIS_SAHH_AfterLSBS\@:
       
        ;MSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBS\@
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBS\@
PLY_AKYst_RRB_NIS_SAHH_MSBS\@:
                                                                ;Sends the MSB software frequency.
  if \3
        add.w #1<<8,d7
    if !(SID_VOICES|DUMP_SONG)
        move.w d7,(a2)
        move.b (a1)+,(a3)
    else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    endif
        sub.w #1<<8,d7                                          ;Yup. Will be compensated below.
  else
    if !(SID_VOICES|DUMP_SONG)
        move.b #\frequency+1,(a2)
        move.b (a1)+,(a3)
    else
        move.b (a1)+,4*(\frequency+1)(a3)
    endif
  endif

PLY_AKYst_RRB_NIS_SAHH_AfterMSBS\@:
  if \3
        add.w #2<<8,d7
  endif
        ;New hardware envelope?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_Envelope\@
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope\@
PLY_AKYst_RRB_NIS_SAHH_Envelope\@:
        movex.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope\@:

        ;Retrig and/or noise?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop\@
  if \3
        rts
  else
        bra.s readregs_out\@
  endif

        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop\@:
        ;Noise or retrig. Reads the next byte.
        move.b (a1)+,d1

        ;Retrig?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Retrig\@
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig\@
PLY_AKYst_RRB_NIS_S_NOR_Retrig\@:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet d1 can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig\@:

        ;Noise? If no, nothing more to do.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Noise\@
  if \3
        rts
  else
        bra.s readregs_out\@
  endif
PLY_AKYst_RRB_NIS_S_NOR_Noise\@:
        
        ;Noise. Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ;Is there a new noise value? If yes, gets the noise.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoise\@
  if \3
        rts
  else
        bra.s readregs_out\@
  endif
PLY_AKYst_RRB_NIS_S_NOR_SetNoise\@:
        ;Sets the noise.
        movex.b d1,PLY_AKYst_PsgRegister6 
  if \3
        rts
  else
;        bra.s readregs_out\@
  endif

readregs_out\@:
	endm

    endif
