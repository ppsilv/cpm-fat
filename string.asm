; Parse a hex string (up to 4 nibbles) to a binary
; HL: Address of hex (ASCII)
; DE: Output
;
Parse_Hex16:            LD      DE,0                    ; Clear the output
                        LD      B,4                     ; Maximum number of nibbles
Parse_Hex:              LD      A,(HL)                  ; Get the nibble
                        SUB     '0'                     ; Normalise to 0
                        RET     C                       ; Return if < ASCII '0'
                        CP      10                      ; Check if >= 10
                        JR      C,1F
                        SUB     7                       ; Adjust ASCII A-F to nibble
                        CP      16                      ; Check for > F
                        RET     NC                      ; Return
1:                      SLA     DE                      ; Shfit DE left 4 times
                        SLA     DE
                        SLA     DE
                        SLA     DE
                        OR      E                       ; OR the nibble into E
                        LD      E,A
                        INC     HL                      ; Increase pointer to next byte of input
                        DJNZ    Parse_Hex               ; Loop around
                        RET

; Print a 16-bit HEX number
; HL: Number to print
;
Print_Hex16:            LD      A,H
                        CALL    Print_Hex8
                        LD      A,L

; Print an 8-bit HEX number
; A: Number to print
;
Print_Hex8:             LD      C,A
                        RRA
                        RRA
                        RRA
                        RRA
                        CALL    1F
                        LD      A,C
1:                      AND     0x0F
                        ADD     A,0x90
                        DAA
                        ADC     A,0x40
                        DAA
                        JP      print_a

; Print CR/LF
;
Print_CR:               LD      A,0x0D
                        CALL    print_a
                        LD      A,0x0A
                        JP      print_a

Print_String:           LD      A,(HL)
                        OR      A
                        RET     Z
                        CALL    Print_Char
                        INC     HL
                        JR      Print_String

Print_Char:             JP      UART_TX                          