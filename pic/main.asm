	include	p16f54.inc
	processor	p16f54
	radix	dec
	extern	isr

	#define DOUT 7
	#define DIN1 8;data in regs need to be in successive order
	#define DIN2 9
	#define DIN3 10
	#define TRH  11
	#define TRL  12

	#define A    15
	#define Y    16
	#define X    17
	#define DH   18
	#define DL   19
	#define PCH  20
	#define EPCL 21
	#define SPH  22
	#define SPL  23
	#define PS   24

	code

q1:
	movf DIN1,w
	addwf PCL,f
	goto endcyc
	goto lda_d
	goto sta_d
	goto tbd
	goto tdb
	goto txa
	goto tax
	goto tya
	goto tay
	goto tbs
	goto ina
	goto ind
	goto dea
	goto ded
	goto rts
	goto sec
	goto clc
	goto ror
	goto rol
	goto pha
	goto pla
	goto phb
	goto plb
	goto phd
	goto pld
	goto lsr
	goto asl

q2:
	bcf DIN1,6
	movf DIN1,w
	addwf PCL,f
	goto lda_imm
	goto cmp
	goto and
	goto adc
	goto sbc
	goto ora
	goto eor

q3:
	bcf DIN1,7
	movf DIN1,w
	addwf PCL,f
	goto bcc
	goto bcs
	goto bmi
	goto bpl
	goto bne
	goto beq

q4:
	bcf DIN1,7
	bcf DIN1,6
	movf DIN1,w
	addwf PCL,f
	goto jmp
	goto jsr
	goto ldb_imm
	goto ldd_imm
	goto jmp_ind

q12:
	btfsc DIN1, 6
	goto q2
	goto q1

init:
	movlw 0
	option
	tris PORTA;port a is used for output-only stuff
	movlw h'FF'
	tris PORTB;port b is the address and data bus, that is set to input (tri-state) by defauft
	
	clrf EPCL
	clrf PCH
	clrf PORTA
	clrf PORTB

cpuloop:;this is where a cycle starts
	clrf TRH
	
	movlw DIN1
	movwf FSR; we will use indirect addressing to get the opcode
	
	;fetch data
	call fetch_noinc
	
	;test bits in data
	btfsc DIN1, 7
	call fetch
	btfsc DIN1, 6
	call fetch
	
	;instruction processing here
	btfss DIN1, 7
	goto q12
	btfss DIN1, 6
	goto q3
	goto q4

endcycfl:;this is where a cycle ends for an instruction that updates the flag register
	call flags
	
endcyc:;this is where a cycle ends for the other instructions
	call incpc
	goto cpuloop

branch_op:
	btfsc DIN2, 7
	goto br_dec_pc
	movf DIN2, w
	addwf EPCL, f
	btfsc STATUS, C
	incf PCH, f
	goto endcyc
br_dec_pc:
	movlw 255
	xorwf DIN2,f
	incf DIN2,w
	subwf EPCL, f
	btfsc STATUS, C
	decf PCH, f
	goto endcyc

; cpu operations

fetch:
	call incpc
fetch_noinc:
	call latchpc

	bsf PORTA,3 ;mreq set
	movf PORTB,w
	bcf PORTA,3 ;mreq clear
	movwf INDF     ;store
	incf FSR, f
	retlw 0

flags:
	;reset flags
	clrf PS
	;update carry flag from pic
	btfsc STATUS, C
	bsf PS, 0
	;set negative flag
	btfsc TRL, 7
	bsf PS, 2
	;set zero flag
	incf TRH, f;test trh
	decfsz TRH, f
	retlw 0
	incf TRL, f;test trl
	decfsz TRL, f
	retlw 0
	bsf PS, 1
	retlw 0

latch_indf:
	;put two bytes pointed by FSR in latches
	
	clrw
	tris PORTB

	movf INDF,w    ;high
	movwf PORTB
	bsf PORTA,1
	bcf PORTA,1
	
	incf FSR
	
	movf INDF,w    ;low
	movwf PORTB
	bsf PORTA,0
	bcf PORTA,0

	movlw h'FF'
	tris PORTB
	
	retlw 0
	
latchpc:
	;put program counter in latches
	
	clrw
	tris PORTB

	movf PCH,w    ;high
	movwf PORTB
	bsf PORTA,1
	bcf PORTA,1

	movf EPCL,w    ;low
	movwf PORTB
	bsf PORTA,0
	bcf PORTA,0

	movlw h'FF'
	tris PORTB
	retlw 0

latchsp:
	;put stack pointer in latches
	movlw SPH
	movwf FSR
	call latch_indf
	
	retlw 0

latchd:
	;put reg d in latches
	movlw DH
	movwf FSR
	call latch_indf
	
	retlw 0

latch_din:
	;put data input in latches
	movlw DIN2
	movwf FSR
	call latch_indf
	
	retlw 0

decsp:
	decf SPL, f
	incfsz SPL, f
	decf SPH, f
	decf SPL, f
	retlw 0

incsp:
	incfsz SPL,f
	retlw 0
	incf SPH,f
	retlw 0

incpc:
	;increment program counter
	incfsz EPCL,f
	retlw 0
	incf PCH,f
	retlw 0

dout:;write data on bus
	bsf PORTA, 2;set rw to write
	movf DOUT, w
	movwf PORTB
	clrw
	tris PORTB
	bsf PORTA, 3;mreq set
	bcf PORTA, 3;mreq clear
	movlw h'FF'
	tris PORTB
	bcf PORTA, 2;set rw to read
	retlw 0;

;instructions here

pha:
	call latchsp
	movf A, w
	movwf DOUT
	call dout
	call decsp
	goto endcyc

pla:
	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf A     ;store
	movwf TRL
	bcf PORTA,3 ;mreq clear
	goto endcycfl

phb:
	call latchsp
	movf Y, w
	movwf DOUT
	call dout
	call decsp

	call latchsp
	movf X, w
	movwf DOUT
	call dout
	call decsp
	goto endcyc

plb:
	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf Y     ;store
	movwf TRH
	bcf PORTA,3 ;mreq clear

	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf X     ;store
	movwf TRL
	bcf PORTA,3 ;mreq clear
	goto endcycfl

phd:
	call latchsp
	movf DH, w
	movwf DOUT
	call dout
	call decsp

	call latchsp
	movf DL, w
	movwf DOUT
	call dout
	call decsp
	goto endcyc

pld:
	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf DH     ;store
	movwf TRH
	bcf PORTA,3 ;mreq clear

	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf DL     ;store
	movwf TRL
	bcf PORTA,3 ;mreq clear
	goto endcycfl

jmp_ind:;update pc and end cycle
	call latch_din

	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf EPCL     ;store
	bcf PORTA,3 ;mreq clear

	incfsz DIN3,f
	goto jmpind_next
	incf DIN2,f
jmpind_next:
	call latch_din
	
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf PCH     ;store
	bcf PORTA,3 ;mreq clear

	goto cpuloop

jmp:;update pc and end cycle
	movf DIN2, w
	movwf PCH
	movf DIN3, w
	movwf EPCL
	goto cpuloop
jsr:;push registers, update pc and end cycle
	call latchsp
	movf PCH, w
	movwf DOUT
	call dout
	call decsp
	call latchsp
	movf EPCL, w
	movwf DOUT
	call dout
	call decsp
	call latchsp
	movf PS, w
	movwf DOUT
	call dout
	call decsp
	goto jmp

bcc:
	btfss PS,0
	goto branch_op
	goto endcyc
bcs:
	btfsc PS,0
	goto branch_op
	goto endcyc

bne:
	btfss PS,1
	goto branch_op
	goto endcyc
beq:
	btfsc PS,1
	goto branch_op
	goto endcyc

bpl:
	btfss PS,2
	goto branch_op
	goto endcyc
bmi:
	btfsc PS,2
	goto branch_op
	goto endcyc

lda_imm:
	movf DIN2, w
	movwf TRL
	movwf A
	goto endcycfl

ldb_imm:
	movf DIN2, w
	movwf TRH
	movwf Y
	movf DIN3, w
	movwf TRL
	movwf X
	goto endcycfl

ldd_imm:
	movf DIN2, w
	movwf TRH
	movwf DH
	movf DIN3, w
	movwf TRL
	movwf DL
	goto endcycfl

lda_d:
	call latchd
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf TRL
	movwf A     ;store
	bcf PORTA,3 ;mreq clear
	goto endcycfl

sta_d:
	call latchd
	movf A,w
	movwf DOUT
	call dout
	goto endcyc

sec:
	bsf PS,0
	goto endcyc

clc:
	bcf PS,0
	goto endcyc

rts:
	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf PS     ;store
	bcf PORTA,3 ;mreq clear
	
	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf EPCL     ;store
	bcf PORTA,3 ;mreq clear
	
	call incsp
	call latchsp
	bsf PORTA,3 ;mreq set
	movf PORTB,w
	movwf PCH     ;store
	bcf PORTA,3 ;mreq clear
	goto cpuloop

tbd:
	movf X,w
	movwf DL
	movf Y,w
	movwf DH
	goto endcyc

tdb:
	movf DL,w
	movwf X
	movf DH,w
	movwf Y
	goto endcyc

tbs:
	movf X,w
	movwf SPL
	movf Y,w
	movwf SPH
	goto endcyc

txa:
	movf X,w
	movwf A
	goto endcyc

tax:
	movf A,w
	movwf X
	goto endcyc

tya:
	movf Y,w
	movwf A
	goto endcyc

tay:
	movf A,w
	movwf Y
	goto endcyc

ina:
	incf A,f
	movf A,w
	movwf TRL
	goto endcycfl

dea:
	decf A, f
	movf A,w
	movwf TRL
	goto endcycfl

ind:
	incfsz SPL,f
	goto endind
	incf SPH,f
endind:
	movf DL,w
	movwf TRL
	movf DH,w
	movwf TRH
	goto endcycfl

ded:
	decf DL, f
	incfsz DL, f
	decf DH, f
	decf DL, f
endded:
	movf DL,w
	movwf TRL
	movf DH,w
	movwf TRH
	goto endcycfl

cmp:
	movf DIN2,w
	andwf A, w
	movwf TRL
	goto endcycfl

and:
	movf DIN2,w
	andwf A, f
	movf A, w
	movwf TRL
	goto endcycfl

ora:
	movf DIN2,w
	iorwf A, f
	movf A, w
	movwf TRL
	goto endcycfl

eor:
	movf DIN2,w
	xorwf A, f
	movf A, w
	movwf TRL
	goto endcycfl

ror:
	btfsc PS,0
	bsf STATUS,0
	btfss PS,0
	bcf STATUS,0
	rrf A, f
	movf A, w
	movwf TRL
	goto endcycfl

rol:
	btfsc PS,0
	bsf STATUS,0
	btfss PS,0
	bcf STATUS,0
	rlf A, f
	movf A, w
	movwf TRL
	goto endcycfl

lsr:
	bcf STATUS,0
	rrf A, f
	movf A, w
	movwf TRL
	goto endcycfl

asl:
	bcf STATUS,0
	rlf A, f
	movf A, w
	movwf TRL
	goto endcycfl

adc:
	movf DIN2,w
	addwf A, f
	btfsc PS,0
	goto adc_carry
adc_cont:
	movf A, w
	movwf TRL
	goto endcycfl
adc_carry:
	movlw 1
	addwf A, f
	goto adc_cont

sbc:
	movf DIN2,w
	subwf A, f
	btfsc PS,0
	goto sbc_carry
sbc_cont:
	movf A, w
	movwf TRL
	goto endcycfl
sbc_carry:
	movlw 1
	subwf A, f
	goto sbc_cont



; reset vector
	org h'0'; reset, it's at 1FF on 16F54 but the convention is to let the PC roll over to 0
	goto init

	end
