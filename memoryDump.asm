


FN_Memory_Dump:         LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        LD      A,(HL)
                        CP      ','
                        JR      NZ,2F
                        INC     HL
                        PUSH    DE
                        CALL    Parse_Hex16
                        POP     HL
                        LD      A,D
                        OR      E
                        JP      NZ,Memory_Dump
2:                      LD      HL,MSG_ERROR
                        JP      Print_String



Memory_Dump:            CALL    Print_Hex16
                        LD      A,':'
                        CALL    Print_Char
                        LD      A,' '
                        CALL    Print_Char
                        LD      B,16
                        LD      IX,SYS_VARS_INPUT
                        LD      (IX+0),' '
1:                      LD      A,(HL)
                        PUSH    AF
                        CP      32
                        JR      NC,2F
                        LD      A,'.'
2:                      LD      (IX+1),A
                        INC     IX
                        POP     AF
                        CALL    Print_Hex8
                        INC     HL
                        DEC     DE
                        LD      A,D
                        OR      E
                        JR      Z,3F
                        CALL    Read_Char_NB
                        CP      0x1B
                        JR      Z,3F
                        DJNZ    1B
                        CALL    5F
                        JR      Memory_Dump

3:                      LD      A,B
                        OR      A
                        JR      Z,5F
                        DEC     B
                        JR      Z,5F
                        LD      A,32
4:                      CALL    Print_Char
                        CALL    Print_Char
                        DJNZ    4B

5:                      LD      (IX+1),0x0D
                        LD      (IX+2),0x0A
                        LD      (IX+3),0x00
                        PUSH    HL
                        LD      HL,SYS_VARS_INPUT
                        CALL    Print_String
                        POP     HL
                        RET

