; Testing Code for the SDcard

; First, plug in the Micro SDcard through a USB adapter.

; Second, run 
; sudo fdisk -l
; to see what drive it is on.  Let's assume /dev/sdd for this one.

; Third, run
; ~/dev65/bin/as65 SDcardCode.asm ; ./Parser.o SDcardCode.lst SDcardCode.bin 1024 0 1024 0
; which compiles the assembly code, this creates a 1K file, can of course go larger

; Fourth, run
; sudo dd if=SDcardCode.bin of=/dev/sdd bs=1M conv=fsync

; Then just pull out the SDcard and pop it into the Acolyte Computer!

	.65C02

; Assembly Example when connecting
; VCLK = PA0
; VDAT = PA1
; KCLK = CA1
; KDAT = PA7
; AUD = PB7

via		.EQU $BF00
via_pb		.EQU $BF00
via_pa		.EQU $BF01
via_db		.EQU $BF02
via_da		.EQU $BF03
via_pcr		.EQU $BF0C
via_ifr		.EQU $BF0D
via_ier		.EQU $BF0E

key_array		.EQU $0200
key_write		.EQU $0300
key_read		.EQU $0301
key_data		.EQU $0302
key_counter		.EQU $0303


	.ORG $0400 ; this is the actual memory location it starts but the SDcard would start at $0000

	PHA
	PHX

	JMP code

pos
	.BYTE $82,$01 ; Y, X positions
key_complete
	.BYTE $00 ; used in keyboard interrupt

code	
	LDA #"*"
	JSR $0360 ; printchar subroutine

	SEI

	LDA $0357 		; disable banked RAM, enable I/O devices
	AND #%10111111
	ORA #%01000000
	STA $FFFF

	JSR sendchar_init

	LDA #$40 ; RTI		; reset interrupt locations
	STA $0390 ; NMI
	LDA #<keyint
	STA $0399 ; IRQ
	LDA #>keyint
	STA $039A ; IRQ

	LDA via_da		; PA7 input
	AND #%01111111
	STA via_da
	LDA #%00001110		; CA2 high output by default, CA1 falling edge
	STA via_pcr
	LDA #%10000010 		; interrupts on CA1
	STA via_ier

	STZ key_write		; reset key info
	STZ key_read
	STZ key_data
	STZ key_counter

	LDY #$00 		; clears shift registers
	LDX #$00
	LDA #$00
	JSR sendchar
	JSR sendchar

	LDY #$80 		; clears screen
	LDX #$00
clear
	LDA #$00
	JSR sendchar
	INX
	BNE clear
	INY
	CPY #$A0
	BNE clear

	CLI

	LDY pos			; draw cursor
	LDX pos+1
	LDA #"_"
	JSR sendchar

loop
	JSR $0368 ; inputchar subroutine
	CMP #$00
	BEQ loop

	CMP #$0D ; return
	BNE cont1
	LDA pos+1
	CMP #$80
	LDA #$81
	STA pos+1
	BCC loop
	INC pos
	LDA #$01
	STA pos+1
	JMP loop
cont1
	CMP #$08 ; backspace
	BNE cont2
	DEC pos+1
	JMP loop
cont2
	CMP #$1B ; escape
	BNE cont3
	JMP exit
cont3
	CMP #"[" ; sound on
	BNE cont4
	JSR sound_start
	JMP loop
cont4
	CMP #"]" ; sound off
	BNE cont5
	JSR sound_end
	JMP loop
cont5
	LDY pos
	LDX pos+1
	JSR sendchar
	INC pos+1
	INX
	LDA #"_"
	JSR sendchar
	JMP loop

exit
	PLX
	PLA

	RTS ; go back to normal operations


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


; the IRQ interrupt looks for keyboard clock/data input, and stores it in the buffer.  That is it.
; this needs to be as short as possible, I have had issues in the past where it was too long and then ignoring some of the key input signals
keyint
	PHA
	LDA via_pa
	AND #%10000000				; read PA7
	CLC	
	ROR key_data				; shift key_data
	CLC
	ADC key_data				; add the PA7 bit into key_data
	STA key_data
	INC key_counter				; increment key_counter
	LDA key_counter
	CMP #$09 ; data ready			; 1 start bit, 8 data bits = 9 bits until real data ready
	BNE keyint_check
	LDA key_data
	STA key_complete			; put the key code into 'key_complete'
	JMP keyint_exit				; and exit
keyint_check
	CMP #$0B ; reset counter		; 1 start bit, 8 data bits, 1 parity bit, 1 stop bit = 11 bits to complete a full signal
	BNE keyint_exit
	STZ key_counter				; reset the counter
	LDA key_complete
	STA $0800
	PHX
	LDX key_write
	STA key_array,X				; store 'key_complete' into 'key_array'
	PLX
	INC key_write				; increment the position
keyint_exit
	PLA
	RTI


; the sound comes from PB7 using the T1 timer.  Set a frequency, let it free-run.  Very simple.
sound_start
	LDA #%10000000				; make PB7 output now
	STA via_db
	LDA #%11111111				; this is T1 timer stuff
	STA via+$04
	LDA #%11111111
	STA via+$05
	LDA #%11000000				; enable sound on PB7
	STA via+$0B
	LDA #$FF ; arbitrary frequency
	STA via+$04 				; lower timer
	LDA #$1F ; arbitrary frequency
	STA via+$05 				; higher timer
	RTS

sound_end
	LDA #%00000000				; turn off T1 timer
	STA via+$0B
	LDA #%00000000				; make PB7 input now
	STA via_db
	RTS


