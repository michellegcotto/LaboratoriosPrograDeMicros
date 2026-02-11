/*
* prelab1.asm
*
* Creado: 06/02/2026
* Autor : Jaqueline Michelle González Cotto
* Descripción: Sumador binario de 4 bits
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P
.dseg
.org    SRAM_START
//variable_name:     .byte   1   // Memory alocation for variable_name:     .byte   (byte size)

.cseg
.org 0x0000
 /****************************************/
// Configuración de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16
/****************************************/
// Configuracion MCU
SETUP:
    LDI R16, 0X0F
	OUT DDRB, R16

	CBI DDRD, 2
	SBI PORTD, 2

	CBI DDRD, 3
	SBI PORTD, 3

	LDI R20, 0X00
	OUT PORTB, R20
/****************************************/
// Loop Infinito
MAIN_LOOP:
	SBIS PIND, 2
	CALL AUMENTAR

	SBIS PIND, 3
	CALL DECREMENTAR

    RJMP    MAIN_LOOP

/****************************************/
// NON-Interrupt subroutines
AUMENTAR:
	INC R20
	ANDI R20, 0X0F
	OUT PORTB, R20
	CALL DELAY
	RET

DECREMENTAR:
	DEC R20
	ANDI R20, 0X0F
	OUT PORTB, R20
	CALL DELAY
	RET

/****************************************/
// Interrupt routines
DELAY:
	LDI R17, 0X20
	LDI R18, 0XFF
	LDI R19, 0XFF

BUCLE:
	DEC R19
	BRNE BUCLE

	DEC R18
	BRNE BUCLE

	DEC R17
	BRNE BUCLE

	RET
/****************************************/