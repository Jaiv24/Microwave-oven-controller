/*
 * iopins.asm
 *
 *  Created: 9/12/2019 12:04:56 PM
 *   Author: n01283714
 */ 
; Port Initialization
initPorts:
	in		r24,DDRD		; Get the contents of DDRD
	ori		r24,0b11100000	; Set Port D pins 5,6,7 to outputs
	out		DDRD,r24
	in		r24,DDRB		; Get the contents of DDRB
	ori		r24,0b00000011	; Set Port B pins 0,1 to output
	out		DDRB,r24
	in		r24,DDRD
	andi	r24,0b11100011	; Set Port D pins 2,3,4 to inputs
	out		DDRD,r24
	in		r24,PORTD		; Pull pins 2,3,4 high
	ori		r24,0b00011100
	out		PORTD,r24
	; Timer0 PWM Setup
	; TCCR0A - Timer/Counter Control Register A
	; Phase Correct PWM = WGM02-0,WGM01-0,WGM00 1, PWM TOP - 0xFF, Updates OCRx at TOP, TOV flag Set on Bottom
	; Compare Output Mode = COM0A1-1,COM0A0-0
	ldi	r16,(1<<COM0A1) |(1<<WGM00) 
	out	TCCR0A,r16 ; to timer control port A

	; TCCCR0B - Timer/Counter Control Register B
	; Prescaler = 1024 - CS02-1,CS01-0,CS00-1, Frequency 61 Hz - 16 mHz/1024/256
	ldi	r16,(1<<CS02) | (1<<CS00) 
	out	TCCR0B,r16
	ldi	r16,0				; Load 0 count to initially turn off turntable
	out	OCR0A,r16

	ret
