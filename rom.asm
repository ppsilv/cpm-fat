;
; Title:	ROM specific code for Monitor
; Author:	Dean Belfield
; Created:	05/06/2020
; Last Updated:	11/10/2020
;
; Modinfo:
;
; 11/10/2020:	UART mods

    org $0000
    
; RST 00
;
			DI
			JP Start
			DS 4
;
; RST 08 - Read char from I/O
;
			JP Read_Char_NB
			DS 5
;
; RST 10 - Output char to I/O
;
			JP Print_Char
			DS 5
;
; RST 18
;
			DS 8
;
; RST 20
; 
			DS 8
;
; RST 28
;
			DS 8
;
; RST 30
;
			DS 8
;
; RST 38 - NMI
;
			EI
			RET
