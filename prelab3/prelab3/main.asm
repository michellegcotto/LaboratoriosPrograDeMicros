/*
* prelab3.asm
*
* Autor : Jaqueline Michelle González Cotto
* Descripción: contador binario de 4 bits con incremento y decremento
*/

.include "M328PDEF.inc"

.dseg
.org SRAM_START
PREVIO:   .byte 1 //reserva de 1 byte para guardar el estado previo del puerto D

.cseg
.org 0x0000
    RJMP SETUP //salto a la rutina inicial

.org 0x000A //vector de interrupción para PCINT2
    RJMP PCINT_ISR //salto a la rutina de interrupción

/****************************************/
// Configuración de la pila
SETUP:
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

/****************************************/
// Configuración MCU

    LDI R16, 0x0F //carga de salidas de los leds
    OUT DDRB, R16 //configura los los 4 bits en Puerto B como salida

    CBI DDRD, 4  //entrada del boton de decremento           
    SBI PORTD, 4 //activación de resistencias pull-up para boton en pd4

	CBI DDRD, 5 //entrada del boton de incremento
	SBI PORTD, 5 //activación de resistencias pull-up para boton en pd5

	LDI R20, 0X00 //inicia el contador en 0
	OUT PORTB, R20 //muestra el primer valor (cero) en el puerto B

	IN R17, PIND //lee el estado actual del puerto D
	STS PREVIO,R17 //guarda el estado como referencia incial

	LDI R16, (1<<PCIE2) //habilita interrupciones por el cambio de pin
	STS PCICR, R16 //activa el grupo de PCINT en el puertoD

	LDI R16, (1<<PCINT20)|(1<<PCINT21) //habilita interrupciones en los botones
	STS PCMSK2, R16 //configuración de mascara de interrupciones en botones

    SEI //interrupciones globales

/****************************************/
// Loop Infinito
MAIN_LOOP:
    RJMP MAIN_LOOP

/****************************************/
// Interrupt Service Routine
PCINT_ISR:
	IN R18, PIND //lee estado actual del puertoD
	LDS R19, PREVIO //carga el estado previo ya guardado

	MOV R21, R18 //copia el estado actual
	EOR R21, R19 // es un XOR para detectar bits cambiados

	SBRS R21, 5 //si el boton no fue apretado, salta a la siguiente instruccion
	RJMP REVISAR //si no cambió el boton de inc, revisar el otro boton

	SBRS R18, 5 //si el boton está en alto se lo salta
	RJMP INCREMENTAR //si el boton está en bajo incrementa

REVISAR:
	SBRS R21, 4 //si el boton de decre no cambia se lo salta
	RJMP GUARDAR_ESTADO //si no cambia el boton, guarda el estado que tenga

	SBRS R18, 4 //si el boton de decre esta en alto se lo salta
	RJMP DECREMENTAR //si el boton de decre está bajo decrementa

GUARDAR_ESTADO:
	STS PREVIO, R18 //guarda el nuevo estado ahora como previo
	RETI //retorna de la interrupción

INCREMENTAR:
	INC R20 //incrementa el contador
	ANDI R20, 0X0F //limita que solo sean 4 bits
	OUT PORTB, R20 //actualiza la salida en el puerto B
	RJMP GUARDAR_ESTADO //guarda el estado y termina la interrupción

DECREMENTAR:
	DEC R20 //decrementa el contador
	ANDI R20, 0X0F //limita que solo sean 4 bits
	OUT PORTB, R20 //actualiza la salida en el puerto B
	RJMP GUARDAR_ESTADO //guarda el estado y termina la interrupción