/*
* lab1.asm
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
// configuración primeras 4 leds
    LDI R16, 0X0F	//carga 00001111 en R16
	OUT DDRB, R16	//configura PB0 a PB3 como salidas

	CBI DDRD, 2		//configura PD2 como entrada
	SBI PORTD, 2	//activa resistencia pull-up en PD2

	CBI DDRD, 3		//configura PD3 como entrada
	SBI PORTD, 3	//activa resistencia pull-up en PD3

	LDI R20, 0X00	//inicializa contador R20 en 0
	OUT PORTB, R20	//apaga los 4 leds

// configuración segundas 4 leds
	SBI DDRD, 4		//configura PD4 como salida
	SBI DDRD, 5		//configura PD5 como salida
	SBI DDRD, 6		//configura PD6 como salida
	SBI DDRD, 7		//configura PD7 como salida

	CBI DDRC, 4		//configura PC4 como entrada
	SBI PORTC, 4	//activa pull-up en PC4

	CBI DDRC, 5		//configura PC5 como entrada
	SBI PORTC, 5	//activa pull-up en PC5

	LDI R21, 0X00	//inicia contador en 0

// suma botón
	CBI DDRC, 0		//Configura botón de entrada
	SBI PORTC, 0	//activa pull-up en PC0

// suma 4 leds
	SBI DDRB, 4		//configura PB4 como salida
	SBI DDRB, 5		//configura PB5 como salida
	SBI DDRC, 2		//configura PC2 como salida
	SBI DDRC, 3		//configura PC3 como salida
	SBI DDRC, 1		//configura PC1 como salida
/****************************************/
// Loop Infinito
MAIN_LOOP:
// primeros 4 leds
	SBIS PIND, 2	//si PD2 está en 1 saltar
	CALL AUMENTAR	//si botón presionado, llamar a AUMENTAR

	SBIS PIND, 3	//si PD3 está en 1, saltar
	CALL DECREMENTAR	//si botón presionado, llamar DECREMENTAR

// segundos 4 leds
	SBIS PINC, 4	//verifica botón en PC4
	CALL AUMENTAR2	//llama a INCREMENTAR2

	SBIS PINC, 5	//verifica botón en PC5
	CALL DECREMENTAR2	//llama a DECREMENTAR

// suma botón
	SBIS PINC, 0	//verifica botón
	CALL SUMA		//llama a SUMA

	RJMP MAIN_LOOP
/****************************************/
// NON-Interrupt subroutines
// primeras 4 leds
AUMENTAR:		//subrutina para incrementar primer contador
	INC R20
	ANDI R20, 0X0F
	OUT PORTB, R20
	CALL DELAY
	RET	

DECREMENTAR:	//subrutina para decrementar primer contador
	DEC R20
	ANDI R20, 0X0F
	OUT PORTB, R20
	CALL DELAY
	RET

// segundas 4 leds
AUMENTAR2:		//subruitna para incrementar segundo contador
	INC R21
	ANDI R21, 0X0F
	MOV R22, R21
	SWAP R22
	ANDI R22, 0XF0
	IN R23, PORTD
	ANDI R23, 0X0F
	OR R23, R22
	OUT PORTD, R23

	CALL DELAY
	RET

DECREMENTAR2:	//subruitna para decrementar segundo contador
	DEC R21
	ANDI R21, 0X0F
	MOV R22, R21
	SWAP R22
	ANDI R22, 0XF0
	
	IN R23, PORTD
	ANDI R23, 0X0F
	OR R23, R22
	OUT PORTD, R23

	CALL DELAY
	RET

// suma

SUMA:		//subrrutina para hacer la suma
	MOV R24, R20
	ADD R24, R21

	CBI PORTB, 4
	CBI PORTB, 5
	CBI PORTC, 2
	CBI PORTC, 3
	CBI PORTC, 1

	SBRC R24, 0
	SBI PORTB, 4
	SBRC R24, 1
	SBI PORTB, 5
	SBRC R24, 2
	SBI PORTC, 2
	SBRC R24, 3
	SBI PORTC, 3

	SBRC R24, 4
	SBI PORTC, 1

	SBRS R24, 4
	CBI PORTC, 1

FIN:
	CALL DELAY	//retardar
	RET			//retornar
/****************************************/
// Interrupt routines
// primeros 4 bits
DELAY:	//retardo por software
	LDI R17, 0X20
	LDI R18, 0XFF
	LDI R19, 0XFF

BUCLE:		//bucle de retardo
	DEC R19
	BRNE BUCLE

	DEC R18
	BRNE BUCLE

	DEC R17
	BRNE BUCLE

	RET
/****************************************/