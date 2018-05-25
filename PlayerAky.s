;
; AKY music player
;
; Port by George Nakos (GGN of pick-your-favorite-group - KUA software productions/D-Bug/Paradize/Reboot/Bello games)
; (yes, crews are becoming pointless :))
;
; Based on the soruces of "Stabilized AKY music player - V1.0."
;       By Julien Névo a.k.a. Targhan/Arkos.
;       February 2018.
;
; This source was written for the rmac assembler (http://virtualjaguar.kicks-ass.net/builds/)
; It should be fairly easy to adapt to other assemblers.
;
; Note that the source makes use of macros, so take a look at their definitions (after these messages end) before reading the code

; Equates that control code generation:
; PC_REL_CODE   - off by default, define this to produce slower SNDH compatible code (i.e. no absolute addressing)
; AVOID_SMC     - off by default, define this to produce slower but more compatible code, friendly for cache endabled CPUs
; UNROLLED_CODE - off by default, define this to produce unrolled code which will be slightly faster
; SID_VOICES    - off by default, define this to use SID style voices
;
; Note that if you define want to create SNDH files, you should enable PC_REL_CODE and AVOID_SMC as well. SNDH files are meant to be compatible with all platforms

; Stuff TODO:
; @ Clean up register usage
; @ In PLY_AKYst_RRB_NIS_ManageLoop there is an auto-even of address happening due to the way the data is exported. This can be fixed by a) Exporting all data as words, b) pre-parsing the tune during init, finding odd addresses, even them and patch all affected offsets
        
; Macros for sndh or normal player.
; In sndh mode the player has to be position independent, and that mostly boils down
; to being PC relative. So we define some macros for the instructions that require
; one format or the other, just so both versions of the player can be generated
; from the same source

    .if ^^defined movex
    .macro movex src,dst
    .if PC_REL_CODE
        move\! \src,\dst - PLY_AKYst_Init(a4)
    .else
        move\! \src,\dst
    .endif
    .endm
    .endif

PLY_AKYst_RRB_NoiseChannelBit equ 5                             ;Bit to modify to set/reset the noise channel.
PLY_AKYst_RRB_SoundChannelBit equ 2                             ;Bit to modify to set/reset the sound channel.

;
; Subroutine PLY_AKYst_ReadRegisterBlock as a macro, so it can be inlined with the code
; volume = the YM volume register to update
; frequency = the YM low frequency register to update
; subroutine = 1 if used as a subroutine, 0 if used as inline expansion
; Originally the code used to have PLY_AKYst_ReadRegisterBlock as a subroutine
; which would call 3 times, once for each YM channel. In order to gain some speed
; this was changed into a macro and inlined with the code. However, people might still need
; the subroutine version because of space reasons (small intros, etc). Hence the
; "subroutine" parameter.
; Generally for each register write there are 4 different code paths:
; 1) Code used as subroutine, no SID voices
; 2) Code used as subroutine, SID voices
; 3) Code inlined, no SID voices
; 4) Code inlined, SID voices
; Each of those paths has slightly different code: the SID versions don't write to the YM
; directly but fill in a table for the SID routine, while the normal versions bang the
; registers directly. Each code path is of different optimisation maturity, so tread lightly!
; While the inlined versions have the luxury of knowing which registers to update beforehand,
; the subroutine versions don't. The mechanism used is to carry both values in d7:
; volume is low byte, frequency is high. These need to be updated after each write,
; as you'll notice. 
;

	.macro readregs volume,frequency,subroutine

;Generic code interpreting the RegisterBlock
;IN:    a1 = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYst_ReadRegisterBlock\~:
        ;Gets the first byte of the line. What type? Jump to the matching code thanks to the zero flag.
PLY_AKYst_RRB_BranchOnNonInitailState\~:
        bne PLY_AKYst_RRB_NonInitialState\~

        ; Code from the bcs and above copied here so nothing will screw with the zero flag
        move.b (a1)+,d1
        
        move.b d1,d2
        and.b #%00000011,d2
        add.b d2,d2
        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_IS_JPTable\~(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_IS_JPTable\~(pc,a5.w)
PLY_AKYst_IS_JPTable\~:
        dc.w PLY_AKYst_RRB_IS_NoSoftwareNoHardware\~-PLY_AKYst_IS_JPTable\~
        dc.w PLY_AKYst_RRB_IS_SoftwareOnly\~        -PLY_AKYst_IS_JPTable\~
        dc.w PLY_AKYst_RRB_IS_HardwareOnly\~        -PLY_AKYst_IS_JPTable\~
        dc.w PLY_AKYst_RRB_IS_SoftwareAndHardware\~ -PLY_AKYst_IS_JPTable\~

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


PLY_AKYst_RRB_IS_NoSoftwareNoHardware\~:

        ;No software no hardware.
        lsr.b #1,d1             ;Noise?
        bcs.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise\~
        bra.s PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End\~
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise\~:
        ;There is a noise. Reads it.
        movex.b (a1)+,PLY_AKYst_PsgRegister6

        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d4
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadNoise_End\~:
        
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_ReadVolume\~:
        ;The volume is now in b0-b3.
  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d1,(a3)
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    .endif
        add.w #(2<<8)+1,d7                                      ;Increases the volume register (low byte) and frequency register (high byte).
        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        rts
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d1,(a3)
    .else
        move.b d1,4*\volume(a3)
    .endif
        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit, d3
        bra readregs_out\~
  .endif

;---------------------
PLY_AKYst_RRB_IS_HardwareOnly\~:

        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Retrig\~
        bra.s PLY_AKYst_RRB_IS_HO_AfterRetrig\~
PLY_AKYst_RRB_IS_HO_Retrig\~:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet A can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_HO_AfterRetrig\~:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_HO_Noise\~
        bra.s PLY_AKYst_RRB_IS_HO_AfterNoise\~
PLY_AKYst_RRB_IS_HO_Noise\~:                                      ;Reads the noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
 
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_HO_AfterNoise\~:
        ;The envelope.
        and.b #%1111,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Copies the hardware period.
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    .endif
        add.w #$201,d7                                          ;Increases the volume register (low byte), and frequency register (high byte - mandatory!).
        rts
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    .else
        move.b d4,4*\volume(a3)
    .endif
        bra readregs_out\~
  .endif

;---------------------
PLY_AKYst_RRB_IS_SoftwareOnly\~:

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SoftwareOnly_Noise\~
        bra.s PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise\~
PLY_AKYst_RRB_IS_SoftwareOnly_Noise\~:
        ;Noise. Reads it.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SoftwareOnly_AfterNoise\~:

        ;Reads the volume (now b0-b3).
        ;Note: we do NOT peform a "and %1111" because we know the bit 7 of the original byte is 0, so the bit 4 is currently 0. Else the hardware volume would be on!
  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d1,(a3)
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    .endif
        addq.w #1,d7                                            ;Increases the volume register.
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d1,(a3)
    .else
        move.b d1,4*\volume(a3)
    .endif
  .endif

        ;Reads the software period.
  .if \subroutine
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
  .else
    .if !SID_VOICES
        move.b #\frequency,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*\frequency(a3)
    .endif
  .endif

  .if \subroutine
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
        rts
  .else
    .if !SID_VOICES
		move.b #\frequency+1,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*(\frequency+1)(a3)
    .endif
        bra readregs_out\~
  .endif



;---------------------
PLY_AKYst_RRB_IS_SoftwareAndHardware\~:
        
        ;Retrig?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Retrig\~
        bra.s PLY_AKYst_RRB_IS_SAH_AfterRetrig\~
PLY_AKYst_RRB_IS_SAH_Retrig\~:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet d1 can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_IS_SAH_AfterRetrig\~:

        ;Noise?
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_IS_SAH_Noise\~
        bra.s PLY_AKYst_RRB_IS_SAH_AfterNoise\~
PLY_AKYst_RRB_IS_SAH_Noise\~:
        ;Reads the noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
PLY_AKYst_RRB_IS_SAH_AfterNoise\~:

        ;The envelope.
        and.b #%1111,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Reads the software period.
  .if \subroutine
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif       
        add.w #1<<8,d7                                          ;Increases the frequency register.
  .else
    .if !SID_VOICES
        move.b #\frequency,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*\frequency(a3)
    .endif
  .endif       
         
  .if \subroutine
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
  .else
    .if !SID_VOICES
        move.b #\frequency+1,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*(\frequency+1)(a3)
    .endif
  .endif

  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    .endif
        addq.w #1,d7                                            ;Increases the volume register.
        ;Copies the hardware period.
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1
        rts
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(volume to 16).
    .else
        move.b d4,4*\volume(a3)
    .endif
        ;Copies the hardware period.
        movex.b (a1)+,PLY_AKYst_PsgRegister11
        movex.b (a1)+,PLY_AKYst_PsgRegister11+1
        bra readregs_out\~
  .endif





;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKYst_RRB_NonInitialState\~:

        ; Code from the start of PLY_AKYst_ReadRegisterBlock copied here so nothing will screw with the zero flag        
        move.b (a1)+,d1

        move.b d1,d2
        and.b #%00001111,d2                                      ;Keeps 4 bits to be able to detect the loop. (%1000)
        add.b d2,d2

        lsr.b #2,d1
        ext.w d2
        lea PLY_AKYst_NIS_JPTable\~(pc),a5
        add.w PLY_AKYst_NIS_JPTable\~(pc,d2.w),a5
        jmp (a5)
PLY_AKYst_NIS_JPTable\~:

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\~-PLY_AKYst_NIS_JPTable\~          ;%0000
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%0001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%0010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\~ -PLY_AKYst_NIS_JPTable\~          ;%0011

        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\~-PLY_AKYst_NIS_JPTable\~          ;%0100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%0101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%0110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\~ -PLY_AKYst_NIS_JPTable\~          ;%0111
        
        dc.w PLY_AKYst_RRB_NIS_ManageLoop\~          -PLY_AKYst_NIS_JPTable\~          ;%1000. Loop!
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%1001
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%1010
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\~ -PLY_AKYst_NIS_JPTable\~          ;%1011
        
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\~-PLY_AKYst_NIS_JPTable\~          ;%1100
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%1101
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly\~        -PLY_AKYst_NIS_JPTable\~          ;%1110
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware\~ -PLY_AKYst_NIS_JPTable\~          ;%1111
        

PLY_AKYst_RRB_NIS_ManageLoop\~:
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
        lea PLY_AKYst_NIS_JPTable_NoLoop\~(pc),a5
        add.w d2,a5
        move.w (a5),a5
        jmp PLY_AKYst_NIS_JPTable_NoLoop\~(pc,a5.w)




        ;This table jumps at each state, but AFTER the loop compensation.
PLY_AKYst_NIS_JPTable_NoLoop\~:
        dc.w PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop\~-PLY_AKYst_NIS_JPTable_NoLoop\~     ;%00
        dc.w PLY_AKYst_RRB_NIS_SoftwareOnly_Loop\~        -PLY_AKYst_NIS_JPTable_NoLoop\~     ;%01
        dc.w PLY_AKYst_RRB_NIS_HardwareOnly_Loop\~        -PLY_AKYst_NIS_JPTable_NoLoop\~     ;%10
        dc.w PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop\~ -PLY_AKYst_NIS_JPTable_NoLoop\~     ;%11
        
        


PLY_AKYst_RRB_NIS_NoSoftwareNoHardware\~:
PLY_AKYst_RRB_NIS_NoSoftwareNoHardware_Loop\~:
        ;No software, no hardware.
        ;NO NEED to test the loop! It has been tested before. We can optimize from the original code.
        move.b d1,d2                                            ;Used below.

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        ;Volume? bit 2 - 2.
        lsr.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Volume\~
        bra.s PLY_AKYst_RRB_NIS_AfterVolume\~
PLY_AKYst_RRB_NIS_Volume\~:
        and.b #%1111,d1
  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d1,(a3)
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    .endif
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d1,(a3)
    .else
        move.b d1,4*\volume(a3)
    .endif
  .endif
PLY_AKYst_RRB_NIS_AfterVolume\~:
  .if \subroutine
        add.w #$201,d7                                          ;Next volume register (low byte) and frequency registers (high byte)
  .endif
        ;Noise? Was on bit 7, but there has been two shifts. We can't use d1, it may have been modified by the volume AND.
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_Noise\~
  .if \subroutine
        rts
  .else
        bra readregs_out\~
  .endif       
PLY_AKYst_RRB_NIS_Noise\~:
        ;Noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
  .if \subroutine
        rts
  .else
        bra readregs_out\~
  .endif





;---------------------
PLY_AKYst_RRB_NIS_SoftwareOnly\~:
PLY_AKYst_RRB_NIS_SoftwareOnly_Loop\~:
        
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        move.b d1,d2
        ;Gets the volume (already shifted).
        and.b #%1111,d1
  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d1,(a3)
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    .endif
        addq.w #1,d7                                            ;Increases the volume register.
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d1,(a3)
    .else
        move.b d1,4*\volume(a3)
    .endif
  .endif

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        btst #6 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_LSP\~
        bra.s PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP\~
PLY_AKYst_RRB_NIS_SoftwareOnly_LSP\~:
  .if \subroutine
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif
                                                                ;d7 high byte not incremented on purpose.
  .else
    .if !SID_VOICES
        move.b #\frequency,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*\frequency(a3)
    .endif
  .endif

PLY_AKYst_RRB_NIS_SoftwareOnly_AfterLSP\~:

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        btst #7 - 2,d2
        bne.s PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise\~
  .if \subroutine
        add.w #2<<8,d7
        rts
  .else
        bra readregs_out\~
  .endif
        
PLY_AKYst_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise\~:
        ;MSP and noise?, in the next byte. nipppp (n = newNoise? i = isNoise? p = MSB period).
        move.b (a1)+,d1                                         ;Useless bits at the end, not a problem.
                                                                ;Sends the MSB software frequency.

  .if \subroutine
        add.w #1<<8,d7                                          ;Was not increased before.
    .if !SID_VOICES
        move.w d7,(a2)
        move.b d1,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b d1,(a3,d0.w)
    .endif
        add.w #1<<8,d7                                          ;Increases the frequency register.
  .else
    .if !SID_VOICES
        move.b #\frequency+1,(a2)
        move.b d1,(a3)
    .else
        move.b d1,4*(\frequency+1)(a3)
    .endif
  .endif
        
        rol.b #1,d1                                             ;Carry is isNoise?
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent\~
  .if \subroutine
        rts
  .else
        bra readregs_out\~
  .endif
PLY_AKYst_RRB_NIS_SoftwareOnly_NoisePresent\~:
        ;Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
       
        ;Is there a new noise value? If yes, gets the noise.
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SoftwareOnly_Noise\~
  .if \subroutine
        rts
  .else
        bra readregs_out\~
  .endif
PLY_AKYst_RRB_NIS_SoftwareOnly_Noise\~:
        ;Gets the noise.
        movex.b (a1)+,PLY_AKYst_PsgRegister6
  .if \subroutine
        rts
  .else
        bra readregs_out\~
  .endif

;---------------------
PLY_AKYst_RRB_NIS_HardwareOnly\~:

PLY_AKYst_RRB_NIS_HardwareOnly_Loop\~:

        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 0 must be 0.
        rol.b #1,d1
        move.b d1,d2
        and.b #%1110,d1
        movex.b d1,PLY_AKYst_PsgRegister13

        ;Closes the sound channel.
        bset #PLY_AKYst_RRB_SoundChannelBit,d3

        ;Hardware volume.
  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    .endif
        add.w #$201,d7                                          ;Increases the volume register (low byte), frequency register (high byte)
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    .else
        move.b d4,4*\volume(a3)
    .endif
  .endif
        move.b d2,d1

        ;LSB for hardware period? Currently on b6.
        rol.b #2,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_LSB\~
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB\~
PLY_AKYst_RRB_NIS_HardwareOnly_LSB\~:
        movex.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_HardwareOnly_AfterLSB\~:

        ;MSB for hardware period?
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_HardwareOnly_MSB\~
        bra.s PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB\~
PLY_AKYst_RRB_NIS_HardwareOnly_MSB\~:
        movex.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_HardwareOnly_AfterMSB\~:
        
        ;Noise or retrig?
        rol.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop\~
  .if \subroutine
        rts
  .else
        bra.s readregs_out\~
  .endif

;---------------------
PLY_AKYst_RRB_NIS_SoftwareAndHardware\~:

PLY_AKYst_RRB_NIS_SoftwareAndHardware_Loop\~:

        ;Hardware volume.
                                                                ;Sends the volume.
  .if \subroutine
    .if !SID_VOICES
        move.b d7,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    .else
        move.w d7,d0
        ext.w d0
        add.w d0,d0
        add.w d0,d0
        move.b d4,(a3,d0.w)
    .endif
        addq.w #1,d7                                            ;Increases the volume register.
  .else
    .if !SID_VOICES
        move.b #\volume,(a2)
        move.b d4,(a3)                                     ;(16 = hardware volume).
    .else
        move.b d4,4*\volume(a3)
    .endif
  .endif
        ;LSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBH\~
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBH\~
PLY_AKYst_RRB_NIS_SAHH_LSBH\~:
        movex.b (a1)+,PLY_AKYst_PsgRegister11
PLY_AKYst_RRB_NIS_SAHH_AfterLSBH\~:

        ;MSB of hardware period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBH\~
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBH\~
PLY_AKYst_RRB_NIS_SAHH_MSBH\~:
        movex.b (a1)+,PLY_AKYst_PsgRegister12
PLY_AKYst_RRB_NIS_SAHH_AfterMSBH\~:
        
        ;LSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_LSBS\~
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterLSBS\~
PLY_AKYst_RRB_NIS_SAHH_LSBS\~:
  .if \subroutine
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif
                                                                ;d7 high byte not increased on purpose.
  .else
    .if !SID_VOICES
        move.w #\frequency,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*\frequency(a3)
    .endif
  .endif

PLY_AKYst_RRB_NIS_SAHH_AfterLSBS\~:
       
        ;MSB of software period?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_MSBS\~
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterMSBS\~
PLY_AKYst_RRB_NIS_SAHH_MSBS\~:
                                                                ;Sends the MSB software frequency.
  .if \subroutine
        add.w #1<<8,d7
    .if !SID_VOICES
        move.w d7,(a2)
        move.b (a1)+,(a3)
    .else
        move.w d7,d0
        lsr.w #8,d0
        add.w d0,d0
        add.w d0,d0
        move.b (a1)+,(a3,d0.w)
    .endif
        sub.w #1<<8,d7                                          ;Yup. Will be compensated below.
  .else
    .if !SID_VOICES
        move.b #\frequency+1,(a2)
        move.b (a1)+,(a3)
    .else
        move.b (a1)+,4*(\frequency+1)(a3)
    .endif
  .endif

PLY_AKYst_RRB_NIS_SAHH_AfterMSBS\~:
  .if \subroutine
        add.w #2<<8,d7
  .endif
        ;New hardware envelope?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_SAHH_Envelope\~
        bra.s PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope\~
PLY_AKYst_RRB_NIS_SAHH_Envelope\~:
        movex.b (a1)+,PLY_AKYst_PsgRegister13
PLY_AKYst_RRB_NIS_SAHH_AfterEnvelope\~:

        ;Retrig and/or noise?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop\~
  .if \subroutine
        rts
  .else
        bra.s readregs_out\~
  .endif

        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKYst_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop\~:
        ;Noise or retrig. Reads the next byte.
        move.b (a1)+,d1

        ;Retrig?
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Retrig\~
        bra.s PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig\~
PLY_AKYst_RRB_NIS_S_NOR_Retrig\~:
        bset #7,d1                                              ;A value to make sure the retrig is performed, yet d1 can still be use.
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig
PLY_AKYst_RRB_NIS_S_NOR_AfterRetrig\~:

        ;Noise? If no, nothing more to do.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_Noise\~
  .if \subroutine
        rts
  .else
        bra.s readregs_out\~
  .endif
PLY_AKYst_RRB_NIS_S_NOR_Noise\~:
        
        ;Noise. Opens the noise channel.
        bclr #PLY_AKYst_RRB_NoiseChannelBit,d3
        ;Is there a new noise value? If yes, gets the noise.
        ror.b #1,d1
        bcs.s PLY_AKYst_RRB_NIS_S_NOR_SetNoise\~
  .if \subroutine
        rts
  .else
        bra.s readregs_out\~
  .endif
PLY_AKYst_RRB_NIS_S_NOR_SetNoise\~:
        ;Sets the noise.
        movex.b d1,PLY_AKYst_PsgRegister6 
  .if \subroutine
        rts
  .else
;        bra.s readregs_out\~
  .endif

readregs_out\~:
	.endm


    .if !AVOID_SMC
PLY_AKYst_OPCODE_SZF equ $7200                                  ;Opcode for "moveq #0,d0".
PLY_AKYst_OPCODE_CZF  equ $72ff                                 ;Opcode for "moveq #-1,d0".
    .else
PLY_AKYst_OPCODE_SZF equ $0000
PLY_AKYst_OPCODE_CZF  equ $ffff
    .endif

PLY_AKYst_Start:
        ;Hooks for external calls. Can be removed if not needed.
        bra.s PLY_AKYst_Init                                    ;Player + 0.
        bra.s PLY_AKYst_Play                                    ;Player + 2.
    


;       Initializes the player.
;       a0.l=music address
PLY_AKYst_Init:
    .if PC_REL_CODE
        lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
        .if USE_EVENTS=1
        ;######################################################
        ;## Patch events data for PC-relativeness

        movem.l a5-a6,-(sp)
        lea tune_events_end(pc),a5
        lea Events_Loop(pc),a6 ; loop point in event data
        move.l (a6),-4(a5)
        movem.l (sp)+,a5-a6

        ;## Patch events data for PC-relativeness
        ;######################################################
        .endif ; .if USE_EVENTS=1
    .endif ; .if PC_REL_CODE

        ;Skips the header.
        addq.l #1,a0                                            ;Skips the format version.
        move.b (a0)+,d1                                         ;Channel count.
PLY_AKYst_Init_SkipHeaderLoop:                                  ;There is always at least one PSG to skip.
        addq.l #4,a0
        subq.b #3,d1                                            ;A PSG is three channels.
        beq.s PLY_AKYst_Init_SkipHeaderEnd
        bcc.s PLY_AKYst_Init_SkipHeaderLoop                     ;Security in case of the PSG channel is not a multiple of 3.
PLY_AKYst_Init_SkipHeaderEnd:
        movex.l a0,PLY_AKYst_PtLinker                           ;a0 now points on the Linker.

        move.w #PLY_AKYst_OPCODE_SZF,d0
        movex.w d0,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        movex.w d0,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        movex.w d0,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        movex.w #1,PLY_AKYst_PatternFrameCounter

        rts

;       Plays the music. It must have been initialized before.
;       The interruption SHOULD be disabled (DI), as the stack is heavily used.
;       a0.l=start of tune

PLY_AKYst_Play:

        .if SID_VOICES
        lea values_store+2(pc),a3
        .else
        lea $ffff8800.w,a2                                      ;cache YM registers
        lea $ffff8802.w,a3
        .endif

        .if PC_REL_CODE
        lea PLY_AKYst_Init(pc),a4                               ;base pointer for PC relative stores
        .endif

;Linker.
;----------------------------------------
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PatternFrameCounter equ * + 2
        move.w #1,d1                                            ;How many frames left before reading the next Pattern.
    .else
        move.w PLY_AKYst_PatternFrameCounter(pc),d1
    .endif
        subq.w #1,d1

        beq.s PLY_AKYst_PatternFrameCounter_Over
        movex.w d1,PLY_AKYst_PatternFrameCounter
        bra.s PLY_AKYst_PatternFrameManagement_End

PLY_AKYst_PatternFrameCounter_Over:

;The pattern is over. Reads the next one.
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PtLinker = * + 2
        lea 0.l,a6                                              ;Points on the Pattern of the linker.
    .else
        move.l PLY_AKYst_PtLinker(pc),a6                        ;Points on the Pattern of the linker.
    .endif
        move.w (a6)+,d1                                         ;Gets the duration of the Pattern, or 0 if end of the song.
        bne.s PLY_AKYst_LinkerNotEndSong
        ;End of the song. Where to loop?
        move.w (a6)+,d1
        ;We directly point on the frame counter of the pattern to loop to.
        lea (a0,d1.w),a6
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
        move.w (a6)+,d1
PLY_AKYst_LinkerNotEndSong:
        movex.w d1,PLY_AKYst_PatternFrameCounter

        movex.w (a6)+,PLY_AKYst_Channel1_PtTrack
        movex.w (a6)+,PLY_AKYst_Channel2_PtTrack
        movex.w (a6)+,PLY_AKYst_Channel3_PtTrack
        movex.l a6,PLY_AKYst_PtLinker

        ;Resets the RegisterBlocks of the channels.
        moveq #1,d1
        movex.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock
        movex.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock
        movex.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock
PLY_AKYst_PatternFrameManagement_End:

;Reading the Track - channel 1.
;----------------------------------------
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1                                            ;Frames to wait before reading the next RegisterBlock. 0 = finished.
    .else
        move.b PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock(pc),d1
    .endif
        subq.b #1,d1
        beq.s PLY_AKYst_Channel1_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel1_RegisterBlock_Process
PLY_AKYst_Channel1_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        movex.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtTrack = * + 2
        lea 0(a0),a6                                            ;Points on the Track.
    .else
        move.w PLY_AKYst_Channel1_PtTrack(pc),a6
        lea (a0,a6.w),a6
    .endif
        move.b (a6),d1                                          ;Gets the duration.
        move.w 2(a6),a1                                         ;Reads the RegisterBlock address.
        lea (a0,a1.w),a1
        movex.l a1,PLY_AKYst_Channel1_PtRegisterBlock
        addq.w #4,a6

        sub.l a0,a6                                             ;TODO can we do without this?

        movex.w a6,PLY_AKYst_Channel1_PtTrack
        ;d1 is the duration of the block.
PLY_AKYst_Channel1_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        movex.b d1,PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock



;Reading the Track - channel 2.
;----------------------------------------
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
    .else
        move.b PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock(pc),d1
    .endif
        subq.b #1,d1       
        beq.s PLY_AKYst_Channel2_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel2_RegisterBlock_Process
PLY_AKYst_Channel2_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        movex.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_PtTrack = * + 2
        lea 0(a0),a6                                            ;Points on the Track.
    .else
        move.w PLY_AKYst_Channel2_PtTrack(pc),a6
        lea (a0,a6.w),a6
    .endif
        move.b (a6),d1                                          ;Gets the duration (b1-7). b0 = silence block?
        move.w 2(a6),a1
        lea (a0,a1.w),a1
        movex.l a1,PLY_AKYst_Channel2_PtRegisterBlock
        addq.w #4,a6

        sub.l a0,a6                                             ;TODO can we do without this?

        movex.w a6,PLY_AKYst_Channel2_PtTrack
        ;d1 is the duration of the block.
PLY_AKYst_Channel2_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        movex.b d1,PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock




;Reading the Track - channel 3.
;----------------------------------------
;PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock: ld a,1         ;Frames to wait before reading the next RegisterBlock. 0 = finished.
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock = * + 3
        move.b #1,d1    ;Frames to wait before reading the next RegisterBlock. 0 = finished.
    .else
        move.b PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock(pc),d1
    .endif
        subq.b #1,d1
        beq.s PLY_AKYst_Channel3_RegisterBlock_Finished
        bra.s PLY_AKYst_Channel3_RegisterBlock_Process
PLY_AKYst_Channel3_RegisterBlock_Finished:
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        movex.w #PLY_AKYst_OPCODE_SZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtTrack equ * + 2
        lea 0(a0),a6                                            ;Points on the Track.
    .else
        move.w PLY_AKYst_Channel3_PtTrack(pc),a6
        lea (a0,a6.w),a6
    .endif

        move.b (a6),d1                                          ;Gets the duration (b1-7). b0 = silence block?
        move.w 2(a6),a1
        lea (a0,a1.w),a1
        movex.l a1,PLY_AKYst_Channel3_PtRegisterBlock
        addq.w #4,a6

        sub.l a0,a6                                             ;TODO can we do without this?

        movex.w a6,PLY_AKYst_Channel3_PtTrack
PLY_AKYst_Channel3_RegisterBlock_Process:
        ;Processes the RegisterBlock, whether it is the current one or a new one.
        movex.b d1,PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock











;Reading the RegisterBlock.
;----------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------

    .if !UNROLLED_CODE
        move.w #((0 * 256) + 8),d7                              ;d7 high byte = first frequency register, d7 low byte = first volume register.
    .endif
        move.w #$f690,d4                                        ;$90 used for both $80 for the PSG, and volume 16!
        
        ;In d3, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
        move.w #%11100000,d3


    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_PtRegisterBlock = * + 2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
    .else
        move.l PLY_AKYst_Channel1_PtRegisterBlock(pc),a1
    .endif
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel1_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
    .else
        move.w PLY_AKYst_Channel1_RegisterBlockLineState_Opcode(pc),d1
    .endif
    .if !UNROLLED_CODE
        bsr PLY_AKYst_ReadRegisterBlock
    .else
        readregs 8,0,0
    .endif
PLY_AKYst_Channel1_RegisterBlock_Return:
        movex.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel1_RegisterBlockLineState_Opcode
        movex.l a1,PLY_AKYst_Channel1_PtRegisterBlock           ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 2
;----------------------------------------

        ;Shifts the R7 for the next channels.
        lsr.b #1,d3
        

    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_PtRegisterBlock equ * + 2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
    .else
        move.l PLY_AKYst_Channel2_PtRegisterBlock(pc),a1
    .endif
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel2_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
    .else
        move.w PLY_AKYst_Channel2_RegisterBlockLineState_Opcode(pc),d1
    .endif
    .if !UNROLLED_CODE
        bsr PLY_AKYst_ReadRegisterBlock
    .else
        readregs 9,2,0
    .endif
PLY_AKYst_Channel2_RegisterBlock_Return:
        movex.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel2_RegisterBlockLineState_Opcode
        movex.l a1,PLY_AKYst_Channel2_PtRegisterBlock           ;This is new pointer on the RegisterBlock.


;Reading the RegisterBlock - Channel 3
;----------------------------------------

        ;Shifts the R7 for the next channels.
        lsr.b #1,d3

    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_PtRegisterBlock equ * + 2
        lea 0.l,a1                                              ;Points on the data of the RegisterBlock to read.
    .else
        move.l PLY_AKYst_Channel3_PtRegisterBlock(pc),a1
    .endif
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_Channel3_RegisterBlockLineState_Opcode: moveq #0,d1   ;if initial state, "moveq #0,d1" / "moveq #-1,d1" if non-initial state.
    .else
        move.w PLY_AKYst_Channel3_RegisterBlockLineState_Opcode(pc),d1
    .endif
    .if !UNROLLED_CODE
        bsr PLY_AKYst_ReadRegisterBlock
    .else
        readregs 10,4,0
    .endif
PLY_AKYst_Channel3_RegisterBlock_Return:
        movex.w #PLY_AKYst_OPCODE_CZF,PLY_AKYst_Channel3_RegisterBlockLineState_Opcode
        movex.l a1,PLY_AKYst_Channel3_PtRegisterBlock           ;This is new pointer on the RegisterBlock.

        ;Register 7 to d1.
        move.w d3,d1

;Almost all the channel specific registers have been sent. Now sends the remaining registers (6, 7, 11, 12, 13).

;Register 7. Note that managing register 7 before 6/11/12 is done on purpose (the 6/11/12 registers are filled using OUTI).

    .if !SID_VOICES
        move.b #7,(a2)
        move.b d1,(a3)
    .else
        move.b d1,(7*4)(a3)
    .endif

;Register 6
    .if !SID_VOICES
        move.b #6,(a2)
        move.b PLY_AKYst_PsgRegister6(pc),(a3)
    .else
        move.b PLY_AKYst_PsgRegister6(pc),(6*4)(a3)
    .endif

;Register 11
    .if !SID_VOICES
        move.b #11,(a2)
        move.b PLY_AKYst_PsgRegister11(pc),(a3)
    .else
        lea $ffff8800.w,a2                                      ;we're going to write these values immediately to the YM so we might as well load an address register
        move.b #11,$ffff8800.w
        move.b PLY_AKYst_PsgRegister11(pc),$ffff8802.w
    .endif       

;Register 12
    .if !SID_VOICES
        move.b #12,(a2)
        move.b PLY_AKYst_PsgRegister12(pc),(a3)
    .else
        move.b #12,(a2)
        move.b PLY_AKYst_PsgRegister12(pc),2(a2)
    .endif


;Register 13
PLY_AKYst_PsgRegister13_Code:
        move.b PLY_AKYst_PsgRegister13(pc),d1
    .if !AVOID_SMC
* SMC - DO NOT OPTIMISE!
PLY_AKYst_PsgRegister13_Retrig equ * + 3
        cmp.b #255,d1                                           ;If IsRetrig?, force the R13 to be triggered.
    .else
        cmp.b PLY_AKYst_PsgRegister13_Retrig(pc),d1
    .endif
        bne.s PLY_AKYst_PsgRegister13_Change
        bra.s PLY_AKYst_PsgRegister13_End
PLY_AKYst_PsgRegister13_Change:
        movex.b d1,PLY_AKYst_PsgRegister13_Retrig

    .if !SID_VOICES
        move.b #13,(a2)
        move.b d1,(a3)
    .else
        move.b #13,(a2)
        move.b d1,2(a2)
    .endif

PLY_AKYst_PsgRegister13_End:



PLY_AKYst_Exit:
        rts

    .if AVOID_SMC
PLY_AKYst_PatternFrameCounter:                      .ds.w 1
PLY_AKYst_PtLinker:                                 .ds.l 1
PLY_AKYst_Channel1_WaitBeforeNextRegisterBlock:     .ds.b 1
PLY_AKYst_Channel1_PtTrack:                         .ds.w 1
PLY_AKYst_Channel2_WaitBeforeNextRegisterBlock:     .ds.b 1
PLY_AKYst_Channel2_PtTrack:                         .ds.w 1
PLY_AKYst_Channel3_WaitBeforeNextRegisterBlock:     .ds.b 1
PLY_AKYst_Channel3_PtTrack:                         .ds.w 1
PLY_AKYst_Channel1_PtRegisterBlock:                 .ds.l 1
PLY_AKYst_Channel2_PtRegisterBlock:                 .ds.l 1
PLY_AKYst_Channel3_PtRegisterBlock:                 .ds.l 1
PLY_AKYst_PsgRegister13_Retrig:                     .ds.b 1
PLY_AKYst_Channel1_RegisterBlockLineState_Opcode:   .ds.w 1
PLY_AKYst_Channel2_RegisterBlockLineState_Opcode:   .ds.w 1
PLY_AKYst_Channel3_RegisterBlockLineState_Opcode:   .ds.w 1
    .even
    .endif




    .if !UNROLLED_CODE
;Generic code interpreting the RegisterBlock
;IN:    a1 = First byte.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYst_ReadRegisterBlock:
        readregs 0,0,1
    .endif

;Some stored PSG registers.
PLY_AKYst_PsgRegister6: dc.b 0
PLY_AKYst_PsgRegister11: dc.b 0
PLY_AKYst_PsgRegister12: dc.b 0
PLY_AKYst_PsgRegister13: dc.b 0

