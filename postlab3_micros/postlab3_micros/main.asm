/*
* postlab3_micros.asm
*
* Creado: 27/02/2026
* Autor : Jaqueline Michelle González Cotto
* Descripción: contador de 4 bits con displays en conteo con multiplexeado
*			
*/

/****************************************/ 
// Encabezado  
/****************************************/ 

.include "M328PDEF.inc"      // Incluir definiciones del microcontrolador ATmega328P

.dseg 						// Inicio del segmento de datos
.org    SRAM_START 			// Ubicar variables desde el inicio de SRAM

VAL_LEDS:		.BYTE 1		// Variable que almacena el valor actual mostrado en LEDs
DISP_UNI:		.BYTE 1		// Variable para el dígito de unidades
DISP_DEC:		.BYTE 1		// Variable para el dígito de decenas
SEL_DISPLAY:	.BYTE 1		// Indica qué display está activo
TICKS_1S:		.BYTE 1		// Contador que acumula interrupciones hasta 1 segundo
FLAG_INC:		.BYTE 1		// Bandera que indica incremento por botón
FLAG_DEC:		.BYTE 1		// Bandera que indica decremento por botón

.cseg 						// Inicio del segmento de código
.org 0x0000 					// Dirección del vector de reset

JMP		INIT_STACK				// Saltar a inicialización de pila
.ORG	0x0008					// Dirección del vector PCINT1
JMP		ISR_BUTTONS				// Saltar a rutina de botones
.ORG	0x001C					// Dirección del vector Timer0 Compare A
JMP		ISR_TIMER0				// Saltar a rutina del temporizador

/****************************************/ 	// Separador visual

INIT_STACK:						// Configuración inicial del stack
	LDI     R16, LOW(RAMEND)	// Cargar parte baja de RAMEND
	OUT     SPL, R16			// Configurar Stack Pointer Low
	LDI     R16, HIGH(RAMEND)	// Cargar parte alta de RAMEND
	OUT     SPH, R16			// Configurar Stack Pointer High

/****************************************/ 	// Separador visual

MCU_INIT:						// Inicio de configuración general
    
	LDI		R16, (1 << CLKPCE)	// Habilitar cambio de prescaler
	STS		CLKPR, R16			// Escribir en registro CLKPR				
	LDI		R16, 0b00000100		// Seleccionar división por 16
	STS		CLKPR, R16			// Establecer nueva frecuencia				

	LDI		R16, 0x00			// Preparar valor cero
	STS		UCSR0B, R16			// Desactivar comunicación serial

	LDI		R16, 0b00001111		// Configurar PB0-PB3 como salida
	OUT		DDRB, R16			// Aplicar configuración al puerto B
	LDI		R16, 0b00000000		// Inicializar LEDs apagados
	OUT		PORTB, R16			// Escribir en puerto B

	LDI		R16, 0b01111111		// Configurar pines del display como salida
	OUT		DDRD, R16			// Aplicar dirección al puerto D
	LDI		R16, 0b00000000		// Apagar todos los segmentos
	OUT		PORTD, R16			// Enviar valor al puerto D
	LDI		R16, 0x00			// Cargar valor inicial
	STS		DISP_UNI, R16		// Inicializar unidades		
	CALL	UPDATE_DISPLAY		// Actualizar display con valor inicial

	LDI		R16, 0b00001100		// Configurar PC2-PC3 como salida
	OUT		DDRC, R16			// Aplicar configuración a puerto C
	LDI		R16, 0b00001011		// Activar resistencias pull-up y selección
	OUT		PORTC, R16			// Escribir configuración en puerto C

	LDI		R16, (1 << PCIE1)	// Habilitar interrupciones PCINT grupo 1
	STS		PCICR, R16			// Guardar configuración

	LDI		R16, (1 << PCINT8) | (1 << PCINT9)	// Activar PC0 y PC1
	STS		PCMSK1, R16			// Aplicar máscara de interrupción

	CALL	CONFIG_TIMER0		// Configurar temporizador 0

	LDI		R16, 0x00			// Preparar valor cero
	STS		VAL_LEDS, R16		// Inicializar LEDs
	STS		TICKS_1S, R16		// Reiniciar contador de tiempo
	STS		FLAG_INC, R16		// Limpiar bandera incremento
	STS		FLAG_DEC, R16		// Limpiar bandera decremento

	LDI		R16, 0				// Cargar cero
	STS		SEL_DISPLAY, R16	// Iniciar con primer display
	
	SEI							// Habilitar interrupciones globales

MAIN_LOOP:						// Bucle principal del programa
	
	LDS		R16, SEL_DISPLAY	// Leer display seleccionado
	CPI		R16, 1				// Comparar si es igual a 1
	BREQ	SHOW_UNITS			// Si es 1 ir a unidades

	SBI		PORTC, PC2			// Activar decenas
	CBI		PORTC, PC3			// Desactivar unidades
	RJMP	END_SELECT			// Saltar al final de selección

SHOW_UNITS:						// Etiqueta para unidades
	SBI		PORTC, PC3			// Activar unidades
	CBI		PORTC, PC2			// Desactivar decenas

END_SELECT:						// Fin selección display
	CALL	UPDATE_DISPLAY		// Refrescar segmentos

	LDS		R16, TICKS_1S		// Leer contador de tiempo
	CPI		R16, 100			// Verificar si llegó a 100
	BRNE	CHECK_BUTTONS		// Si no, revisar botones
	
	LDI		R16, 0x00			// Reiniciar contador
	STS		TICKS_1S, R16		// Guardar valor reiniciado

	LDS		R16, DISP_UNI		// Leer unidades
	LDS		R17, DISP_DEC		// Leer decenas

	INC		R16					// Incrementar unidades
	CPI		R16, 10				// Verificar si llegó a 10
	BRNE	STORE_VALUES		// Si no, guardar

	LDI		R16, 0				// Reiniciar unidades				
	INC		R17					// Incrementar decenas
	CPI		R17, 6				// Verificar límite de decenas
	BRNE	STORE_VALUES		// Si no, guardar
	LDI		R17, 0				// Reiniciar decenas

STORE_VALUES:					// Guardar nuevos valores
	STS		DISP_UNI, R16		// Actualizar unidades
	STS		DISP_DEC, R17		// Actualizar decenas
	
	CALL	UPDATE_DISPLAY		// Refrescar display

CHECK_BUTTONS:					// Revisar botón incremento
	LDS		R16, FLAG_INC		// Leer bandera
	CPI		R16, 1				// Comparar
	BRNE	CHECK_DECREMENT		// Si no está activa

	LDS		R16, VAL_LEDS		// Leer valor LEDs
	INC		R16					// Incrementar
	ANDI	R16, 0b00001111		// Limitar a 4 bits
	STS		VAL_LEDS, R16		// Guardar nuevo valor
	OUT		PORTB, R16			// Mostrar en puerto

	LDI		R16, 0x00			// Limpiar bandera
	STS		FLAG_INC, R16		// Guardar limpieza

CHECK_DECREMENT:				// Revisar botón decremento
	LDS		R16, FLAG_DEC		// Leer bandera
	CPI		R16, 1				// Comparar
	BRNE	MAIN_LOOP			// Si no, volver al inicio

	LDS		R16, VAL_LEDS		// Leer LEDs
	DEC		R16					// Decrementar
	ANDI	R16, 0b00001111		// Mantener 4 bits
	STS		VAL_LEDS, R16		// Guardar valor
	OUT		PORTB, R16			// Mostrar en puerto

	LDI		R16, 0x00			// Limpiar bandera
	STS		FLAG_DEC, R16		// Guardar limpieza

    RJMP    MAIN_LOOP			// Repetir ciclo principal

/****************************************/

CONFIG_TIMER0:					// Configuración del Timer0
	LDI		R16, (1 << WGM01)	// Activar modo CTC
	OUT		TCCR0A, R16		// Configurar registro A

	LDI		R16, (0 << CS02) | (1 << CS01) | (1 << CS00)	// Prescaler 64
	OUT		TCCR0B, R16		// Configurar registro B
	
	LDI		R16, 156			// Valor de comparación
	OUT		OCR0A, R16			// Cargar comparación

	LDI		R16, (1 << OCIE0A)	// Habilitar interrupción por comparación
	STS		TIMSK0, R16		// Guardar configuración
	
	LDI		R16, 0x00			// Reiniciar contador
	OUT		TCNT0, R16		// Aplicar reset

	RET						// Regresar

UPDATE_DISPLAY:					// Subrutina actualización display
	PUSH	R16					// Guardar R16
	PUSH	R17					// Guardar R17
	PUSH	ZL					// Guardar ZL
	PUSH	ZH					// Guardar ZH

	LDS		R20, SEL_DISPLAY	// Leer selector
	CPI		R20, 0				// Comparar con 0
	BREQ	LOAD_UNITS			// Si es 0 cargar unidades

	LDS		R16, DISP_DEC		// Cargar decenas
	RJMP	LOAD_DONE			// Saltar

LOAD_UNITS:						// Cargar unidades
	LDS		R16, DISP_UNI		// Leer valor unidades

LOAD_DONE:						// Calcular dirección tabla
	LSL		R16					// Multiplicar por 2
	LDI		ZL, LOW(TABLE7SEG*2)	// Dirección baja tabla
	LDI		ZH, HIGH(TABLE7SEG*2)	// Dirección alta tabla
	CLR		R17					// Limpiar R17			
	ADD		ZL, R16				// Sumar desplazamiento		
	ADC		ZH, R17				// Ajustar con acarreo		
	LPM		R16, Z				// Leer patrón

	OUT		PORTD, R16			// Enviar a display

	POP		ZH					// Restaurar ZH
	POP		ZL					// Restaurar ZL
	POP		R17					// Restaurar R17
	POP		R16					// Restaurar R16
	RET							// Retornar

/****************************************/ 	// Separador visual

ISR_TIMER0:						// Rutina interrupción Timer0

	PUSH	R16					// Guardar R16
	PUSH	R17					// Guardar R17
	IN		R16, SREG			// Guardar estado
	PUSH	R16					// Apilar estado

	LDS		R16, TICKS_1S		// Leer contador
	INC		R16					// Incrementar
	STS		TICKS_1S, R16		// Guardar valor

	LDS		R16, SEL_DISPLAY	// Leer selector
	LDI		R17, 1				// Cargar 1
	EOR		R16, R17			// Alternar bit
	STS		SEL_DISPLAY, R16	// Guardar cambio

	POP		R16					// Recuperar estado
	OUT		SREG, R16			// Restaurar SREG
	POP		R17					// Restaurar R17
	POP		R16					// Restaurar R16

	RETI						// Retornar de interrupción

ISR_BUTTONS:						// Rutina interrupción botones

	PUSH	R16								
	PUSH	R17	
	IN		R16, SREG					
	PUSH	R16	
	
	IN		R17, PINC					
	SBRS	R17, PC0					
	RJMP	ACTIVATE_INC
	RJMP	CHECK_SECOND
	
ACTIVATE_INC:
	LDI		R16, 1
	STS		FLAG_INC, R16					

CHECK_SECOND:
	SBRS	R17, PC1					
	RJMP	ACTIVATE_DEC
	RJMP	EXIT_ISR

ACTIVATE_DEC:
	LDI		R16, 1
	STS		FLAG_DEC, R16					

EXIT_ISR:
	POP		R16
	OUT		SREG, R16					
	POP		R17
	POP		R16

	RETI

/****************************************/ 

TABLE7SEG:
    .dw 0x3F	// Código para mostrar 0 
    .dw 0x0A	// Código para mostrar 1 
    .dw 0x5D	// Código para mostrar 2 
    .dw 0x5B	// Código para mostrar 3 
    .dw 0x6A	// Código para mostrar 4
    .dw 0x73	// Código para mostrar 5
    .dw 0x77	// Código para mostrar 6 
    .dw 0x1A	// Código para mostrar 7
    .dw 0x7F	// Código para mostrar 8 
    .dw 0x7A	// Código para mostrar 9