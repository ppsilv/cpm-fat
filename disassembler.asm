
FN_Disassemble:         LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        LD      A,(HL)
                        CP      ','
                        JR      NZ,2F
                        INC     HL
                        PUSH    DE
                        CALL    Parse_Hex16
                        POP     HL
                        LD      B,D
                        LD      C,E
                        LD      IX,SYS_VARS_INPUT
                        LD      A,B
                        OR      C
                        JP      NZ,Disassemble
2:                      LD      HL,MSG_ERROR
                        JP      Print_String



;******************************************************************************************
;                        L O W  L E V E L
;                        R O U T I N E S
;******************************************************************************************



;
; Title:	Z80 Disassembler for BSX
; Author:	Dean Belfield
; Created:	03/06/2020
; Last Updated:	05/10/2020
;
; Based upon information in http://www.z80.info/decoding.htm
;
; Modinfo:
; 06/06/2020:	Output formatting tweaks
; 05/10/2020:	Added UART support

;
; Macros
;

; Macro to write a single char to the output buffer
;
CHAR:			MACRO	value
			LD	(IY+0), value
			INC	IY
			ENDM

; Macro to write the zero-delimited text to the output buffer
;
TEXT:			MACRO 	text
			CALL	Copy_String
			DZ	text
			ENDM

; Macro to write the zero delimited text to the output buffer if A != value
;
TEXTIF:			MACRO	value, text
			CP	value
			JR	NZ, .S1
			CALL	Copy_String
			DZ	text
			RET 
.S1:			;
			ENDM 

; Macro to index string from table[value]
;
TEXTIN:			MACRO	table, value 
			LD 	A, value 
			TEXTINM	table, Copy_String_Index
			ENDM 

; Macro to index string from table[A]
;
TEXTINA:		MACRO	table
			TEXTINM	table, Copy_String_Index
			ENDM 

; Same as TEXTIN, but takes the shift opcodes DD and FD into account 
; Used for tables DTable_R, DTable_RP1 and DTable_RP2
;
TEXTINS:		MACRO	table, value 
			LD 	A, value 
			TEXTINM	table, Copy_String_Index_S 
			ENDM 

; Same as TEXTINA, but takes the shift opcodes DD and FD into account
; Used for tables DTable_R, DTable_RP1 and DTable_RP2
;
TEXTINSA:		MACRO	table
			TEXTINM	table, Copy_String_Index_S 
			ENDM 

; Macro called by all TEXTIN macros 
;
TEXTINM:		MACRO	table, function
			EXX 
			LD	HL, table
			CALL	function
			EXX 
			ENDM

; Add A to HL (signed)
;
ADD_HL_A_SIGNED:	MACRO
			OR A 
			JP P, .S1
			DEC H
.S1			ADD A, L  
			LD L, A 
			ADC A, H 
			SUB L 
			LD H, A 
			ENDM 

; Add A to BC (signed)
;
ADD_BC_A_SIGNED:	MACRO
			OR A 
			JP P, .S1
			DEC B
.S1			ADD A, C  
			LD C, A 
			ADC A, B
			SUB C 
			LD B, A 
			ENDM 			

; HL: Start address of memory to disassemble
; IX: Address of buffer 
; 	+&00: Address (2 bytes)
;	+&02: Opcode byte count (1 byte)
;	+&03: Temporary Storage (4 bytes)
;	+&07: Shift byte (&00, &CB, &DD, &ED, &FD)
;	+&08: Disassembly text
; BC: Number of bytes to disassemble
;
Disassemble:		LD 	A,IXL			; Point IY to the disassembly text address
			ADD	A,8
			LD	IYL,A 
			LD	A,IXH 
			ADC	A,0
			LD	IYH,A

1:			PUSH 	BC			; Stack the loop counter
			LD	A,L: LD (IX+0),A	; Store the address
			LD	A,H: LD (IX+1),A 
			PUSH	IY 			; Stack the string buffer address
			LD	(IX+2),0		; Clear the byte count
			LD	(IX+7),0		; Clear the shift byte
			CALL	Disassemble_Op		; Disassemble the OP code
			LD	A,(IX+7)		; Is it a shift byte?
			OR	A			
			CALL	NZ,Disassemble_Op	; If not zero, then do it again!
			LD	(IY+0),0		; Terminate the string
			POP 	IY
			PUSH	HL 			; Print the string to the console
			LD	A,(IX+0): LD L,A	; First the address
			LD	A,(IX+1): LD H,A
			CALL 	Print_Hex16
			LD	A,":": CALL Print_Char
			LD	A," ": CALL Print_Char
			CALL	Print_Opcodes
			LD	A,IYL: LD L,A 		; And finally the disassembly
			LD	A,IYH: LD H,A 
			CALL 	Print_String
			CALL	Print_CR
			POP 	HL 
			POP 	BC			; Pop the line loop counter
			CALL 	Read_Char_NB		; Check for ESC
			CP 	0x1B
			RET	Z
			LD	A,(IX+2)		; Decrement number of bytes
			NEG
			ADD_BC_A_SIGNED
			BIT	7,B 
			JR	Z, 1B			; Loop
			RET 

; Print the opcodes out to the terminal
; HL: Start of memory to dump
;
Print_Opcodes:		LD	B,(IX+2)		; Number of bytes in this instruction
1:			LD	A,(HL)			; Fetch the byte from memory
			CALL	Print_Hex8		; Output an 8 digit hex code
			LD	A," "			; Pad with a space
			CALL	Print_Char
			INC	HL
			DJNZ	1B
			LD	A,4			; Need to pad this out
			SUB	(IX+2)			; Work out how many spaces to pad out with 3*(4-#opcodes)
			RET	C 			; If no padding required, then exit
			RET	Z
			LD	B,A 			; Multiply by 3
			SLA	A
			ADD	A,B 
			LD	B,A			; Store in loop counter, and pad
2:			LD	A," ": CALL Print_Char
			DJNZ 	2B	
			RET 

; Disassemble a single op code
; HL: Current memory address
; IY: Buffer to store string in
; Returns:
;  A: 0 or CB, DD, ED, FD prefix shift (TODO)
;
Disassemble_Op:		LD	B,(HL)			; Get the opcode byte to decode
			INC	HL 			; Skip to next memory address
			INC	(IX+2)			; Increment the opcode byte count

			LD 	A,B
			AND	0b00000111
			LD	D,A			; D = Z
			LD 	A,B
			AND	0b00111000	
			SRL	A
			SRL	A 
			SRL	A
			LD	E,A			; E = Y
			SRL	A
			LD	C,A			; C = P

			LD	A,(IX+7)		; Check the shift byte
			CP	0xCB
			JP 	Z, Disassemble_Op_CB
			CP	0xED
			JP	Z, Disassemble_Op_ED

			LD 	A,B
			AND	0b11000000		; Get the X value
			CP	0b11000000: JP	Z, Disassemble_Op_X3
			CP	0b10000000: JP 	Z, Disassemble_Op_X2
			CP 	0b01000000: JP	Z, Disassemble_Op_X1

Disassemble_Op_X0:	LD 	A,D			; Get Z
			CP	7: JP	Z, Disassemble_Op_X0Z7
			CP	6: JP	Z, Disassemble_Op_X0Z6
			CP	5: JP	Z, Disassemble_Op_X0Z5
			CP 	4: JP	Z, Disassemble_Op_X0Z4
			CP	3: JP	Z, Disassemble_Op_X0Z3
			CP	2: JP	Z, Disassemble_Op_X0Z2
			CP	1: JP	Z, Disassemble_Op_X0Z1

Disassemble_Op_X0Z0:	LD 	A,E			; Get Y
			TEXTIF	0, "NOP"
			TEXTIF	1, "EX AF,AF'"
			TEXTIF	2, "DJNZ ?R"
			TEXTIF	3, "JR ?R"
			TEXT	"JR "
			LD	A,E
			SUB	4
			TEXTINA	DTable_CC
			TEXT	",?R"
			RET

Disassemble_Op_X0Z1:	BIT    	3,B 	
			JR	NZ, 1F
			TEXT	"LD "			; Q = 0
			TEXTINS	DTable_RP1, C
			TEXT	",?W"
			RET
1:			TEXT	"ADD HL,"		; Q = 1
			TEXTINS	DTable_RP1, C
			RET

Disassemble_Op_X0Z2:	BIT	3,B
			JR	NZ, 1F
			LD	A,C			; Q = 0
			TEXTIF	0, "LD (BC),A"
			TEXTIF	1, "LD (DE),A"
			TEXTIF	2, "LD (?W),HL"
			TEXTIF	3, "LD (?W),A"		
			RET
1:			LD	A,C 			; Q = 1
			TEXTIF	0, "LD A,(BC)"
			TEXTIF	1, "LD A,(DE)"
			TEXTIF	2, "LD HL,(?W)"
			TEXTIF	3, "LD A,(?W)"
			RET

Disassemble_Op_X0Z3:	BIT	3,B
			JR 	NZ,1F
			TEXT	"INC "			; Q = 0
			TEXTINS	DTable_RP1, C 
			RET
1:			TEXT	"DEC "			; Q = 1
			TEXTINS	DTable_RP1, C
			RET 

Disassemble_Op_X0Z4:	TEXT	"INC "
			TEXTINS	DTable_R, E 
			RET

Disassemble_Op_X0Z5:	TEXT	"DEC "
			TEXTINS	DTable_R, E  
			RET

Disassemble_Op_X0Z6:	TEXT	"LD "
			TEXTINS	DTable_R, E 
			TEXT	",?B"
			RET

Disassemble_Op_X0Z7:	TEXTIN	DTable_O1, E 
			RET

Disassemble_Op_X1:	LD	A,D			; If Z is 6 
			CP	6
			JR 	NZ,1F
			LD	A,E			; and Y is 6
			CP	6
			JR	NZ,1F
			TEXT	"HALT"			; The opcode is HALT
			RET 
1:			TEXT	"LD "			; Otherwis LD r[y], r[z]
			TEXTINS	DTable_R, E		
			CHAR	","
			TEXTINS	DTable_R, D
			RET 

Disassemble_Op_X2:	TEXTIN	DTable_ALU, E		; ALU[y] r[z]
			TEXTINS	DTable_R, D	
			RET

Disassemble_Op_X3:	LD 	A,D			; Get Z
			CP	7: JP	Z, Disassemble_Op_X3Z7
			CP	6: JP	Z, Disassemble_Op_X3Z6
			CP	5: JP	Z, Disassemble_Op_X3Z5
			CP 	4: JP	Z, Disassemble_Op_X3Z4
			CP	3: JP	Z, Disassemble_Op_X3Z3
			CP	2: JP	Z, Disassemble_Op_X3Z2
			CP	1: JP	Z, Disassemble_Op_X3Z1

Disassemble_Op_X3Z0:	TEXT 	"RET "			; RET cc[y]
			TEXTIN	DTable_CC, E
			RET

Disassemble_Op_X3Z1:	BIT 	3,B
			JR	NZ,1F
			TEXT	"POP "			; Q = 0
			TEXTINS	DTable_RP2, C
			RET 
1:			LD	A,C 			; Q = 1
			TEXTIF	0, "RET"
			TEXTIF	1, "EXX"
			TEXTIF	2, "JP HL"
			TEXTIF	3, "LD SP,HL"
			RET

Disassemble_Op_X3Z2:	TEXT	"JP "			; JP cc[y]
			TEXTIN	DTable_CC, E
			TEXT	",?W"
			RET

Disassemble_Op_X3Z3:	LD	A,E
			CP	1
			JR 	NZ,1F
			LD	(IX+7),0xCB 
			RET 
1:			TEXTIF	0, "JP ?W"	
			TEXTIF	2, "OUT (?B),A"
			TEXTIF	3, "IN A,(?B)"
			TEXTIF	4, "EX (SP),HL"
			TEXTIF 	5, "EX DE,HL"
			TEXTIF	6, "DI"
			TEXTIF	7, "EI"
			RET

Disassemble_Op_X3Z4:	TEXT	"CALL "			; CALL cc[y]
			TEXTIN	DTable_CC, E
			TEXT	",?W"
			RET
			
Disassemble_Op_X3Z5:	BIT 	3,B
			JR	NZ,1F
			TEXT	"PUSH "			; Q = 0
			TEXTINS	DTable_RP2, C
			RET 
1:			LD	A,C 			; Q = 1
			TEXTIF	0, "CALL ?W"
			SLA	A 			; Return opcodes DD,ED or FD
			SLA	A 
			SLA 	A
			SLA 	A
			ADD	A, 0xCD
			LD	(IX+7),A		; And store the shift byte
			RET 

Disassemble_Op_X3Z6:	TEXTIN	DTable_ALU, E		; ALU[y],n
			TEXT	"?B"
			RET

Disassemble_Op_X3Z7:	TEXT 	"RST "
			LD 	A,E 
			SLA 	A
			SLA 	A
			SLA 	A
			JP	Copy_Hex8

Disassemble_Op_CB:	LD	A,B
			AND	0b11000000		; Get the X value
			CP	0b11000000: JR	Z, 3F
			CP	0b10000000: JR 	Z, 2F
			CP 	0b01000000: JR	Z, 1F
			TEXTIN	DTable_ROT, E		; ROT[y], r[z]
			TEXTINS	DTable_R, D
			RET
1:			TEXT	"BIT "			; BIT y, r[z]
			LD	A,E
			ADD	A,'0'
			CHAR	A 
			CHAR	","
			TEXTINS	DTable_R, D
			RET
2:			TEXT	"RES "			; RES y, r[7]
			LD	A,E
			ADD	A,'0'
			CHAR	A 
			CHAR	","
			TEXTINS	DTable_R, D
			RET
3:			TEXT	"SET "			; SET y, r[7]
			LD	A,E
			ADD	A,'0'
			CHAR	A 
			CHAR	","
			TEXTINS	DTable_R, D
			RET

Disassemble_Op_ED:	LD	A,B
			AND	0b11000000		; Get the X value
			CP	0b10000000: JP Z, Disassemble_Op_ED_X2
			CP	0b01000000: JP Z, Disassemble_Op_ED_X1
			RET
Disassemble_Op_ED_X1:	LD 	A,D			; Get Z
			CP	7: JP	Z, Disassemble_Op_ED_X1Z7
			CP	6: JP	Z, Disassemble_Op_ED_X1Z6
			CP	5: JP	Z, Disassemble_Op_ED_X1Z5
			CP 	4: JP	Z, Disassemble_Op_ED_X1Z4
			CP	3: JP	Z, Disassemble_Op_ED_X1Z3
			CP	2: JP	Z, Disassemble_Op_ED_X1Z2
			CP	1: JP	Z, Disassemble_Op_ED_X1Z1

			LD	A,E 
			CP	6
			JR 	Z, 1F
			TEXT 	"IN "
			TEXTINS	DTable_R, E 
			TEXT	",(C)"
			RET 
1:			TEXT	"IN (C)"
			RET

Disassemble_Op_ED_X1Z1:	TEXT 	"OUT (C),"
			LD	A,E 
			CP	6
			JR 	Z, 1F
			TEXTINS	DTable_R, E 			
			RET 
1:			CHAR	"0"
			RET

Disassemble_Op_ED_X1Z2:	BIT	3,B 
			JR	NZ, 1F
			TEXT	"SBC HL,"		; Q = 0
			TEXTINS	DTable_RP1, C 
			RET 
1:			TEXT	"ADC HL,"		; Q = 1
			TEXTINS	DTable_RP1, C 
			RET

Disassemble_Op_ED_X1Z3: BIT	3,B 
			JR	NZ, 1F
			TEXT	"LD (?W),"		; Q = 0
			TEXTINS	DTable_RP1, C 
			RET 
1:			TEXT	"LD "			; Q = 1
			TEXTINS	DTable_RP1, C 
			TEXT	",(?W)"
			RET

Disassemble_Op_ED_X1Z4:	TEXT	"NEG"
			RET 

Disassemble_Op_ED_X1Z5:	LD	A,E
			CP	1
			JR	Z,1F
			TEXT	"RETN"
			RET 
1:			TEXT	"RETI"
			RET 

Disassemble_Op_ED_X1Z6:	TEXT	"IM "
			TEXTIN	DTable_IM, E
			RET 

Disassemble_Op_ED_X1Z7:	TEXTIN	DTable_O2, E
			RET
			
Disassemble_Op_ED_X2:	LD	A,D 			; If z > 4 then invalid instruction
			CP	4
			RET	C 
			LD	A,E			; If y > 4 then invalid instruction
			SUB	4
			RET	C
			SLA	A
			SLA	A
			ADD	A,D 
			TEXTINA	DTable_BLI		; BLI[z+4(y-4)]
			RET

; Copy a zero terminated string
; String text placed directly after call
; IY: Destination
;
Copy_String:		EXX 
			EX	(SP),HL
			CALL	Copy_String_1
			EX	(SP),HL
			EXX
			RET

; Copy a zero terminated string indirectly from a table
; IY: Destination
; HL: Table to index into
;  A: Index into table
; Returns:
; HL: Pointer to zero-terminated string
;
Copy_String_Index_S:	PUSH	HL 
			LD	L,A 
			LD	A,(IX+7)

			CP	0xDD
			JR	NZ,1F
			LD	A,8
			ADD	A,L 
			JR	5F

1:			CP	0xFD
			JR	NZ,2F
			LD	A,16
			ADD	A,L
			JR	5F

2:			LD	A,L
5:			POP	HL

Copy_String_Index:	PUSH	HL			; Store the address of the table
			ADD	A,L			; Add the index to it
			LD	L,A
			LD	A,H
			ADC	A,0
			LD 	H,A
			LD	A,(HL)			; Fetch the relative address of the string to this table
			POP	HL			; Pop the address of the table
			ADD	A,L			; Add the relative address to this
			LD	L,A
			LD	A,H
			ADC	A,0
			LD 	H,A

; Copy a zero terminated string from a memory address
; IY: Destination
; HL: Source
;
Copy_String_1:		LD 	A,(HL)
			CP 	"?"
			JR 	NZ,1F
			INC	HL
			LD 	A,(HL)
			INC	HL
			CP	"B": JP	Z,Copy_String_B
			CP	"W": JP Z,Copy_String_W
			CP	"R": JP Z,Copy_String_R
			JR	2F
1:			LD	(IY+0),A 
2:			INC 	HL
			OR	A 
			RET	Z
			INC	IY
			JR	Copy_String_1

Copy_String_B:		INC	(IX+2)
			EXX 
			LD	A,(HL): INC HL
			EXX 
			CALL	Copy_Hex8
			JR	Copy_String_1

Copy_String_W:		INC	(IX+2)
			INC	(IX+2)
			PUSH 	HL
			EXX
			LD	A,(HL): LD (IX+3),A: INC HL
			LD	A,(HL): LD (IX+4),A: INC HL 
			EXX
			LD	A,(IX+3): LD L,A
			LD	A,(IX+4): LD H,A 
			CALL	Copy_Hex16 
			POP	HL
			JR 	Copy_String_1

Copy_String_R:		INC	(IX+2)
			PUSH	HL
			EXX
			LD	A,(HL): INC HL
			PUSH	HL 
			EXX 
			POP	HL
			ADD_HL_A_SIGNED
			CALL	Copy_Hex16
			POP	HL
			JR	Copy_String_1

; Copy a 16-bit HEX number to a buffer
; IY: Address of buffer
; HL: Number to print
;
Copy_Hex16:		LD A,H
			CALL Copy_Hex8
			LD A,L

; Copy an 8-bit HEX number into a buffer
; IY: Address of buffer
;  A: Number to print
;
Copy_Hex8:		PUSH AF 
			RRA 
			RRA 
			RRA 
			RRA 
			CALL 1F 
			POP AF 
1:			AND 0x0F
			ADD A,0x90
			DAA
			ADC A,0x40
			DAA
			LD (IY+0),A
			INC IY
			RET 	

; 8-Bit registers
;
DTable_R:		DB	DTable_R0-DTable_R, DTable_R1-DTable_R, DTable_R2-DTable_R, DTable_R3-DTable_R
			DB	DTable_R4-DTable_R, DTable_R5-DTable_R, DTable_R6-DTable_R, DTable_R7-DTable_R
			DB	DTable_R0-DTable_R, DTable_R1-DTable_R, DTable_R2-DTable_R, DTable_R3-DTable_R
			DB	DTable_R8-DTable_R, DTable_R9-DTable_R, DTable_RA-DTable_R, DTable_R7-DTable_R
			DB	DTable_R0-DTable_R, DTable_R1-DTable_R, DTable_R2-DTable_R, DTable_R3-DTable_R
			DB	DTable_RB-DTable_R, DTable_RC-DTable_R, DTable_RD-DTable_R, DTable_R7-DTable_R
DTable_R0:		DZ	"B"
DTable_R1:		DZ	"C"
DTable_R2:		DZ	"D"
DTable_R3:		DZ	"E"
DTable_R4:		DZ	"H"
DTable_R5:		DZ	"L"
DTable_R6:		DZ	"(HL)"
DTable_R7:		DZ	"A"
DTable_R8:		DZ 	"IXH"
DTable_R9:		DZ	"IXL"
DTable_RA:		DZ	"(IX+?B)"
DTable_RB:		DZ 	"IYH"
DTable_RC:		DZ	"IYL"
DTable_RD:		DZ	"(IY+?B)"

; 16-Bit Registers
;
DTable_RP1:		DB	DTable_RP10-DTable_RP1, DTable_RP11-DTable_RP1, DTable_RP12-DTable_RP1, DTable_RP13-DTable_RP1
			DB	DTable_RP10-DTable_RP1, DTable_RP11-DTable_RP1, DTable_RP24-DTable_RP1, DTable_RP13-DTable_RP1
			DB	DTable_RP10-DTable_RP1, DTable_RP11-DTable_RP1, DTable_RP25-DTable_RP1, DTable_RP13-DTable_RP1

DTable_RP2:		DB	DTable_RP10-DTable_RP2, DTable_RP11-DTable_RP2, DTable_RP12-DTable_RP2, DTable_RP23-DTable_RP2
			DB	DTable_RP10-DTable_RP2, DTable_RP11-DTable_RP2, DTable_RP24-DTable_RP2, DTable_RP23-DTable_RP2
			DB	DTable_RP10-DTable_RP2, DTable_RP11-DTable_RP2, DTable_RP25-DTable_RP2, DTable_RP23-DTable_RP2
DTable_RP10:		DZ	"BC"
DTable_RP11:		DZ	"DE"
DTable_RP12:		DZ	"HL"
DTable_RP13:		DZ	"SP"
DTable_RP23:		DZ	"AF"
DTable_RP24:		DZ	"IX"
DTable_RP25:		DZ	"IY"

; Condition codes
;
DTable_CC:		DB	DTable_CC0-DTable_CC, DTable_CC1-DTable_CC, DTable_CC2-DTable_CC, DTable_CC3-DTable_CC
			DB	DTable_CC4-DTable_CC, DTable_CC5-DTable_CC, DTable_CC6-DTable_CC, DTable_CC7-DTable_CC
DTable_CC0:		DZ	"NZ"
DTable_CC1:		DZ	"Z"
DTable_CC2:		DZ	"NC"
DTable_CC3:		DZ 	"C"
DTable_CC4:		DZ 	"PO"
DTable_CC5:		DZ 	"PE"
DTable_CC6:		DZ 	"P"
DTable_CC7:		DZ 	"M"

; Arithmetic Operations
;
DTable_ALU:		DB 	DTable_ALU0-DTable_ALU, DTable_ALU1-DTable_ALU, DTable_ALU2-DTable_ALU, DTable_ALU3-DTable_ALU
			DB 	DTable_ALU4-DTable_ALU, DTable_ALU5-DTable_ALU, DTable_ALU6-DTable_ALU, DTable_ALU7-DTable_ALU
DTable_ALU0:		DZ 	"ADD A,"
DTable_ALU1:		DZ	"ADC A,"
DTable_ALU2:		DZ	"SUB "
DTable_ALU3:		DZ	"SBC A,"
DTable_ALU4:		DZ	"AND "
DTable_ALU5:		DZ	"XOR "
DTable_ALU6:		DZ	"OR "
DTable_ALU7:		DZ	"CP "

; Shift and rotate operations
;
DTable_ROT:		DB	DTable_ROT0-DTable_ROT, DTable_ROT1-DTable_ROT, DTable_ROT2-DTable_ROT, DTable_ROT3-DTable_ROT
			DB	DTable_ROT4-DTable_ROT, DTable_ROT5-DTable_ROT, DTable_ROT6-DTable_ROT, DTable_ROT7-DTable_ROT
DTable_ROT0:		DZ	"RLC "
DTable_ROT1:		DZ	"RRC "
DTable_ROT2:		DZ	"RL "
DTable_ROT3:		DZ	"RR "
DTable_ROT4:		DZ	"SLA "
DTable_ROT5:		DZ	"SRA "
DTable_ROT6:		DZ	"SLL "
DTable_ROT7:		DZ	"SRL "

; Interrupt modes
;
DTable_IM:		DB	DTable_IM0-DTable_IM, DTable_IM1-DTable_IM, DTable_IM2-DTable_IM, DTable_IM3-DTable_IM
			DB	DTable_IM0-DTable_IM, DTable_IM1-DTable_IM, DTable_IM2-DTable_IM, DTable_IM3-DTable_IM
DTable_IM0:		DZ	"0"
DTable_IM1:		DZ	"0/1"
DTable_IM2:		DZ	"1"
DTable_IM3:		DZ	"2"

; Block instructions
;
DTable_BLI:		DB	DTable_BLI00-DTable_BLI, DTable_BLI01-DTable_BLI, DTable_BLI02-DTable_BLI, DTable_BLI03-DTable_BLI
			DB	DTable_BLI10-DTable_BLI, DTable_BLI11-DTable_BLI, DTable_BLI12-DTable_BLI, DTable_BLI13-DTable_BLI
			DB	DTable_BLI20-DTable_BLI, DTable_BLI21-DTable_BLI, DTable_BLI22-DTable_BLI, DTable_BLI23-DTable_BLI
			DB	DTable_BLI30-DTable_BLI, DTable_BLI31-DTable_BLI, DTable_BLI32-DTable_BLI, DTable_BLI33-DTable_BLI
DTable_BLI00:		DZ	"LDI"
DTable_BLI01:		DZ	"CPI"
DTable_BLI02:		DZ	"INI"
DTable_BLI03:		DZ	"OUTI"
DTable_BLI10:		DZ	"LDD"
DTable_BLI11:		DZ	"CPD"
DTable_BLI12:		DZ	"IND"
DTable_BLI13:		DZ	"OUTD"
DTable_BLI20:		DZ	"LDIR"
DTable_BLI21:		DZ	"CPIR"
DTable_BLI22:		DZ	"INIR"
DTable_BLI23:		DZ	"OTIR"
DTable_BLI30:		DZ	"LDDR"
DTable_BLI31:		DZ	"CPDR"
DTable_BLI32:		DZ	"INDR"
DTable_BLI33:		DZ	"OTDR"

DTable_O1:		DB	DTable_O10-DTable_O1, DTable_O11-DTable_O1, DTable_O12-DTable_O1, DTable_O13-DTable_O1
			DB	DTable_O14-DTable_O1, DTable_O15-DTable_O1, DTable_O16-DTable_O1, DTable_O17-DTable_O1
DTable_O10:		DZ	"RLCA"
DTable_O11:		DZ	"RRCA"
DTable_O12:		DZ	"RLA"
DTable_O13:		DZ 	"RRA"
DTable_O14:		DZ 	"DAA"
DTable_O15:		DZ 	"CPL"
DTable_O16: 		DZ	"SCF"
DTable_O17:		DZ	"CCF"

DTable_O2:		DB	DTable_O20-DTable_O2, DTable_O21-DTable_O2, DTable_O22-DTable_O2, DTable_O23-DTable_O2
			DB	DTable_O24-DTable_O2, DTable_O25-DTable_O2, DTable_O26-DTable_O2, DTable_O26-DTable_O2
DTable_O20:		DZ	"LD I,A"
DTable_O21:		DZ	"LD R,A"
DTable_O22:		DZ	"LD A,I"
DTable_O23:		DZ 	"LD A,R"
DTable_O24:		DZ 	"RRD"
DTable_O25:		DZ 	"RLD"
DTable_O26: 		DZ	"NOP"

