;
; Title:        Z80 Monitor for BSX
; Author:       Dean Belfield
; Created:      12/05/2020
; Last Updated: 05/10/2020
;
; Modinfo:
; 22/05/2020:   Moved SYS_VARS to last page of RAM
;               Added B option to jump to BBC Basic
; 28/05/2020:   Added O(ut) and I(n) instructions
;               Added ASCII column for memory dump
; 29/05/2020:   O(ut) instruction now supports Hex and ASCII strings
; 03/06/2020:   Added Z80 disassembler
; 05/10/2020:   Added UART support, source formatting changes
;
;
; Start
;


Start:                  
                        LD      A, 0x80 			; All ports output A,B and C
	                    OUT     (PIO_M), A		; 
                        LD      A, 0xA0    
                        OUT     (PIO_A), A
                        IF      SKIP_MEMTEST = 1
                        LD      HL,0x0000
                        XOR     A
                        JR      3F
                        ELSE
                        LD      HL,RAM_START
                        LD      C, 10101010b
1:                      LD      (HL),C
                        LD      A,(HL)
                        CP      C
                        JR      NZ,3F
                        INC     HL
                        LD      A,L
                        OR      A
                        JR      NZ,2F
;                       LD      A,"."
;                       OUT     (PORT_STM_IO),A         ; Output progress - no longer works (STM_IO depreciated)
2:                      LD      A,H
                        OR      A
                        JR      NZ,1B
                        ENDIF
3:                      LD      (SYS_VARS_RAMTOP),HL    ; Store last byte of physical RAM in the system variables
                        
                        LD      SP,HL                   ; Set the stack pointer
                        ld      hl, 0xFFFF - 1024
                        ld      SP,HL
                        ;JR      Z,Memtest_OK
                        JR      Memtest_OK
                        LD      HL,MSG_BADRAM
                        JR      Ready
Memtest_OK:             LD      HL,MSG_READY

Ready:                  PUSH    HL                      ; Stack the startup error message
                        LD      HL,UART_BAUD_38400       ; Baud rate = 9600
                        LD      A,0x03                  ; 8 bits, 1 stop, no parity
                        CALL    UART_INIT               ; Initialise the UART
                        ;lcd routines
                        call    long_pause

                        LD      HL,MSG_CLEAR
                        CALL    Print_String
                        LD      HL,MSG_STARTUP
                        CALL    Print_String
                        
                        CALL    message
   	                    db 27,'[2J',27,'[H'
                        db 'Z80 Playground Monitor & CP/M Loader v1.03',13,10,0
                        ; Check MCR
                        ld a, %00100010
                        out (uart_MCR), a
                        call message
                        db '16C550: ',0
                        in a, (uart_MCR)
                        call show_a_as_hex
                        call newline

                        call    long_pause

                        call message
                        db 'Configure USB Drive...',13,10,0
                        call configure_memorystick

                        call message
                         db 'Check CH376 module exists...',13,10,0                        
                        call check_module_exists
                        
                        call message
                        db 'Get CH376 module version...',13,10,0
                        call get_module_version

                        call message
                        db 'T E R M I N O U . . . ',13,10,0

                        ;halt

                        ld a, (auto_run_char)
                        cp 0
                        jp z, start_monitor
                        call message
                        db 'AUTO ',0
                        call show_a_safe
                        call newline
                        jp start_monitor
                        CALL    message
   	                    db 27,'[2J',27,'[H'
                        db 'Z80 Playground Monitor & CP/M Loader v1.03',13,10,0
                        halt

InputMenu:              call    Print_Help 
InputMenu1:                
                        LD      HL,SYS_VARS_INPUT       ; Input buffer
                        LD      B,0                     ; Cursor position
Input_Loop:             CALL    Read_Char               ; Read a key from the keyboard
                        CP      0x7F
                        JR      Z,Input_Backspace       ; Handle backspace

                        CALL    Print_Char              ; Output the character
                        LD      (HL),A                  ; Store the character in the buffer


                        INC     HL                      ; Increment to next character in buffer
                        INC     B                       ; Increment the cursor position
                        CP      0x0D                    ; Check for newline
                        JR      NZ,Input_Loop           ; If not pressed, then loop

                        CALL    Print_CR                ; Output a carriage return


                        LD      A,(SYS_VARS_INPUT)      ; Check the first character of input
                        LD      HL,Input_Ret            ; Push the return address on the stack
                        PUSH    HL
                        ;CP      'B': JP Z,FN_Basic
                        CP      'D': JP Z,FN_Disassemble
                        CP      'd': JP Z,FN_Disassemble
                        CP      'M': JP Z,FN_Memory_Dump
                        CP      'n': JP Z,FN_Memory_Dump
                        ;CP      'L': JP Z,FN_Memory_Load
                        ;CP      'J': JP Z,FN_Jump
                        ;CP      'O': JP Z,FN_Port_Out
                        ;CP      'I': JP Z,FN_Port_In
                        ;CP      '2': JP Z,FN_I2c
                        CP      '?': JP Z,Print_Help
                        CP      'H': JP Z,Print_Help
                        CP      'h': JP Z,Print_Help
                        ;CP      'C': JP Z,BBC_copy
                        CP      'R': JP MenuReturn
                        CP      'r': JP MenuReturn
                        CP      0x0D
                        RET     Z
                        LD      HL,MSG_INVALID_CMD      ; Unknown command error
                        JP      Print_String

Input_Ret:              CALL    Print_CR                ; On return from the function, print a carriage return
                        LD      HL,MSG_READY            ; And the ready message
                        CALL    Print_String
                        JR      InputMenu1                   ; Loop around for next input line

Input_Backspace:        LD      A,B                     ; Are we on the first character?
                        OR      A
                        JR      Z,Input_Loop
                        DEC     HL                      ; Skip back in the buffer
                        DEC     B
                        LD      (HL),0
                        JR      Input_Loop

Print_Help:
    call clear_screen
	call message
	db 13,10
	db 27,'[41m','+------------------+',13,10
	db 27,'[41m','|',27,'[40m','                  ',27,'[41m','|',13,10
	db 27,'[41m','|',27,'[40m','     BSX Menu     ',27,'[41m','|',13,10
	db 27,'[41m','|',27,'[40m','                  ',27,'[41m','|',13,10
	db 27,'[41m','+------------------+',27,'[40m',13,10,13,10,0
						;LD      HL,MSG000
                        ;CALL    Print_String
                        LD      HL,MSG001
                        CALL    Print_String
                        ;LD      HL,MSG002
                        ;CALL    Print_String
                        ;LD      HL,MSG003
                        ;CALL    Print_String
                        ;LD      HL,MSG004
                        ;CALL    Print_String
                        ;LD      HL,MSG005
                        ;CALL    Print_String
                        ;LD      HL,MSG006
                        ;CALL    Print_String
                        ;LD      HL,MSG007
                        ;CALL    Print_String
                        LD      HL,MSG008
                        CALL    Print_String
                        LD      HL,MSG098
                        CALL    Print_String
                        call    Input_Ret
                        RET



MSG_STARTUP:            DZ "BSX Version 0.3.1\n\r"
MSG_CLEAR:              DZ "\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r"

MSG_READY:              DZ "Ready:> "
MSG_BADRAM:             DZ "Mem Fault\n\r"
MSG_ERROR:              DZ "Error\n\r"
MSG_INVALID_CMD:        DZ "Invalid Command -\n\r"
MSG_INVALID_PORT:       DZ "Invalid Port #\n\r"
MSG_OUT_OF_RANGE:       DZ "Value out of range\n\r"
MSG000: DZ "Help  \n\r"
MSG001: DZ "  - Mnnnn,llll - Memory Hex Dump: Output llll bytes from memory location nnnn \n\r"
MSG002: DZ "  - Jnnnn - Jump to location nnnn \n\r"
MSG003: DZ "  - Onn,vv - O(utput) the value vv on Z80 port nn \n\r"
MSG004: DZ "  - Inn,llll - I(nput) llll values from Z80 port nn \n\r"
MSG005: DZ "  - L - Put the monitor into Load mode; it will wait for a binary stream of data on port 0 \n\r"
MSG006: DZ "  - B - Jump to address 0x4000 (where BBC Basic can be loaded) \n\r"
MSG007: DZ "  - 2nn - Send this data to standard I2C chip\n\r"
MSG008: DZ "  - Dnnnn,llll - Disassemble llll bytes from memory location nnnn \n\r"
MSG098: DZ "  - ? or H - Show this help \n\r"

