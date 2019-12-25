/*
 * i2c.asm
 *
 *  Created: 10/31/2019 12:23:28 PM
 *   Author: n01283714
 */ 
.equ F_SCL		= 100000	; I2C speed 100 KHz
.equ TWISTART		= 0xA4		; Start (TWINT,TWSTA,TWEN)
.equ TWISTOP		= 0x94		; Stop (TWINT,TWSTO,TWEN)
.equ TWIACK		= 0xC4		; Return ACK to slave
.equ TWINACK		= 0x84		; Don't ACK slave
.equ TWISEND		= 0x84		; Send data (TWINT,TWEN)
.equ TWIREADY		= TWCR & 0x80	; Ready when TWINT returns 1
.equ TWISTATUS	= TWSR & 0xF8	; Returns value of status register
; I2C Initialization
; at 16 MHz, the SCL frequency will be 16/(16+2(TWBR)), assuming prescalar of 0.
; for 100KHz SCL, TWBR = ((F_CPU/F_SCL)-16)/2 = ((16/0.1)-16)/2 = 144/2 = 72.
i2cInit:
	ldi		r21,0
	sts		TWSR,r21		; set prescaler bits to 0
	ldi		r21,0x48		; 16 MHz CPU, 100 KHz TWI 72
	sts		TWBR,r21
	ldi		r21,(1<<TWEN)
	sts		TWCR,r21		; Enable TWI
	ret
; Looks for device at specfied address passed in r23                                                     
i2cDetect:
	ldi	r20,TWISTART		; Send Start
	sts	TWCR,r20
	ldi	r30,TWCR
	ldi	r31,0x00
dt1:
	ld	r20,Z
	and	r20,r20
	brge	dt1
	sts	TWDR,r23
	ldi	r24,TWISEND
	sts	TWCR,r24
	ldi	r30,TWCR
	ldi	r31,0x00
dt2:	
	ld	r24,Z
	and	r24,r24
	brge	dt2
	lds	r20,TWSR
	andi	r20,TWISTATUS
	ldi	r24,0x01
	cpi	r20,0x18
	breq	dt3
	ldi	r24,0
dt3:
	ret
; I2C Start Address in r23
i2cStart:
	call i2cDetect
	ret
; I2C Stop
i2cStop:
	ldi r24,TWISTOP
	sts TWCR,r24
	ret
; I2C Read
; Data returned in r27
i2cRead:
	ldi	r21,(1<<TWINT) | (1<<TWEN)
	sts	TWCR,r21
wait2:
	lds	r21,TWCR		; Read control register
	sbrs	r21,TWINT		; Wait until ready
	rjmp	wait2
	lds	r27,TWDR		; Read data
	ret

; reads data byte from slave into r24
i2cReadACK:
	ldi	r24,TWIACK	; ack = read more data
	sts	TWCR,r24
	ldi	r30,TWCR
	ldi	r31,0x00
ra1:
	ld	r24,Z
	and	r24,r24
	brge	ra1
	lds	r24,TWDR
	ret

; reads data byte from slave into r24
i2cReadNACK:
	ldi	r24,TWINACK	; nack = not reading more data
	sts	TWCR,r24
	ldi	r30,TWCR
	ldi	r31,0x00
rn1:
	ld	r24,Z
	and	r24,r24
	brge	rn1
	lds	r24,TWDR
	ret

; I2C Write
; Data to write in r24
i2cWrite:
	sts	TWDR,r24	; Load data into TWDR register
	ldi	r24,TWISEND
	sts	TWCR,r24	; Configure control register to send TWDR contents.
	ldi	r28,TWCR
	ldi	r29,0x00
wr1:
	ld	r24,Y
	and	r24,r24
	brge	wr1
	lds	r20,TWSR
	ldi	r24,0x01
	cpi	r20,0x26
	brne	wr2
	ldi	r24,0x00
wr2:
	ret
; I2C Write Register
; Bus Address in r23,Device Register in r25,Data in r22
i2cWriteRegister:
	call	i2cStart
	mov	r24,r25
	call	i2cWrite
	mov	r24,r22
	call	i2cWrite
	call	i2cStop
	ret

; I2C Read Register
; Bus address in r23, Device register in r25,
i2cReadRegister:
	mov	r22,r23
	call	i2cStart
	mov	r24,r25
	call	i2cWrite
	ldi	r23,0x01	; Restart as a READ operation
	add	r23,r22
	call	i2cStart
	call	i2cReadNACK
	mov	r22,r24
	call	i2cStop
	mov	r24,r22
	ret

; Write Multiple Bytes
; Bus Address in r23,Device Register in r25, Address Pointer r16,r17
i2cWriteMulti:
	call	i2cStart
	mov	r24,r25
	call	i2cWrite
	sbiw	r28,0x00
	breq	wm1
wm2:
	movw	r30,r16	; Set address in Z
	ld	r24,Z+		; Get data then increment Z
	movw	r16,r30	; Save Z register
	call	i2cWrite	; Write data
	sbiw	r28,0x01	; Decrement byte count
	brne	wm2		; loop if not done
wm1:
	call i2cStop
	ret