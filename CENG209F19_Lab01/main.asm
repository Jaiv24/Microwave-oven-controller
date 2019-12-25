;
; CENG209F19_Lab01.asm
;
; Created: 9/5/2019 11:59:24 AM
; Author : n01283714 (Jaivkumar Shah)
;
;
; CEN209L01.asm
;

; Constants
	.equ	CLOSED	= 0
	.equ	OPEN	= 1
	.equ	ON		= 1
	.equ	OFF		= 0
	.equ	YES		= 1
	.equ	NO		= 0
	.equ	JCTR	= 125	; Joystick centre value

; States
	.equ	STARTS		= 0
	.equ	IDLES		= 1
	.equ	DATAS		= 2
	.equ	COOKS		= 3
	.equ	SUSPENDS	= 4



; Port Pins
	.equ	LIGHT	= 7		; Door Light WHITE LED PORTD pin 7
	.equ	TTABLE	= 6		; Turntable PORTD pin 6 PWM
	.equ	BEEPER	= 5		; Beeper PORTD pin 5
	.equ	CANCEL	= 4		; Cancel switch PORTD pin 4
	.equ	DOOR	= 3		; Door latching switch PORTD pin 3
	.equ	STSP	= 2		; Start/Stop switch PORTD pin 2
	.equ	HEATER	= 0		; Heater RED LED PORTB pin 0

; Global variables
		.dseg

cstate:		.byte	1		; Current State
inputs: 		.byte	1		; Current input settings
joyx:			.byte	1		; Joystick x-axis
joyy:			.byte	1		; Joystick y-axis
joys:			.byte	1		; Joystick status 0 - not centred, 1 - centred.
seconds:		.byte	2		; Cook time in seconds 16-bit
sec1:			.byte	1		; minor tick time (100 ms)
tascii:		.byte	8		



	.cseg
	.org		0x0000
	jmp			start

;	Start after interrupt vector table
	.org	0xF6

	.include "iopins.asm"
	.include "util.asm"
	.include "serialio.asm"
	.include "adc.asm"
	.include "i2c.asm"
	.include "rtcds1307.asm"
	.include "andisplay.asm"


start:
	ldi			r16,HIGH(RAMEND)	; Initialize the stack pointer
	out			sph,r16
	ldi			r16,LOW(RAMEND)
	out			spl,r16
	call			initPorts
	call			initUSART0
	call			initADC
	call			i2cInit
	call			ds1307Init
	call			anInit
	jmp			startstate

	
	
; Main Control Loop
loop:	
	call			updateTick			;Check the time


;	If Door Open jump to suspend
	sbis			PIND,DOOR	
	jmp			suspend
	cbi			PORTD,LIGHT
	

;	Cancel Key Pressed
	sbic			PIND,CANCEL
	rjmp			l1
	sbi			PORTD,BEEPER
	jmp			idle

;	Start Stop Key Pressed 
l1:
	lds			r24, cstate
	sbic			PIND,STSP
	jmp			joy0
	sbi			PORTD,BEEPER
	cpi			r24,COOKS
	breq			suspend
	cpi			r24,IDLES
	breq			cook
	cpi			r24,SUSPENDS
	breq			cook
	cpi			r24,STARTS
	breq			cook


joy0:
	call			joystickinputs
	lds			r24,cstate
	cpi			r24,COOKS
	breq			loop
	cpi			r25,1
	breq			loop
	jmp			dataentry
	




idle:							; idle state tasks
	ldi		r24,IDLES			; Set state variable to Idle
	sts		cstate,r24			; Do idle state tasks
	cbi		PORTB,HEATER
	cbi		PORTD,LIGHT

	ldi		r16,0				;turning off the turntable
	out		OCR0A,r16

	ldi		r24,0
	sts		seconds,r24
	sts		seconds+1,r24
	jmp		loop


cook:							; cook state tasks
	ldi		r24,COOKS			; Set state variable to Cook
	sts		cstate,r24			; Do cook state tasks
	sbi		PORTB,HEATER
	cbi		PORTD,LIGHT

	ldi		r16,0x23			;turn turntable on
	out		OCR0A,r16

	jmp		loop

startstate:
	ldi		r24,STARTS			
	sts		cstate,r24			
	ldi		r24,0
	sts		sec1,r24

	sts		seconds+1,r24
	ldi		r24,0
	sts		seconds,r24

	cbi		PORTB,HEATER
	cbi		PORTD,LIGHT

	ldi		r16,0				;turn turntable off
	out		OCR0A,r16

	jmp		loop

suspend:						; suspend state tasks
	ldi		r24,SUSPENDS		; Set state variable to Suspend
	sts		cstate,r24			; Do suspend state tasks
	cbi		PORTB,HEATER
	sbi		PORTD,LIGHT

	ldi		r16,0				;turn off turntable
	out		OCR0A,r16

	jmp		loop


; Data Entry State
dataentry:						; data entry state tasks
	ldi		r24,DATAS			; Set state variable to Data Entry
	sts		cstate,r24

	cbi		PORTB,HEATER		;turn off heater
	cbi		PORTD,LIGHT			;turn off light

	ldi		r16,0				;turn off turntable
	out		OCR0A,r16

	lds		r26,seconds			; Get current cook time
	lds		r27,seconds+1
	lds		r21,joyx
	cpi		r21,135				; Check for time increment
	brsh		de1
	cpi		r27,0				; Check upper byte for 0
	brne		de0
	cpi		r26,0				; Check lower byte for 0
	breq		de2
de0:
	sbiw		r27:r26,10			; Decrement cook time by 10 seconds
	jmp		de2
de1:
	adiw		r27:r26,10			; Increment cook time by 10 seconds
de2:
	sts		seconds,r26			; Store time
	sts		seconds+1,r27
	call		displayState
	call		delay1s
	call		joystickInputs
	lds		r21,joys
	cpi		r21,0
	breq		dataentry			; Do data entry until joystick centred
	ldi		r24,SUSPENDS
	sts		cstate,r24
	jmp		loop




; Time Tasks
updateTick:
	call		delay100ms
	cbi		PORTD,BEEPER	; Turn off beeper
	lds		r22,sec1		; Get minor tick time
	cpi		r22,10			; 10 delays of 100 ms done?
	brne		ut2
	ldi		r22,0			; Reset minor tick
	sts		sec1,r22		; Do 1 second interval tasks

	lds		r23,cstate		; Get current state
	cpi		r23,COOKS
	brne		ut1
	lds		r26,seconds		; Get current cook time
	lds		r27,seconds+1
	inc		r26
	sbiw		r27:r26,1		; Decrement cook time by 1 second
	brne		ut3
	jmp		idle
ut3:
	sbiw		r27:r26,1		; Decrement/store cook time
	sts		seconds,r26
	sts		seconds+1,r27
ut1:
	call		displayState
ut2:
	lds		r22,sec1
	inc		r22
	sts		sec1,r22

; Save Most Significant 8 bits of Joystick X,Y
joystickInputs:
	ldi		r24,0x00		; Read ch 0 Joystick Y
	call		readADCch
	swap		r25
	lsl		r25
	lsl		r25
	lsr		r24
	lsr		r24
	or		r24,r25
	sts		joyy,r24
	ldi		r24,0x01		; Read ch 1 Joystick X
	call		readADCch
	swap		r25
	lsl		r25
	lsl		r25
	lsr		r24
	lsr		r24
	or		r24,r25
	sts		joyx,r24
	ldi		r25,0			; Not centred
	cpi		r24,115
	brlo		ncx
	cpi		r24,135
	brsh		ncx
	ldi		r25,1			; Centred
ncx:
	sts		joys,r25
ret
	

displayState:
	call		newline
	ldi		ZL,LOW(msg1<<1)
	ldi		ZH,HIGH(msg1<<1)
	ldi		r16,1
	call		putsUSART0

	call		displayTOD
	
	ldi		ZL,LOW(msg2<<1)
	ldi		ZH,HIGH(msg2<<1)
	ldi		r16,1
	call		putsUSART0

	call   	 displayCookTime

	
	ldi		ZL,LOW(msg3<<1)
	ldi		ZH,HIGH(msg3<<1)
	ldi		r16,1
	call		putsUSART0

	lds		r16,cstate
	ori		r16,0x30
	call		putchUSART0

	ret




displayTOD:

	ldi		r25,HOURS_REGISTER
	call		ds1307GetDateTime

	mov		r17, r24
	call		pBCDToASCII
	mov		r16,r17
	call		putchUSART0
	mov		r16,r18
	call		putchUSART0

	ldi		r16,':'
	call		putchUSART0

	ldi		r25,MINUTES_REGISTER
	call		ds1307GetDateTime

	mov		r17,r24
	call		pBCDToASCII
	mov		r16,r17
	call		putchUSART0
	mov		r16,r18
	call		putchUSART0

	lds		r24,cstate	;don't do TOD if in cooks
	cpi		r24,COOKS	;suspends or datas
	breq		return
	cpi		r24,SUSPENDS
	breq		return
	cpi		r24,DATAS
	breq		return

	;send to display
	ldi		r25,HOURS_REGISTER	;get hour time
	call		ds1307GetDateTime
	mov		r17,r24
	call		pBCDToASCII
	mov		r16,r17
	mov		r14,r18
	ldi		r17,0
	call		anWriteDigit
	mov		r16,r14
	ldi		r17,1
	call		anWriteDigit

	ldi		r25,MINUTES_REGISTER	;get minute time
	call		ds1307GetDateTime
	mov		r17,r24
	call		pBCDToASCII
	mov		r16,r17
	mov		r14,r18
	ldi		r17,2
	call		anWriteDigit
	mov		r16,r14
	ldi		r17,3
	call		anWriteDigit

return:
	ret

displayCookTime:

	lds		r16,seconds
	lds		r17,seconds+1
	call		itoa_short

	ldi		r24,0
	sts		tascii+5,r24
	sts		tascii+6,r24
	sts		tascii+7,r24

	ldi		ZL,LOW(tascii)
	ldi		ZH,HIGH(tascii)
	ldi		r16,0
	call		putsUSART0

	;only output to display if in COOKS,
	;SUSPENDS,DATAS
	lds		r24,cstate
	cpi		r24,COOKS
	breq		display
	cpi		r24,SUSPENDS
	breq		display
	cpi		r24,DATAS
	breq		display

	ret


	;send to display
display:
	lds		r16,seconds		;hold low-byte as divident
	lds		r17,seconds+1	;hold high-byte as divident
	ldi		r18,60			;divide by 60 (low byte)
	ldi		r19,0			;divide by 60 (high byte)
	call		div1616
	mov		r10,r0			;hold low-byte answer (mm)
	mov		r11,r2			;hold low-byte remainder (ss)

	mov		r16,r10			;dividing minutes
	ldi		r18,10			;by 10
	call		div88

	ldi		r16,'0'
	add		r16,r0
	ldi		r17,0
	call		anWriteDigit	;writing 10's minutes digit

	ldi		r16,'0'
	add		r16,r2
	ldi		r17,1
	call		anWriteDigit	;writing 1's minutes digit

	mov		r16,r11			;divide seconds
	ldi		r18,10			;by 10
	call		div88
	
	ldi		r16,'0'
	add		r16,r0
	ldi		r17,2
	call		anWriteDigit	;writing 10's seconds digit

	ldi		r16,'0'
	add		r16,r2
	ldi		r17,3
	call		anWriteDigit	;writing 1's seconds digit


	ret

;test message
msg1:	.db "Time: ",0,0
msg2:	.db " Cook Time: ",0,0
msg3:	.db " State: ",0,0
