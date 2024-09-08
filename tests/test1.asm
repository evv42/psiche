	.org 0

start:
	clc
	lda #$FF
loop:
	nop
	ldb $8000
	tbd
	eor #$FF
	stad
	jmp loop
