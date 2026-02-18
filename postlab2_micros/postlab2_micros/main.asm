/* 
* postlab2.asm 
*
* Creado: 18/02/2026
* Autor : Jaqueline Michelle González Cotto 
* Descripción: Display 7 segmentos (ÁNODO COMÚN) con contador y alarma
*/
// Encabezado (Definición de Registros, Variables y Constantes)
.include "M328PDEF.inc"     // Incluye las definiciones internas del microcontrolador ATmega328P
.dseg                     
.org SRAM_START             // Indica el inicio de la memoria SRAM
//variable_name:     .byte   1   // Espacio reservado en memoria para una variable de 1 byte

//definiciones
.def TEMP          = R16    // Registro general
.def CONTADOR_BITS = R17    // Guarda el valor actual del contador (0–15)
.def CONTADOR_SEG  = R22    // Contador temporización del display
.def ESTADO_BOT    = R18    // Guarda el estado actual de los botones
.def ANTERIOR_B1   = R19    // Guarda el estado anterior del botón 1
.def ANTERIOR_B2   = R20    // Guarda el estado anterior del botón 2
.def OVERFLOW1     = R23    // Cuenta overflow del Timer0
.def CONT_100MS    = R24    // Cuenta intervalos aproximados de 100 ms

.equ B1  = 3                // Botón 1 conectado al pin PB3
.equ B2  = 4                // Botón 2 conectado al pin PB4
.equ LED = 4				// LED conectado al pin PC4

.cseg                        
.org 0x0000                  
    RJMP SETUP               

//tabla hexa de 0-F
HEXA:                        
    .db 0x3F,0x06,0x5B,0x4F
    .db 0x66,0x6D,0x7D,0x07
    .db 0x7F,0x6F,0x77,0x7C
    .db 0x39,0x5E,0x79,0x71

// Configuración MCU
SETUP:
    // Configuración de la pila
    LDI R16, LOW(RAMEND)     
    OUT SPL, R16             
    LDI R16, HIGH(RAMEND)    
    OUT SPH, R16          

    CLR R1                   // Limpia R1

    LDI TEMP, (1<<0)|(1<<1)  // PB0 y PB1 como salida
    OUT DDRB, TEMP
    LDI TEMP, (1<<B1)|(1<<B2)//resistencias pull-up en PB3 y PB4
    OUT PORTB, TEMP

    LDI R25, 0x00
    STS UCSR0B, R25          // Deshabilita comunicación serial

    LDI TEMP, 0b11111100
    OUT DDRD, TEMP           // Configura PD2–PD7 como salida para display

    LDI TEMP, 0b00011111
    OUT DDRC, TEMP           // Configura PC0–PC4 como salida para leds
    CLR TEMP
    OUT PORTC, TEMP          // Inicia PORTC en 0

    LDI TEMP, (1<<CS02)|(1<<CS00)
    OUT TCCR0B, TEMP         // Configura Timer0 con prescaler 1024
    LDI TEMP, 0
    OUT TCCR0A, TEMP         // Timer0 en modo normal 

    LDI TEMP, 0
    OUT TCNT0, TEMP          // Inicia contador del timer en 0

    CLR CONTADOR_BITS        // Inicia contador principal en 0
    CLR CONTADOR_SEG         // Inicia contador secundario
    CLR OVERFLOW1            // Reinicia contador de overflows
    CLR CONT_100MS           // Reinicia contador de 100 ms

    LDI ANTERIOR_B1, (1<<B1) // Inicializa estado anterior del botón 1
    LDI ANTERIOR_B2, (1<<B2) // Inicializa estado anterior del botón 2

    RCALL NUMEROS            // Muestra el número inicial en el display

/****************************************/
// Loop Infinito
MAIN_LOOP:

    IN TEMP, TIFR0           // Lee bandera del Timer0
    SBRS TEMP, TOV0          // Si no hubo overflow, salta
    RJMP CHECK_BUTTONS

    LDI TEMP, (1<<TOV0)
    OUT TIFR0, TEMP          // Limpia bandera de overflow

    INC OVERFLOW1            // Incrementa contador de overflows
    CPI OVERFLOW1, 6
    BRNE CHECK_BUTTONS       // Espera 6 overflows

    CLR OVERFLOW1

    INC CONT_100MS           // Incrementa contador de 100ms
    CPI CONT_100MS, 10
    BRNE CHECK_BUTTONS       // Espera hasta 10 (1 segundo)

    CLR CONT_100MS

    INC CONTADOR_SEG         // Incrementa contador de segundos
    ANDI CONTADOR_SEG, 0x0F  // Limita de 0 a 15

    IN TEMP, PORTC
    ANDI TEMP, 0b11100000    // Conserva bits altos
    OR TEMP, CONTADOR_SEG    // Actualiza bits bajos con contador
    OUT PORTC, TEMP

    CP CONTADOR_SEG, CONTADOR_BITS
    BRNE CHECK_BUTTONS       // Si no son iguales, continúa

    CLR CONTADOR_SEG         // Reinicia contador si coinciden

    IN TEMP, PORTC
    ANDI TEMP, 0b11100000
    OUT PORTC, TEMP          // Limpia bits bajos

    LDI TEMP, (1<<LED)
    OUT PINC, TEMP           // Cambia estado del LED

CHECK_BUTTONS:
    RCALL REVISA_BOTONES     // Revisa si algún botón fue presionado
    RJMP MAIN_LOOP           // Repite ciclo infinito

REVISA_BOTONES:

    IN ESTADO_BOT, PINB      // Lee estado actual de los botones

    SBRS ANTERIOR_B1, B1   
    RJMP NO_B1               // Si antes estaba en 0, no hace nada
    SBRC ESTADO_BOT, B1 
    RJMP NO_B1               // Si aún está en 1, no hay pulsación

    RCALL DELAY_ANTIREBOTE   // Espera para antirebote

    IN ESTADO_BOT, PINB
    SBRC ESTADO_BOT, B1
    RJMP NO_B1               // Verifica nuevamente
    RCALL INCREMENTO         // Incrementa contador

NO_B1:

    SBRS ANTERIOR_B2, B2
    RJMP NO_B2
    SBRC ESTADO_BOT, B2
    RJMP NO_B2
    RCALL DELAY_ANTIREBOTE
    IN ESTADO_BOT, PINB
    SBRC ESTADO_BOT, B2
    RJMP NO_B2
    RCALL DECREMENTO         // Decrementa contador

NO_B2:

    MOV ANTERIOR_B1, ESTADO_BOT // Guarda estado actual como anterior
    MOV ANTERIOR_B2, ESTADO_BOT
    RET

INCREMENTO:
    INC CONTADOR_BITS        // Aumenta valor del contador
    ANDI CONTADOR_BITS, 0x0F // Limita entre 0 y 15
    RCALL NUMEROS            // Actualiza display
    RET

DECREMENTO:
    TST CONTADOR_BITS        // Verifica si es 0
    BRNE OK_DEC
    LDI CONTADOR_BITS, 0x10  // Si es 0, prepara para volver a 15
OK_DEC:
    DEC CONTADOR_BITS        // Decrementa
    ANDI CONTADOR_BITS, 0x0F // Limita entre 0 y 15
    RCALL NUMEROS            // Actualiza display
    RET

NUMEROS:
    LDI ZH, HIGH(HEXA<<1)    // Carga dirección alta de la tabla
    LDI ZL, LOW(HEXA<<1)     // Carga dirección baja

    ADD ZL, CONTADOR_BITS    // Suma índice del número
    ADC ZH, R1

    LPM TEMP, Z              // Lee valor de tabla

    COM TEMP                 // Invierte bits (porque es ánodo común)

    MOV R25, TEMP
    ANDI R25, 0b11111100
    OUT PORTD, R25           // Envía segmentos a PORTD

    IN R26, PORTB
    ANDI R26, 0b11111100
    MOV R25, TEMP
    ANDI R25, 0b00000011
    OR R26, R25
    OUT PORTB, R26           // Envía bits restantes a PORTB

    RET

DELAY_ANTIREBOTE:
    LDI R28, 50              // Bucle externo
LOOP_A:
    LDI R29, 200             // Bucle interno
LOOP_B:
    NOP                      // No operación
    DEC R29
    BRNE LOOP_B
    DEC R28
    BRNE LOOP_A
    RET                      // Fin del retardo
