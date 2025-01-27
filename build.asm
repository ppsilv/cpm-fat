ROM_START		EQU 0x0000			; Start of ROM	
BAS_START		EQU	0x4000			; Location of BBC Basic in ROM
RAM_START		EQU 0x8000			; Start of RAM
;32k RAM
SYS_VARS		EQU	0xFF00			; System variable block
;16K ram
;SYS_VARS		EQU	0xBF00			; System variable block

SYS_VARS_RAMTOP		EQU SYS_VARS + 0x00
SYS_VARS_INPUT		EQU	SYS_VARS + 0x02

;PORT_STM_IO 		EQU	0x00			; The IO port for serial terminal IO - depreciated
;PORT_STM_FLAGS		EQU	0x07			; Flags - depreciated

BUILD_ROM		EQU 	1			; Set to 1 to build for ROM, or 0 to build for RAM
SKIP_MEMTEST	EQU		0			; Set to 1 to skip the memtest on boot - leave this until proper clock fitted





    IF	BUILD_ROM = 0
    ORG	RAM_START
    ELSE
    ORG	ROM_START
    include	"rom.asm"
    ENDIF 


    include "start.asm"
    include "ppi.asm"
    include "uart.asm"
    include "uart1.asm"
    include "message.asm"

    include "cpm.asm"
    include "memorystick.asm"
    include "filesize.asm"
    include "monitor.asm"
    include "tiny-basic.asm"
    include "GOFL.asm"

    ;From here I am merging two systems, 
    ; Title:        Z80 Monitor for BSX
    ; Author:       Dean Belfield

    ;AND

    ;Z80 playground made by John I know this is his name although he does not put his name in source code.
    ; 
    include "string.asm"
    include "disassembler.asm"
    include "memoryDump.asm"