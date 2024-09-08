	.org 0

start:
	NOP
	LDD $8000
	EOR #$FF
	STAD
	JMP start
