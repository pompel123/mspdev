;*******************************************************************************
;   MSP430F21x2 Demo - ADC10, Sample A0, 1.5V, TA1 Trig, Set P1.0 if > 0.5V
;
;   Description: A0 is sampled 16/second (ACLK/2048) with reference to 1.5V.
;   Timer_A is run in upmode and TA1 is used to automatically trigger
;   ADC10 conversion, TA0 defines the period. Internal oscillator times sample
;   (16x) and conversion (13x). Inside ADC10_ISR if A0 > 0.5Vcc, P1.0 is set,
;   else reset. Normal mode is LPM3.
;   //* An external watch crystal on XIN XOUT is required for ACLK *//
;
;                MSP430F21x2
;             -----------------
;         /|\|              XIN|-
;          | |                 | 32kHz
;          --|RST          XOUT|-
;            |                 |
;        >---|P2.0/A0     P1.0 |--> LED
;
;  JL Bile
;  Texas Instruments Inc.
;  May 2008
;  Built Code Composer Essentials: v3 FET
;*******************************************************************************
 .cdecls C,LIST, "msp430x21x2.h"
;-------------------------------------------------------------------------------
 			.text							;Program Start
;-------------------------------------------------------------------------------
RESET       mov.w   #025Fh,SP   	        ; Initialize stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop WDT
SetupADC10  mov.w   #SHS_1+CONSEQ_2,&ADC10CTL1 ; TA1 trigger sample start
            mov.w   #SREF_1+ADC10SHT_2+REFON+ADC10ON+ADC10IE,&ADC10CTL0;
            mov.w   #30,&TACCR0             ; Delay to allow Ref to settle
            bis.w   #CCIE,&TACCTL0          ; Compare-mode interrupt.
            mov.w   #TACLR+MC_1+TASSEL_2,&TACTL; up mode, SMCLK
            bis.w   #LPM0+GIE,SR            ; Enter LPM0,enable interrupts
            bic.w   #CCIE,&TACCTL0          ; Disable timer interrupt
            bis.w   #ENC,&ADC10CTL0         ; ADC10 enable set
            bis.b   #001h,&ADC10AE0         ; P2.0 ADC10 option select
SetupP1     bis.b   #001h,&P1DIR            ; P1.0 output
SetupC0     mov.w   #2048-1,&TACCR0         ; PWM Period
SetupC1     mov.w   #OUTMOD_3,&TACCTL1      ; TACCR1 set/reset
            mov.w   #2047,&TACCR1           ; TACCR1 PWM Duty Cycle
SetupTA     mov.w   #TASSEL_1+MC_1,&TACTL   ; ACLK, up mode
                                            ;
Mainloop    bis.w   #LPM3+GIE,SR            ; Enter LPM3
            nop                             ; Required only for debugger
                                            ;
;-------------------------------------------------------------------------------
TA0_ISR;    ISR for TACCR0
;-------------------------------------------------------------------------------
            clr.w   &TACTL                  ; Clear Timer_A control registers
            bic.w   #LPM0,0(SP)             ; Exit LPM0 on reti
            reti                            ;
;-------------------------------------------------------------------------------
ADC10_ISR;
;-------------------------------------------------------------------------------
            bic.b   #01h,&P1OUT             ; P1.0 = 0
            cmp.w   #0155h,&ADC10MEM        ; ADC10MEM = A0 > 0.5V?
            jlo     ADC10_Exit              ; Again
            bis.b   #01h,&P1OUT             ; P1.0 = 1
ADC10_Exit  reti                            ;
                                            ;
;-------------------------------------------------------------------------------
;			Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".int05"            	; ADC10 Vector
            .short  ADC10_ISR
            .sect   ".int09"          		; Timer_A0 Vector *Check TimerA0
            .short  TA0_ISR
            .sect   ".reset"	            ; POR, ext. Reset
            .short  RESET
            .end

