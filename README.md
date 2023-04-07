# SerialVGA

<img src="SerialVGA-Front.png">

Serial VGA Module

Displays ~80x60 monochrome characters on a VGA monitor.  Max interface speed is ~1 MHz.  Includes PS/2 Keyboard/Mouse port and 3.5mm Audio jack with minimal circuitry.

Example code:

```
; 6502 Assembly Example when using 6522 VIA
; VCLK = PA0
; VDAT = PA1

via_pa		.EQU $BF01
via_da		.EQU $BF03

test
	JSR sendchar_init

	LDY #$84
	LDX #$04
	LDA #"A"
	JSR sendchar
inf
	JMP inf

; character to be sent is already in A
; and the address is located in X (lower) and Y (higher)
; thus, the letter A ($41 in ASCII) in the top-left corner would be
; Y = %10000000, X = %00000000, A = %01000001
; must have a 1 for the very highest address location, always.
; this assumes via has already been set up with PA0 and PA1 both output low.
sendchar
	PHA
	PHX
	TYA
	LDX #$08
sendchar_loop1
	JSR sendchar_bit
	DEX
	BNE sendchar_loop1
	PLA
	PHA
	LDX #$08
sendchar_loop2
	JSR sendchar_bit
	DEX
	BNE sendchar_loop2
	PLX
	PLA
	PHA
	PHX
	LDX #$08
sendchar_loop3
	JSR sendchar_bit
	DEX
	BNE sendchar_loop3
	PLX
	PLA
	RTS ; exit
sendchar_bit
	ROL A
	PHA
	LDA via_pa
	AND #%11111100
	BCC sendchar_toggle
	ORA #%00000010
sendchar_toggle
	STA via_pa
	INC A
	STA via_pa
	DEC A
	STA via_pa
	PLA
	RTS
sendchar_init ; initializes via
	PHA
	LDA via_da
	ORA #%00000011
	STA via_da
	LDA via_pa
	AND #%11111100
	STA via_pa
	PLA
	RTS
```
