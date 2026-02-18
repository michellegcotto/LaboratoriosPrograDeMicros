/*
* prelab2.asm
*
* Creado: 13/02/2026
* Autor : Jaqueline Michelle González Cotto
* Descripción: Timer de 4 bits
*/
/****************************************/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Include definitions specific to ATMega328P

.def TIMER = R17	//contador
.def OVERFLOW = R18	//cuenta la cantidad de overflows
.def temp = R16	//registro temporal

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
    //salidas
	LDI temp, (1<<DDD2)|(1<<DDD3)|(1<<DDD4)|(1<<DDD5)	//activa pines de salida)
	OUT DDRD, temp	//se escribe en DDRD los pines anteriores como salidas
	//contador y overflow
	CLR TIMER	//pone contador en 0
	CLR OVERFLOW	//pone contador de overflow en 0
	//timer normal
	LDI temp, 0x00	//se pone en el modo normal
	OUT TCCR0A, temp	//escribe la confi normal en ese lugar
	//prescaler
	LDI temp, (1<<CS02)|(1<<CS00) //selecciona el prescaler para el timer
	OUT TCCR0B, temp	//inicia el timer en la conf del prescaler
/****************************************/
// Loop Infinito
MAIN_LOOP:
	//espera overflow
	SBIS TIFR0, TOV0	//salta la instrucción si el bit está en 1
	RJMP MAIN_LOOP //si no hay, espera a que haya
	//limpiar bandera de overflow
	LDI temp, (1<<TOV0)	//carga un 1 en esa posición
	OUT TIFR0, temp	//escribe un 1 para limpiar la bandera

	INC OVERFLOW //incrementa el contador de overflows

	//comparación
	CPI OVERFLOW, 6	//compara overflow con 6
	BRNE MAIN_LOOP //si no hay 6, regresa al inicio
	//reinicia conteo
	CLR OVERFLOW	//reinicia el contador de overflow
	//incrementar contador de 4 bits
	INC TIMER	//incrementar el contador principal
	ANDI TIMER, 0X0F	//limita a que solo se puedan 4 bits
	//se alista para salida
	MOV temp, TIMER	//copia el valor del timer en temp
	LSL temp	//se mueve un bit a la izquierda
	LSL temp	//se vuelve a mover
	//liampiar bits
	IN R19, PORTD	//lee valor actual del puerto
	ANDI R19, 0b11000011	//borra los bits 2, 3, 4, 5
	OR R19, temp	//inserta nuevo valor del contador en los bits
	OUT PORTD, R19	//actualiza el puerto D

	RJMP MAIN_LOOP	//repite el ciclo sin fin
/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines

/****************************************/