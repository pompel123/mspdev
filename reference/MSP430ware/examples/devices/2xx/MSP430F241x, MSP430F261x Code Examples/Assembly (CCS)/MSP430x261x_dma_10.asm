;*******************************************************************************
;  MSP430x261x Demo - DMA0, ADC12 A10 rpt single transfer Xfer to Flash, TBCCR1, DCO
;
;  Description: A 0x20 word block of data is sampled and recorded into Flash
;  memory starting at address 010000h from ADC12 channel 10 (integr. temp sens)
;  Timer_B CCR1 begins the ADC12 sample period, CCR0 the hold
;  and conversion start. Timer_B operates in the up mode with CCR0 defining the
;  sample period. DMA0 will automatically transfer each ADC12 conversion code
;  to memory when complete. At the end of the recording block, DMA0 will issue
;  an interrupt existing the function.
;  In this example the ADC12 sample period is 100 SMCLK cycle, and Flash
;  programming requires 70 cycles.
;  In the example the Flash block use to record the ADC12 data begins at 0x2200.
;  P1.0 is toggled during DMA transfer only for demonstration purposes.
;  ACLK = 32kHz, MCLK = SMCLK = default DCO 1048576Hz
;  //* Set Breakpoint on NOP in the Mainloop to avoid Stressing Flash *//
;
;              MSP430x2619
;            -----------------
;        /|\|              XIN|-
;         | |                 | 32Khz
;         --|RST          XOUT|-
;           |                 |
;           |             P1.0|-->LED
;
;  JL Bile
;  Texas Instruments Inc.
;  June 2008
;  Built Code Composer Essentials: v3 FET
;*******************************************************************************
 .cdecls C,LIST, "msp430x26x.h"
;-------------------------------------------------------------------------------
			.text	;Program Start
;-------------------------------------------------------------------------------
RESET       mov.w   #0850h,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop watchdog timer
            mov.w   #FWKEY+FSSEL_2+FN1,&FCTL2 ; Clk src = SMCLK / 3 (~333KHz)
SetupP5     bis.b   #BIT0,&P1DIR             ; Set P1.0 to output direction
Mainloop    calla   #Record
            nop                             ; Needed only for debugger
            jmp     Mainloop

Record      mov.w   #FWKEY+ERASE,&FCTL1     ; Erase bit = 1
Erase_SegA  mov.w   #FWKEY,&FCTL3           ; Lock = 0
            clrx.a  &010000h                ; Dummy write to erase Flash segment
            mov.b   #SREF_1+INCH_10,&ADC12MCTL0 ; Channel A10, Vref+
            clr.w   &ADC12IFG
            mov.w   #SHS_3+CONSEQ_2,&ADC12CTL1 ; S&H TB.OUT1, rep. single chan
            mov.w   #REF2_5V+REFON+ADC12ON+ENC,&ADC12CTL0 ; VRef ADC12 on, enabl
            mov.w   #03600h,R15             ; Delay for needed ref start-up.
RefDelay    dec.w   R15                     ; See datasheet for details
            jnz     RefDelay                ;
            mov.w   #100,&TBCCR0            ; Init TBCCR0 w/ sample prd
            mov.w   #70,&TBCCR1             ; Trigger for ADC12 SC
            mov.w   #OUTMOD_7,&TBCCTL1      ; Reset OUT1 on EQU1, set on EQU0
SetupDMAx   movx.a  #ADC12MEM0,&DMA0SA     ; Src address = ADC12 module
            movx.a  #010000h,&DMA0DA       ; Dst address = Flash @ 010000h
            mov.w   #020h,&DMA0SZ           ; Size in words
            mov.w   #DMA0TSEL_6,&DMACTL0    ; ADC12IFGx triggers DMA0
            mov.w   #DMAONFETCH,&DMACTL1    ; Required for proper Flash Write
            mov.w   #DMADSTINCR_3+DMAIE+DMAEN,&DMA0CTL; Config
            bis.b   #BIT0,&P1OUT             ; Start recording and enter LPM0
            mov.w   #TBSSEL_2+MC_1+TBCLR,&TBCTL ;SMCLK, clear TBR, up mode
            mov.w   #FWKEY+WRT,&FCTL1       ; Write bit = 1
            bis.w   #CPUOFF+GIE,SR          ; Enter LPM0, enable interrupts
            mov.w   #FWKEY,&FCTL1           ; Write bit = 0
            mov.w   #FWKEY+LOCK,&FCTL3      ; Lock = 1
            bic.w   #CONSEQ_2,&ADC12CTL1    ; Stop conversion immediately
            bic.w   #ENC,&ADC12CTL0         ; Disable ADC12 conversion
            clr.w   &ADC12CTL0              ; Switch off ADC12 & ref voltage
            clr.w   &TBCTL                  ; Disable Timer_B
            bic.b   #BIT0,&P1OUT             ; Clear P1.0 (LED Off)
            reta
;------------------------------------------------------------------------------
DMA_ISR;    Common ISR for DMA/DAC12
;------------------------------------------------------------------------------
            bic.w   #DMAIFG,&DMA0CTL        ; Clear DMA0 interrupt flag
            bic.w   #LPM0,0(SP)             ; Exit LPMx, interrupts enabled
            reti                            ;
;-------------------------------------------------------------------------------
;			Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect     ".int15"              ; DMA Vector
            .short   DMA_ISR                 ;
            .sect    ".reset"            ; POR, ext. Reset
            .short   RESET
            .end
            