;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;	Title:		Door Chime Tone
;	Author:		Sashen Govender
;	Date:		01 October 2012
;	Version:		1.0
;	File Name:		210513093P4.asm

;------------------------------------------------------------------------------------------------------------
;*********************Overview*********************Overview*********************Overview*********************
;------------------------------------------------------------------------------------------------------------
;	This program generates a 7 second door chime that is played into a speaker. The frequency of the
;	chime ranges from 3000Hz to 3910Hz. This 7 second chime is made up of 3 tones that last for either 1
;	second or 2 seconds depending on the tone played. The chime is generated using PICs PWM channel and
;	is played to a speaker when the push button is pressed. Once the push button is pressed and the
;	chime begins, the push button is then disabled. It is only re-enabled when the chime has finished.

;------------------------------------------------------------------------------------------------------------
;*****************Tone Sequence*****************Tone Sequence*****************Tone Sequence******************
;------------------------------------------------------------------------------------------------------------
;	The 7 second tone is generated by playing 3 tones in a specific sequence. The sequence is as follows:
;	Low->Middle->High->Middle->High. These tone frequencies can be changed by simply changing the
;	appropriate tone variable in this program. The first (Low_tone=3910Hz) and second (Middle_tone=3400hz)
;	tones last for 1 second, while the third tone (high_tone=3000HZ) lasts for 2 seconds.
;
;------------------------------------------------------------------------------------------------------------
;************Tone Implementation*************Tone Implementation*************Tone Implementation*************
;------------------------------------------------------------------------------------------------------------
;	Two interrupts were used to develop this program. An external Interrupt process the push of the
;	button, while a Timer1 overflow interrupt was used to change the frequency of the tone. I created
;	this program such that it is not possible for both interrupts to occur at the same time. First an
;	external interrupt occurs which then enables the timer1 overflow interrupt and disables any further
;	external interrupts until the chime has been completed. The tone played, depends on the ToneSelect
;	register. This register is like a flag register, which indicates which tone to play. This register is
;	summarized as follows:
;
;	bit0
;		1	=	enable middle tone
;		0	=	disable middle tone
;	bit1
;		1	=	enable high tone
;		0	=	disable high tone
;	bit2
;		1	=	repeat middle and high tone
;		0	=	end chime

;	bit3 - bit7:		unimplemented bits
;
;	The signal produced by the PWM channel is a square wave with a 50% duty cycle. A clock frequency of
;	1 MHz was chosen in order to obtain a 1 and 2 second "delay". A higher clock frequency such as 20 MHz
;	would not obtain the required delay.

;------------------------------------------------------------------------------------------------------------
;*****************Important Info****************Important Info****************Important Info*****************
;------------------------------------------------------------------------------------------------------------
;	Files required:		None
;	Clock Speed:			1 MHz
;	Microchip:			PIC16F690
;	Macros:			None
;	Interrupts:			Timer1 Overflow, External interrupt 
;	Timer usage:			Timer1, Timer2 (for PWM)
;	Reminder:			The value in the PR2 register creates a specific PWM period 
;
;	Code Performance Figures:
;	-------------------------
;	Program memory:		123
;	Max Stack Depth:		2

;------------------------------------------------------------------------------------------------------------
;***************Pin Connections****************Pin Connections****************Pin Connections****************
;------------------------------------------------------------------------------------------------------------
;	Pin 1 (Vdd):			Vdd = 5V 
;	Pin 5 (CCP1):			PWM output pin
;	Pin 17 (RA2):			push button input pin
;	Pin 20 (Vss):			Vss = 0V

;------------------------------------------------------------------------------------------------------------
;***********Configuration Section***********Configuration Section***********Configuration Section************
;------------------------------------------------------------------------------------------------------------

list p=16F690
#include <p16f690.inc>

__CONFIG _CP_OFF & _CPD_OFF & _BOR_OFF & _MCLRE_ON & _WDT_OFF & _PWRTE_ON &_INTRC_OSC_NOCLKOUT & _FCMEN_OFF & _IESO_OFF

cblock 0x70

	ToneSelect						; indicates which tone to play and whether or not the 
								; tone should repeat or end
	W_Save						; save the W Reg while in the ISR
	STATUS_Save						; save the Status Reg while in the ISR
endc

;	Constant definitions
	PWM_Output 		equ 	TRISC			; port 	
	PWM_Output_bit 	equ 	5			; and bit for the PWM output signal
	Push_Button 		equ 	TRISA			; port 
	Push_Button_bit	equ 	2			; and bit for the Push button input
	Low_Tone		equ	3			; PR2 values for a specific frequency
	Middle_Tone 		equ	4
	High_Tone 		equ	5

org 0x00
		goto Initialise

org 0x04
		goto ISR

;------------------------------------------------------------------------------------------------------------
;*********************Intialise********************Intialise********************Intialise********************
;------------------------------------------------------------------------------------------------------------
;	Code to setup the:	clock frequency
;					External Interrupt
;					input and output pins
;					Make input pins digital

Initialise:
		
		call	setClockFreq			; set clock frequency to 1 MHz

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
		bcf	PWM_Output,PWM_Output_bit		; PWM output pin
		bsf	Push_Button,Push_Button_bit	; RA2 used as input for the push button

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
		bcf 	OPTION_REG, INTEDG			; external interrupt on Falling edge

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
		bcf	INTCON,INTF
		bsf	INTCON,INTE				; enable external interrupt
		bsf	INTCON,GIE
		bsf	INTCON,PEIE				; enable peripheral interrupt (Timer1)

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;	Make all inputs digital 

		banksel 	ANSEL
		clrf 	ANSEL
		clrf 	ANSELH

;------------------------------------------------------------------------------------------------------------
;************************Main************************Main************************Main************************
;------------------------------------------------------------------------------------------------------------
;	Infinite loop waiting for interrupts to occur

Main:
		banksel 	INTCON
		bcf 	INTCON,INTF	
		goto 	Main

;------------------------------------------------------------------------------------------------------------
;*************************ISR*************************ISR*************************ISR************************
;------------------------------------------------------------------------------------------------------------
ISR:
;	Save W and Status registers

		movwf 	W_Save
		movf 	STATUS,W
		movwf 	STATUS_Save

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
		banksel 	INTCON
		btfsc 	INTCON,INTF			; check if an external interrupt had occurred
		goto 	External_ISR
		banksel 	PIR1
		btfsc 	PIR1,TMR1IF			; check if Timer1 interrupt had occurred
		goto 	Timer1_ISR
		goto 	End_ISR

;------------------------------------------------------------------------------------------------------------
;******************External_ISR******************External_ISR******************External_ISR******************
;------------------------------------------------------------------------------------------------------------
;	An external interrupt occurs when the push button has been pressed.
;	This Routine setups the PWM channel and plays the first tone out of the 3 tones to be played. It also
;	setups timer1 with a 1 second overflow interrupt and disable any further external interrupts until
;	the chime has finished.

External_ISR:

		bcf	INTCON,INTF			; clear the Timer1 overflow flag bit
		bcf	INTCON,INTE			; disable external interrupts
		call	Config_PWM
		movlw	Low_Tone
		call	Update_PWM_Freq		; play the first low tone
		call	Config_Timer1		; setup timer1 
		banksel	T1CON
		bsf	T1CON,TMR1ON		; start timer1 (start counting until 1 second is over)
		clrf	ToneSelect
		bsf	ToneSelect,0		; set middle tone to play on the next timer1 overflow interrupt

;------------------------------------------------------------------------------------------------------------
;**********************End_ISR;**********************End_ISR;**********************End_ISR*******************
;------------------------------------------------------------------------------------------------------------

End_ISR:

;	Load the original value of the STATUS and W registers
		movf	STATUS_Save,W
		movwf	STATUS
		swapf	W_Save,F
		swapf	W_Save,W
		retfie

;------------------------------------------------------------------------------------------------------------
;*******************Timer1_ISR*******************Timer1_ISR*******************Timer1_ISR*********************
;------------------------------------------------------------------------------------------------------------
;	This interrupt occurs every 1 or 2 seconds depending on the tone been played. This ISR plays the middle
;	and high tone. When the full chime has been played the following occurs:
;	The PWM channel is disable, Timer1 count is stopped, preventing any further timer1 overflows and the
;	external interrupt is re-enabled

Timer1_ISR:

		bcf	PIR1,TMR1IF
		btfsc	ToneSelect,0
		goto	MiddleTone			; play 1 second middle tone
		btfsc	ToneSelect,1
		goto	HighTone			; play 2 second high tone
		btfsc	ToneSelect,2
		goto	EndTone			; end tone sequence
		goto	Repeat			; Repeat middle and High tone
			
;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;	Play the Middle Tone for approximately 1 second

MiddleTone:
				
		movlw	Middle_Tone
		call	Update_PWM_Freq		; play the middle tone
		call	Config_Timer1		; configure timer1 for a 1 second overflow interrupt
		banksel	T1CON
		bsf	T1CON,TMR1ON		; start timer1
		bcf	ToneSelect,0		; disable the middle tone on next timer1 overflow
		bsf	ToneSelect,1		; play the high tone on the next timer1 overflow
		goto	End_ISR

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;	Play the High Tone for approximatly 2 second

HighTone:

		movlw	High_Tone
		call	Update_PWM_Freq		; play the high tone
		call	TwoSecTimer1		; configure timer1 for a 2 second overflow interrupt
		bsf	T1CON,TMR1ON		; start timer1
		bcf	ToneSelect,1		; disable the high tone on next timer1 overflow
		goto	End_ISR

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;	Repeat the Middle and High tones then end the chime.

Repeat:
		bsf	ToneSelect,2		; end sequence enabled
		goto	MiddleTone

;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;	End the Chime by disabling the PWM Module and re-enabling external interrupts

EndTone:

		banksel	CCP1CON
		clrf	CCP1CON			; disable PWM
		bcf	T1CON,TMR1ON		; stop timer1
		bcf	INTCON,INTF			; clear external flag bit (Which may have been set when the
							; chime was playing)
		bsf	INTCON,INTE			; enable external interrupts
		goto	End_ISR

;------------------------------------------------------------------------------------------------------------
;*******************setClockFreq******************setClockFreq******************setClockFreq*****************
;------------------------------------------------------------------------------------------------------------
;	set clock Frequency to 1 MHz

setClockFreq:

		banksel	OSCCON
		movlw	b'01000101'
							; Bit6-4:	110	=>	1 MHz
							; Bit3:		0	=>	Internal Oscillator
							; Bit2:		1	=>	High Frequency Stable (enabled)
							; Bit0:		1	=>	Internal Oscillator for system 							;				clock
		movwf	OSCCON
		return

;------------------------------------------------------------------------------------------------------------
;*****************TwoSecTimer1*****************TwoSecTimer1*****************TwoSecTimer1*********************
;------------------------------------------------------------------------------------------------------------
;	Configure Timer1 for a 1 second "delay"

TwoSecTimer1:

		banksel	T1CON
		movlw	b'00110000'
							; Bit5-4:	11	=>	Prescaler 1:8
							; Bit1:		0	=>	Internal Clock
							; Bit0:		0	=>	Stop Timer1
		movwf	T1CON
		movlw	0x0B			; High byte
		movwf	TMR1H
		movlw	0xDC			; Low byte
		movwf	TMR1L
		return

;------------------------------------------------------------------------------------------------------------
;****************Update_PWM_Freq****************Update_PWM_Freq***************Update_PWM_Freq****************
;------------------------------------------------------------------------------------------------------------
;	Description: Generate a new PWM frequency at 50% duty cycle
;
;	No. of Instructions:	8 (call + return)
;	Registers used :		W, PR2, CCPR1L
;	Execution Time :		12uS 
;	Stack Depth :			1
;	Flags Used :			C
;	Input :			The new PR2 value must be in the W register
;	Output :			updates the PWM Frequency
;------------------------------------------------------------------------------------------------------------

Update_PWM_Freq:

		banksel	PR2
		movwf	PR2
		bcf	STATUS,C
		rrf	PR2,W			;load half of the PR2 value into CCPR1L to get a 50% duty cycle
		banksel	CCPR1L
		movwf	CCPR1L
		return
;------------------------------------------------------------------------------------------------------------
; *****************Config_Timer1*****************Config_Timer1*****************Config_Timer1*****************
;------------------------------------------------------------------------------------------------------------
;	Setup timer1 with a 2 second overflow

Config_Timer1:

		banksel	T1CON
		movlw	b'00110000'
							; Bit5-4:	11	=>	Prescaler 1:8
							; Bit1:		0	=>	Internal Clock
							; Bit0:		0	=>	Stop Timer1
		movwf	T1CON
		movlw	0x85
		movwf	TMR1H
		movlw	0xEE
		movwf	TMR1L
		bcf	PIR1,TMR1IF			;clear overflow flag bit
		banksel	PIE1
		bsf	PIE1,TMR1IE			;timer1 overflow interrupt
		return
;------------------------------------------------------------------------------------------------------------
; *******************Config_PWM1*******************Config_PWM*******************Config_PWM*******************
;------------------------------------------------------------------------------------------------------------
;	Setup the PWM module

Config_PWM:

		banksel	CCP1CON
		movlw	b'00001100'
							; Bit7-6:	00	=>	single output
							; Bit3-0:	1100	=>	PWM Mode P1A active-high
		movwf	CCP1CON
		bsf	T2CON, T2CKPS1		; T2CKPS:	11	=>	Prescaler 16
		bsf	T2CON, T2CKPS0
		bsf	T2CON, TMR2ON		; set Timer2 on
		clrf	TMR2
		return

end
