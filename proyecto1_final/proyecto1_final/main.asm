/*
* Proyecto1_micros.asm
* Creado: 27/02/2026
* Autor: Jaqueline Michelle González Cotto
* Descripción: Reloj con alarma y calendario, con diferentes modos
*/

.include "M328PDEF.inc"

// ==========================================
// DEFINICION DE REGISTROS (Asignación de variables a registros del CPU)
// ==========================================
// Registros para la Hora
.def MIN_U          = R18        // Minutos Unidades (0-9)
.def MIN_D          = R19        // Minutos Decenas (0-5)
.def HOR_U          = R20        // Horas Unidades (0-9)
.def HOR_D          = R21        // Horas Decenas (0-2)

// Registros bajos para Fecha
.def DIA_U          = R6         // Días Unidades (0-9)
.def DIA_D          = R7         // Días Decenas (0-3)
.def MES_U          = R8         // Meses Unidades (0-9)
.def MES_D          = R9         // Meses Decenas (0-1)

// Registros para la Alarma (Despertador)
.def ALM_MIN_U      = R10        // Alarma Minutos Unidades
.def ALM_MIN_D      = R11        // Alarma Minutos Decenas
.def ALM_HOR_U      = R12        // Alarma Horas Unidades
.def ALM_HOR_D      = R13        // Alarma Horas Decenas

// Registros de Control y Estados
.def MITAD_SEG      = R14        // Contador para lograr 1 segundo (cuenta 2 desbordamientos de 500ms)
.def CONTEO_SEG     = R22        // Contador de Segundos (0-59)
.def FLAG_PUNTO     = R23        // Banderas múltiples: Bit 0=Parpadeo del Punto/LED, Bit 1=Alarma Activa
.def MUX_ESTADO     = R24        // Estado actual del multiplexado (0 a 3, para los 4 displays)
.def ESTADO_SIS     = R25        // Modo del sistema (0=Hora, 1=Fecha, 2=Conf Hora, 3=Conf Fecha, 4=Conf Alarma)
.def TEMP_ESTADO    = R17        // Registro temporal para mover datos al display y cálculos rápidos

// Constantes
.equ TMR1_VAL       = 57723      // Valor de precarga del Timer1 para generar 500ms (con prescaler 1024)
.equ LIMITE_MODOS   = 5          // Cantidad máxima de modos del sistema (0 al 4)

.cseg
// ==========================================
// VECTOR DE INTERRUPCIONES
// ==========================================
.org 0x0000
    JMP INICIO_CONF                     // Vector de Reset: Salta a la configuración inicial

.org PCI0addr       
    JMP INT_BOTONES_0                   // Interrupción por cambio de estado en pines PCINT0 (Botones PB0-PB3)

.org PCI1addr
    JMP INT_BOTONES_1                   // Interrupción por cambio de estado en pines PCINT1 (Botón de Modos en PC4)

.org 0x001A
    JMP INT_TMR1_OVF                    // Interrupción por desbordamiento del Timer1 (Control de tiempo base 500ms)

.org 0x0020
    JMP INT_TMR0_OVF                    // Interrupción por desbordamiento del Timer0 (Multiplexado de displays)

// ==========================================
// --- TABLA 7 SEGMENTOS (ÁNODO COMÚN) ---
// ==========================================
// Al ser Ánodo Común, un '0' enciende el segmento y un '1' lo apaga.
TABLA_7SEG:
.db 0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8 // Códigos para los números 0 al 7
.db 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E // Códigos para los números 8 al F

// ==========================================
// CONFIGURACIÓN INICIAL (SETUP)
// ==========================================
INICIO_CONF:
    // Inicialización del Stack Pointer (Puntero de Pila) al final de la RAM
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    // Deshabilita el transmisor/receptor UART (por si acaso interfieren con pines)
    LDI R16, 0x00
    STS UCSR0B, R16
    
    // Configura el Puerto D completo como salida (Segmentos del Display)
    LDI R16, 0xFF
    OUT DDRD, R16                   
    OUT PORTD, R16                  // Inicia con todos los segmentos apagados (5V)

    // --- NUEVA CONFIGURACIÓN DE PUERTO C ---
    // PC0-PC3 como salidas (Transistores PNP de los displays)
    // PC4 como entrada (Botón de Modo)
    // PC5 como salida (LED Extra indicadora de configuración)
    LDI R16, 0b0010_1111                    
    OUT DDRC, R16                   
    
    // Al ser transistores PNP, un 1 lógico los APAGA. 
    // Habilita la resistencia Pull-up en PC4. PC5 inicia en 0 (apagado).
    LDI R16, 0b0001_1111
    OUT PORTC, R16

    // Configura PB4 (Buzzer) y PB5 (LED original D13) como salidas
    // PB0-PB3 como entradas (Botones de ajuste)
    LDI R16, 0b0011_0000            
    OUT DDRB, R16                   
    LDI R16, 0b0000_1111            // Habilita resistencias Pull-up para PB0-PB3
    OUT PORTB, R16

    // Limpia las variables de la hora, inicia en 00:00
    CLR MIN_U
    CLR MIN_D
    CLR HOR_U
    CLR HOR_D

    // Inicia la fecha en el 01 del 01 (1 de enero)
    LDI R16, 0
    MOV DIA_D, R16
    MOV MES_D, R16
    LDI R16, 1
    MOV DIA_U, R16
    MOV MES_U, R16

    // Limpia la alarma, inicia en 00:00
    CLR ALM_MIN_U
    CLR ALM_MIN_D
    CLR ALM_HOR_U
    CLR ALM_HOR_D

    // Reinicia banderas y contadores
    CLR MUX_ESTADO
    CLR CONTEO_SEG
    CLR MITAD_SEG
    CLR FLAG_PUNTO
    CLR ESTADO_SIS

    // Habilita interrupciones por cambio de pin (PCINT0 y PCINT1)
    LDI R16, (1 << PCIE1) | (1 << PCIE0)
    STS PCICR, R16
    // Máscaras: Habilita el pin PCINT12 (PC4) y los pines PCINT0 a PCINT3 (PB0 a PB3)
    LDI R16, (1 << PCINT12)
    STS PCMSK1, R16
    LDI R16, 0x0F
    STS PCMSK0, R16

    // Llama a las subrutinas que configuran los timers
    CALL CONF_TIMER0
    CALL CONF_TIMER1
    SEI                             // Habilita las Interrupciones Globales

// ==========================================
// LOOP PRINCIPAL (Máquina de estados)
// ==========================================
CICLO_PRINCIPAL:
    ; --- LÓGICA DE LA LED EXTRA DE CONFIGURACIÓN (PC5 / A5) ---
    CPI ESTADO_SIS, 2               // Compara si estamos en un modo de configuración (>= 2)
    BRLO APAGAR_LED_EXTRA           ; Si es 0 o 1 (menor a 2), salta para mantener la LED extra apagada
    
    ; Si ESTADO_SIS es 2, 3 o 4 (Configuración), la LED en PC5 parpadea al ritmo de FLAG_PUNTO bit 0
    SBRC FLAG_PUNTO, 0
    SBI PORTC, PC5                  ; Enciende la LED extra en PC5 (Pin A5)
    SBRS FLAG_PUNTO, 0
    CBI PORTC, PC5                  ; Apaga la LED extra en PC5
    RJMP REVISAR_ESTADOS

APAGAR_LED_EXTRA:
    CBI PORTC, PC5                  ; Apaga la LED extra si no estamos configurando

REVISAR_ESTADOS:
    // Salta a la etiqueta correspondiente según el modo del sistema (ESTADO_SIS)
    CPI ESTADO_SIS, 0
    BREQ VER_RELOJ
    CPI ESTADO_SIS, 1
    BREQ VER_CALENDARIO
    CPI ESTADO_SIS, 2
    BREQ CONFIG_RELOJ
    CPI ESTADO_SIS, 3
    BREQ CONFIG_CALENDARIO
    CPI ESTADO_SIS, 4
    BREQ CONFIG_DESPERTADOR
    RJMP CICLO_PRINCIPAL

VER_RELOJ:
    CBI PORTB, PB5                  ; En modo reloj, apaga el LED original (D13)
    RJMP CICLO_PRINCIPAL

VER_CALENDARIO:
    SBI PORTB, PB5                  ; En modo calendario, enciende el LED (D13)
    RJMP CICLO_PRINCIPAL

CONFIG_RELOJ:
    SBI PORTB, PB5                  ; En modo config hora, enciende el LED (D13)
    RJMP CICLO_PRINCIPAL

CONFIG_CALENDARIO:
    SBI PORTB, PB5                  ; En modo config fecha, enciende el LED (D13)
    RJMP CICLO_PRINCIPAL

CONFIG_DESPERTADOR:
    ; En modo config alarma, el LED original (D13) parpadea
    SBRC FLAG_PUNTO, 0              
    SBI PORTB, PB5
    SBRS FLAG_PUNTO, 0
    CBI PORTB, PB5
    RJMP CICLO_PRINCIPAL

// ==========================================
// INTERRUPCIONES PCINT (BOTONES)
// ==========================================
// Esta interrupción se dispara cuando presionas los botones de ajuste (PB0, PB1, PB2, PB3)
INT_BOTONES_0:
    PUSH R16                        // Guarda el registro R16 en la pila
    IN R16, SREG                    // Guarda el registro de estado (SREG)
    PUSH R16
    
    // Si la alarma está sonando y presionas CUALQUIER botón, apaga la alarma (Limpia el Bit 1)
    ANDI FLAG_PUNTO, 0b1111_1101     
    CBI PORTB, PB4                  // Apaga el zumbador/buzzer físicamente
    
    // Solo permite ajustar valores si estamos en modos de configuración (ESTADO_SIS >= 2)
    CPI ESTADO_SIS, 2
    BRSH SEGUIR_BOTONES_0
    JMP FIN_INT_BOTONES_0           // Si no estamos configurando, sale de la interrupción

SEGUIR_BOTONES_0:
    // Verifica qué botón fue presionado (Pin en 0 lógico por el pull-up)
    SBIS PINB, PB3
    RJMP PRESIONADO_PB3
    SBIS PINB, PB0
    RJMP PRESIONADO_PB0
    SBIS PINB, PB1
    RJMP PRESIONADO_PB1
    SBIS PINB, PB2
    RJMP PRESIONADO_PB2
    RJMP FIN_INT_BOTONES_0

PRESIONADO_PB3:
    RCALL ANTIREBOTE_PB3            // Llama a la rutina de retardo para evitar rebotes
    // Verifica en qué modo de configuración estamos para saber qué incrementar
    CPI ESTADO_SIS, 2
    BREQ EJECUTAR_INC_MIN           // Modo 2: Incrementa minutos
    CPI ESTADO_SIS, 3
    BREQ EJECUTAR_INC_MES           // Modo 3: Incrementa mes
    CPI ESTADO_SIS, 4
    BREQ EJECUTAR_ALM_INC_MIN       // Modo 4: Incrementa minutos alarma
    RJMP FIN_INT_BOTONES_0

// Saltos puente para ejecutar la matemática requerida y salir
EJECUTAR_INC_MIN: 
    RCALL INC_MINUTOS 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_INC_MES: 
    RCALL INC_MESES 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_ALM_INC_MIN: 
    RCALL ALM_INC_MIN 
    RJMP FIN_INT_BOTONES_0

PRESIONADO_PB0:
    RCALL ANTIREBOTE_PB0
    CPI ESTADO_SIS, 2
    BREQ EJECUTAR_DEC_MIN           // Modo 2: Decrementa minutos
    CPI ESTADO_SIS, 3
    BREQ EJECUTAR_DEC_MES           // Modo 3: Decrementa mes
    CPI ESTADO_SIS, 4
    BREQ EJECUTAR_ALM_DEC_MIN       // Modo 4: Decrementa minutos alarma
    RJMP FIN_INT_BOTONES_0

EJECUTAR_DEC_MIN: 
    RCALL DEC_MINUTOS 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_DEC_MES: 
    RCALL DEC_MESES 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_ALM_DEC_MIN: 
    RCALL ALM_DEC_MIN 
    RJMP FIN_INT_BOTONES_0

PRESIONADO_PB1:
    RCALL ANTIREBOTE_PB1
    CPI ESTADO_SIS, 2
    BREQ EJECUTAR_INC_HOR           // Modo 2: Incrementa horas
    CPI ESTADO_SIS, 3
    BREQ EJECUTAR_INC_DIA           // Modo 3: Incrementa días
    CPI ESTADO_SIS, 4
    BREQ EJECUTAR_ALM_INC_HOR       // Modo 4: Incrementa horas alarma
    RJMP FIN_INT_BOTONES_0

EJECUTAR_INC_HOR: 
    RCALL INC_HORAS 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_INC_DIA: 
    RCALL INC_DIAS 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_ALM_INC_HOR: 
    RCALL ALM_INC_HORAS 
    RJMP FIN_INT_BOTONES_0

PRESIONADO_PB2:
    RCALL ANTIREBOTE_PB2
    CPI ESTADO_SIS, 2
    BREQ EJECUTAR_DEC_HOR           // Modo 2: Decrementa horas
    CPI ESTADO_SIS, 3
    BREQ EJECUTAR_DEC_DIA           // Modo 3: Decrementa días
    CPI ESTADO_SIS, 4
    BREQ EJECUTAR_ALM_DEC_HOR       // Modo 4: Decrementa horas alarma
    RJMP FIN_INT_BOTONES_0

EJECUTAR_DEC_HOR: 
    RCALL DEC_HORAS 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_DEC_DIA: 
    RCALL DEC_DIAS 
    RJMP FIN_INT_BOTONES_0
EJECUTAR_ALM_DEC_HOR: 
    RCALL ALM_DEC_HORAS 
    RJMP FIN_INT_BOTONES_0

FIN_INT_BOTONES_0:
    LDI R16, (1<<PCIF0)             // Limpia la bandera de interrupción PCINT0
    OUT PCIFR, R16
    POP R16                         // Restaura SREG y registros
    OUT SREG, R16
    POP R16
    RETI

// Esta interrupción se dispara al presionar el Botón de Modo (PC4)
INT_BOTONES_1:
    PUSH R16
    IN R16, SREG
    PUSH R16

    SBIC PINC, PC4                  // Si el pin soltó el botón antes de tiempo, ignora
    RJMP FIN_CAMBIO_ESTADO
    RCALL ANTIREBOTE_PC4            // Espera a que el usuario suelte el botón de modo                 

    INC ESTADO_SIS                  // Cambia al siguiente modo
    CPI ESTADO_SIS, LIMITE_MODOS    // Si llegamos a 5 (límite), reinicia a 0
    BRLO RESET_DESPERTADOR        
    CLR ESTADO_SIS

RESET_DESPERTADOR:
    // Asegurarse de apagar la alarma si se cambia de modo
    ANDI FLAG_PUNTO, 0b1111_1101     
    CBI PORTB, PB4

FIN_CAMBIO_ESTADO:
    LDI R16, (1<<PCIF1)             // Limpia la bandera de interrupción PCINT1
    OUT PCIFR, R16
    POP R16
    OUT SREG, R16
    POP R16
    RETI

// ==========================================
// INTERRUPCIÓN MULTIPLEXADO (TIMER 0)
// ==========================================
// Se ejecuta muy rápido (Timer0 OVF) para encender un dígito a la vez, creando la ilusión de que los 4 están prendidos
INT_TMR0_OVF:
    PUSH R16                        // Respaldo de registros
    PUSH R17
    PUSH R30              
    PUSH R31              
    IN R16, SREG
    PUSH R16
    
    LDI R16, 6                      // Recarga el Timer0 para ajustar la frecuencia de refresco
    OUT TCNT0, R16
    
    // Apaga los 4 transistores PNP (1 = apagado) para evitar el "fantasmeo" de números
    SBI PORTC, PC0
    SBI PORTC, PC1
    SBI PORTC, PC2
    SBI PORTC, PC3
    
    INC MUX_ESTADO                  // Incrementa el estado del multiplexor (0, 1, 2, 3)
    ANDI MUX_ESTADO, 0x03           // Máscara para que solo cuente hasta 3 (vuelve a 0)
    
    // Elige qué mostrar en los displays según el Modo del Sistema
    CPI ESTADO_SIS, 1                      
    BREQ DISP_FECHA
    CPI ESTADO_SIS, 3
    BREQ DISP_FECHA
    CPI ESTADO_SIS, 4
    BREQ DISP_DESPERTADOR

DISP_HORA:
    // Muestra la Hora Normal
    CPI MUX_ESTADO, 0
    BREQ DIG0_H                     // Dígito 0: Horas Decenas
    CPI MUX_ESTADO, 1
    BREQ DIG1_H                     // Dígito 1: Horas Unidades
    CPI MUX_ESTADO, 2
    BREQ DIG2_H                     // Dígito 2: Minutos Decenas
    // Si no es 0, 1 o 2, es el 3: Minutos Unidades
    CBI PORTC, PC3                  // Enciende transistor del 4to display
    MOV R17, MIN_U                  // Carga el valor a mostrar en R17
    RJMP MANDAR_A_DISPLAY

DIG0_H: 
    CBI PORTC, PC0
    MOV R17, HOR_D
    RJMP MANDAR_A_DISPLAY

DIG1_H: 
    CBI PORTC, PC1
    MOV R17, HOR_U
    RJMP MANDAR_A_DISPLAY

DIG2_H: 
    CBI PORTC, PC2
    MOV R17, MIN_D
    RJMP MANDAR_A_DISPLAY

DISP_FECHA:
    // Muestra la Fecha (Día y Mes)
    CPI MUX_ESTADO, 0
    BREQ DIG0_F
    CPI MUX_ESTADO, 1
    BREQ DIG1_F
    CPI MUX_ESTADO, 2
    BREQ DIG2_F
    CBI PORTC, PC3
    MOV R17, MES_U
    RJMP MANDAR_A_DISPLAY

DIG0_F: 
    CBI PORTC, PC0
    MOV R17, DIA_D
    RJMP MANDAR_A_DISPLAY

DIG1_F: 
    CBI PORTC, PC1
    MOV R17, DIA_U
    RJMP MANDAR_A_DISPLAY

DIG2_F: 
    CBI PORTC, PC2
    MOV R17, MES_D
    RJMP MANDAR_A_DISPLAY

DISP_DESPERTADOR:
    // Muestra la Hora de la Alarma configurada
    CPI MUX_ESTADO, 0
    BREQ DIG0_A
    CPI MUX_ESTADO, 1
    BREQ DIG1_A
    CPI MUX_ESTADO, 2
    BREQ DIG2_A
    CBI PORTC, PC3
    MOV R17, ALM_MIN_U
    RJMP MANDAR_A_DISPLAY

DIG0_A: 
    CBI PORTC, PC0
    MOV R17, ALM_HOR_D
    RJMP MANDAR_A_DISPLAY

DIG1_A: 
    CBI PORTC, PC1
    MOV R17, ALM_HOR_U
    RJMP MANDAR_A_DISPLAY

DIG2_A: 
    CBI PORTC, PC2
    MOV R17, ALM_MIN_D

MANDAR_A_DISPLAY:
    // Traduce el número (0-9) a su equivalente en 7 segmentos usando el puntero Z
    LDI ZH, HIGH(TABLA_7SEG<<1)
    LDI ZL, LOW(TABLA_7SEG<<1)
    ADD ZL, R17                     // Suma el valor a mostrar (R17) a la dirección base
    LPM R17, Z                      // Carga el byte de la tabla de memoria flash a R17

    // LÓGICA DEL PUNTO DECIMAL (DP)
    // Parpadea cada segundo (depende del Bit 0 de FLAG_PUNTO)
    SBRC FLAG_PUNTO, 0              // Si el flag es 0, salta la siguiente línea
    ANDI R17, 0x7F                  // Enciende el punto decimal (Bit 7 en 0, ánodo común)
    SBRS FLAG_PUNTO, 0              // Si el flag es 1, salta la siguiente línea
    ORI R17, 0x80                   // Apaga el punto decimal (Bit 7 en 1)

    OUT PORTD, R17                  // Envía los segmentos formados al Puerto D
    
    // Restaura contexto y sale
    POP R16
    OUT SREG, R16
    POP R31                 
    POP R30                 
    POP R17
    POP R16
    RETI

// ==========================================
// INTERRUPCIÓN TIEMPO (TIMER 1) - 500ms
// ==========================================
// El "Corazón" del reloj. Se dispara exactamente 2 veces por segundo.
INT_TMR1_OVF:
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17              

    // Recarga el Timer1 para que la próxima interrupción ocurra en 500ms
    LDI R16, HIGH(TMR1_VAL)
    STS TCNT1H, R16
    LDI R16, LOW(TMR1_VAL)
    STS TCNT1L, R16

    // Alterna el Bit 0 de la bandera (Hace parpadear los dos puntos del reloj / DP)
    LDI R16, 0x01
    EOR FLAG_PUNTO, R16              

    INC MITAD_SEG                   // Incrementa el contador de medios segundos
    LDI R16, 2
    CP MITAD_SEG, R16               // ¿Ya pasaron 2 medios segundos (1 segundo completo)?
    BRLO GESTION_ZUMBADOR           // Si no, salta al control del buzzer
    
    // Si ya pasó 1 segundo:
    CLR MITAD_SEG
    INC CONTEO_SEG                  // Sumamos 1 segundo
    LDI R16, 60
    CP CONTEO_SEG, R16              // ¿Ya pasaron 60 segundos?

    BRLO CHECK_SONIDO_ALM           // Si no, revisa si debe sonar la alarma

    // Si ya pasaron 60 segundos:
    CLR CONTEO_SEG                 
    RCALL REFRESCAR_RELOJ_GLOBAL    // Llama a la rutina para actualizar minutos, horas y fecha

CHECK_SONIDO_ALM:
    // Solo evalúa disparar la alarma en el segundo 00 para que suene justo al empezar el minuto
    LDI R16, 0
    CP CONTEO_SEG, R16             
    BRNE GESTION_ZUMBADOR             
    
    // Compara la Hora actual VS la Hora de la Alarma
    CP MIN_U, ALM_MIN_U
    BRNE GESTION_ZUMBADOR
    CP MIN_D, ALM_MIN_D
    BRNE GESTION_ZUMBADOR
    CP HOR_U, ALM_HOR_U
    BRNE GESTION_ZUMBADOR
    CP HOR_D, ALM_HOR_D
    BRNE GESTION_ZUMBADOR
    
    // Si todo coincide, Activa el Bit 1 de la bandera (Alarma Disparada)
    ORI FLAG_PUNTO, 0b0000_0010

GESTION_ZUMBADOR:
    // Si la alarma NO está disparada, salta directo al final
    SBRS FLAG_PUNTO, 1               
    RJMP FIN_TIMER1               
    
    // Si está disparada, hace sonar el buzzer intermitentemente al ritmo del segundo (Bit 0)
    SBRC FLAG_PUNTO, 0               
    SBI PORTB, PB4                  // Enciende el buzzer
    SBRS FLAG_PUNTO, 0
    CBI PORTB, PB4                  // Apaga el buzzer

FIN_TIMER1:
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

// ==========================================
// FUNCIONES DE MATEMÁTICA Y AJUSTE
// ==========================================
// Incrementa los minutos de 00 a 59
INC_MINUTOS:
    INC MIN_U
    LDI R16, 10
    CP MIN_U, R16
    BRNE FIN_INC_MIN                // Si unidades llega a 10...
    CLR MIN_U                       // ... se reinicia a 0
    INC MIN_D                       // ... e incrementa las decenas
    LDI R16, 6
    CP MIN_D, R16
    BRNE FIN_INC_MIN                // Si decenas llega a 6 (60 mins)...
    CLR MIN_D                       // ... se reinicia a 0
FIN_INC_MIN:
    RET

// Decrementa los minutos de 59 a 00
DEC_MINUTOS:
    DEC MIN_U
    LDI R16, 255
    CP MIN_U, R16            
    BRNE FIN_DEC_MIN                // Si unidades baja de 0 (underflow a 255)...
    LDI R16, 9
    MOV MIN_U, R16                  // ... se pone en 9
    DEC MIN_D                       // ... y decrece las decenas
    LDI R16, 255
    CP MIN_D, R16
    BRNE FIN_DEC_MIN                // Si decenas baja de 0 (underflow a 255)...
    LDI R16, 5
    MOV MIN_D, R16                  // ... se pone en 5 (59 mins)
FIN_DEC_MIN:
    RET

// Incrementa las horas en formato 24H (00 a 23)
INC_HORAS:
    INC HOR_U
    LDI R16, 10
    CP HOR_U, R16
    BRNE CHEQUEO_24H_INC            // Si unidades llega a 10, pasa a 0 y suma decenas
    CLR HOR_U
    INC HOR_D
CHEQUEO_24H_INC:
    LDI R16, 2
    CP HOR_D, R16
    BRNE FIN_INC_HORAS
    LDI R16, 4
    CP HOR_U, R16
    BRNE FIN_INC_HORAS              // Si llega a 24 horas...
    CLR HOR_U                       // ... reinicia a 00
    CLR HOR_D
FIN_INC_HORAS:
    RET

// Decrementa las horas
DEC_HORAS:
    DEC HOR_U
    LDI R16, 255
    CP HOR_U, R16
    BRNE CHEQUEO_24H_DEC
    LDI R16, 9
    MOV HOR_U, R16
    DEC HOR_D
CHEQUEO_24H_DEC:
    LDI R16, 255
    CP HOR_D, R16                
    BRNE FIN_DEC_HORAS              // Si baja de 00 horas...
    LDI R16, 2
    MOV HOR_D, R16                 
    LDI R16, 3                      // ... se pone en 23
    MOV HOR_U, R16
FIN_DEC_HORAS:
    RET

// --- ARREGLO DIAS ---
// Incrementa los días cuidando el límite de cada mes (28, 30 o 31)
INC_DIAS:
    INC DIA_U
    LDI R16, 10
    CP DIA_U, R16
    BRNE VER_MAX_DIAS_INC
    CLR DIA_U
    INC DIA_D
VER_MAX_DIAS_INC:
    RCALL CALCULAR_DIA_HOY          // Convierte unidades/decenas a un solo número
    MOV R18, R17
    RCALL CALCULAR_TOPE_MES         // Averigua el límite del mes actual
    INC R16       
    CP R18, R16
    BRNE FIN_INC_DIAS               // Si excede el límite del mes...
    LDI R16, 1
    MOV DIA_U, R16                  // ... reinicia al día 01
    LDI R16, 0
    MOV DIA_D, R16
FIN_INC_DIAS:
    RET

// Decrementa los días
DEC_DIAS:
    DEC DIA_U
    LDI R16, 255
    CP DIA_U, R16
    BRNE VER_CERO_DIAS
    LDI R16, 9
    MOV DIA_U, R16
    DEC DIA_D
VER_CERO_DIAS:
    RCALL CALCULAR_DIA_HOY   
    CPI R17, 0                      // Si bajó de 1 a 0...
    BRNE FIN_DEC_DIAS
    // Si baja a 00, reasignar limite máximo de días del mes actual
    RCALL CALCULAR_TOPE_MES        
    CLR R17
DIV_DEC_DIA:                        // División iterativa para separar Decenas de Unidades del límite del mes
    CPI R16, 10             
    BRLO SET_DEC_DIA          
    SUBI R16, 10
    INC R17
    RJMP DIV_DEC_DIA
SET_DEC_DIA:
    MOV DIA_U, R16            
    MOV DIA_D, R17                
FIN_DEC_DIAS:
    RET

// --- ARREGLO MESES ---
// Incrementa los meses de 01 a 12
INC_MESES:
    INC MES_U
    LDI R16, 10
    CP MES_U, R16
    BRNE VER_LIM_12_INC
    CLR MES_U
    INC MES_D
VER_LIM_12_INC:
    LDI R16, 1
    CP MES_D, R16
    BRNE FIN_INC_MESES
    LDI R16, 3
    CP MES_U, R16
    BRNE FIN_INC_MESES              // Si llega a mes 13...
    ; Reinicio a 01 al pasar de 12
    LDI R16, 0
    MOV MES_D, R16
    LDI R16, 1
    MOV MES_U, R16
FIN_INC_MESES:
    RET

// Decrementa los meses
DEC_MESES:
    DEC MES_U
    LDI R16, 255
    CP MES_U, R16
    BRNE VER_LIM_12_DEC
    LDI R16, 9
    MOV MES_U, R16
    DEC MES_D
VER_LIM_12_DEC:
    MOV R16, MES_D
    CPI R16, 0
    BRNE FIN_DEC_MESES
    MOV R16, MES_U
    CPI R16, 0
    BRNE FIN_DEC_MESES              // Si baja a mes 00...
    ; Reinicio a 12 al bajar de 01
    LDI R16, 1
    MOV MES_D, R16                 
    LDI R16, 2
    MOV MES_U, R16
FIN_DEC_MESES:
    RET

// Incrementa minutos para la ALARMA (Idéntico al reloj, pero con sus registros)
ALM_INC_MIN:
    INC ALM_MIN_U
    LDI R16, 10
    CP ALM_MIN_U, R16
    BRNE FIN_ALM_INC_MIN
    CLR ALM_MIN_U
    INC ALM_MIN_D
    LDI R16, 6
    CP ALM_MIN_D, R16
    BRNE FIN_ALM_INC_MIN
    CLR ALM_MIN_D
FIN_ALM_INC_MIN:
    RET

// Decrementa minutos para la ALARMA
ALM_DEC_MIN:
    DEC ALM_MIN_U
    LDI R16, 255
    CP ALM_MIN_U, R16
    BRNE FIN_ALM_DEC_MIN
    LDI R16, 9
    MOV ALM_MIN_U, R16
    DEC ALM_MIN_D
    LDI R16, 255
    CP ALM_MIN_D, R16
    BRNE FIN_ALM_DEC_MIN
    LDI R16, 5
    MOV ALM_MIN_D, R16
FIN_ALM_DEC_MIN:
    RET

// Incrementa horas para la ALARMA
ALM_INC_HORAS:
    INC ALM_HOR_U
    LDI R16, 10
    CP ALM_HOR_U, R16
    BRNE VER_24H_ALM
    CLR ALM_HOR_U
    INC ALM_HOR_D
VER_24H_ALM:
    LDI R16, 2
    CP ALM_HOR_D, R16
    BRNE FIN_ALM_INC_HOR
    LDI R16, 4
    CP ALM_HOR_U, R16
    BRNE FIN_ALM_INC_HOR
    CLR ALM_HOR_U
    CLR ALM_HOR_D
FIN_ALM_INC_HOR:
    RET

// Decrementa horas para la ALARMA
ALM_DEC_HORAS:
    DEC ALM_HOR_U
    LDI R16, 255
    CP ALM_HOR_U, R16
    BRNE VER_24H_DEC_ALM
    LDI R16, 9
    MOV ALM_HOR_U, R16
    DEC ALM_HOR_D
VER_24H_DEC_ALM:
    LDI R16, 255
    CP ALM_HOR_D, R16
    BRNE FIN_ALM_DEC_HOR
    LDI R16, 2
    MOV ALM_HOR_D, R16
    LDI R16, 3             
    MOV ALM_HOR_U, R16
FIN_ALM_DEC_HOR:
    RET

// --- ARREGLO LOGICA RUTINA PRINCIPAL DE TIEMPO ---
// Esta rutina ocurre automáticamente en el fondo (llamada desde TMR1 cada 60 seg) para correr el tiempo del reloj maestro
REFRESCAR_RELOJ_GLOBAL:
    INC MIN_U
    LDI R16, 10
    CP MIN_U, R16
    BRLO FIN_REFRESCO
    CLR MIN_U
    
    INC MIN_D
    LDI R16, 6
    CP MIN_D, R16
    BRLO FIN_REFRESCO
    CLR MIN_D
    
    INC HOR_U                       // Aumenta una hora
    LDI R16, 10
    CP HOR_U, R16
    BRNE CHEQUEO_CAMBIO_DIA
    CLR HOR_U
    INC HOR_D
CHEQUEO_CAMBIO_DIA:
    LDI R16, 2
    CP HOR_D, R16
    BRNE FIN_REFRESCO
    LDI R16, 4
    CP HOR_U, R16
    BRNE FIN_REFRESCO
    CLR HOR_U
    CLR HOR_D
    
    INC DIA_U                       // Aumenta un día a media noche
    LDI R16, 10
    CP DIA_U, R16
    BRNE CHEQUEO_LIMITE_MES
    CLR DIA_U
    INC DIA_D
CHEQUEO_LIMITE_MES:
    RCALL CALCULAR_DIA_HOY        
    MOV R18, R17                    
    RCALL CALCULAR_TOPE_MES         // Evalúa qué día termina el mes
    
    INC R16                         
    CP R18, R16                     
    BRNE FIN_REFRESCO      
    
    ; Cambio de Mes
    LDI R16, 0
    MOV DIA_D, R16
    LDI R16, 1
    MOV DIA_U, R16

    INC MES_U                       // Sube un mes
    LDI R16, 10
    CP MES_U, R16
    BRNE CHEQUEO_CAMBIO_ANIO
    CLR MES_U
    INC MES_D

CHEQUEO_CAMBIO_ANIO:
    LDI R16, 1
    CP MES_D, R16
    BRNE FIN_REFRESCO
    LDI R16, 3
    CP MES_U, R16
    BRNE FIN_REFRESCO
    ; Cambio de Año (Reset de mes a 01, fin de Diciembre)
    LDI R16, 0
    MOV MES_D, R16
    LDI R16, 1
    MOV MES_U, R16
FIN_REFRESCO:
    RET

// Calcula qué mes es (del 1 al 12) sumando unidades y decenas
CALCULAR_NUM_MES:
    MOV R16, MES_U
    MOV R17, MES_D
    CPI R17, 0
    BREQ FIN_CALC_MES
    PUSH R17
    LDI R17, 10             
    ADD R16, R17
    POP R17
FIN_CALC_MES:
    RET

// Asigna la cantidad de días límite para cada mes (No maneja año bisiesto, Febrero siempre tiene 28)
CALCULAR_TOPE_MES:
    RCALL CALCULAR_NUM_MES        
    CPI R16, 2                      // Febrero
    BREQ M_28
    CPI R16, 4                      // Abril
    BREQ M_30
    CPI R16, 6                      // Junio
    BREQ M_30
    CPI R16, 9                      // Septiembre
    BREQ M_30
    CPI R16, 11                     // Noviembre
    BREQ M_30
M_31:                               // Todos los demás
    LDI R16, 31
    RET
M_30:
    LDI R16, 30
    RET
M_28:
    LDI R16, 28                     
    RET

// Convierte el registro de unidades de días y decenas a un número entero normal
CALCULAR_DIA_HOY:
    MOV R17, DIA_U
    MOV R16, DIA_D
    CPI R16, 0
    BREQ FIN_CALC_DIA
    CPI R16, 1
    BREQ SUMA_10D          
    CPI R16, 2
    BREQ SUMA_20D          

    PUSH R16
    LDI R16, 30
    ADD R17, R16                   
    POP R16
    RJMP FIN_CALC_DIA

SUMA_20D: 
    PUSH R16 
    LDI R16, 20 
    ADD R17, R16 
    POP R16 
    RJMP FIN_CALC_DIA

SUMA_10D: 
    PUSH R16 
    LDI R16, 10 
    ADD R17, R16 
    POP R16

FIN_CALC_DIA: 
    RET

// ==========================================
// ANTIRREBOTES PARA PCINT (Delay por software Aumentado)
// ==========================================
// Estas rutinas aseguran que no se registren múltiples pulsaciones (ruido) cuando se aprieta un botón
ANTIREBOTE_PB0:
    RCALL RETARDO_MS
B_PB0: 
    SBIS PINB, PB0                  // Espera a que el botón se suelte (vuelva a estado alto)
    RJMP B_PB0 
    RCALL RETARDO_MS                // Segundo delay para asegurar limpieza
    RET

ANTIREBOTE_PB1:
    RCALL RETARDO_MS
B_PB1: 
    SBIS PINB, PB1 
    RJMP B_PB1 
    RCALL RETARDO_MS 
    RET

ANTIREBOTE_PB2:
    RCALL RETARDO_MS
B_PB2: 
    SBIS PINB, PB2 
    RJMP B_PB2 
    RCALL RETARDO_MS 
    RET

ANTIREBOTE_PB3:
    RCALL RETARDO_MS
B_PB3: 
    SBIS PINB, PB3 
    RJMP B_PB3 
    RCALL RETARDO_MS 
    RET

ANTIREBOTE_PC4:
    RCALL RETARDO_MS
B_PC4: 
    SBIS PINC, PC4 
    RJMP B_PC4 
    RCALL RETARDO_MS 
    RET

// Ciclo anidado que consume ciclos de instrucción para perder tiempo (crear un delay "bloqueante")
RETARDO_MS:
    LDI R30, 255                    ; Incrementado para mejor antirrebote
Bucle1: 
    LDI R31, 255
Bucle2: 
    DEC R31 
    BRNE Bucle2 
    DEC R30 
    BRNE Bucle1
    RET

// ==========================================
// INICIALIZACIÓN DE TIMERS
// ==========================================
CONF_TIMER0:
    // Configura el Timer0 para el multiplexado de los Displays (rápido)
    LDI R16, (1<<CS01)|(1<<CS00)        // Prescaler de 64
    OUT TCCR0B, R16
    LDI R16, 6                          // Valor inicial (con prescaler 64 salta interrupción cada 1 ms aprox.)
    OUT TCNT0, R16
    LDI R16, (1<<TOIE0)                 // Habilita interrupción de Timer0 por Overflow
    STS TIMSK0, R16
    RET

CONF_TIMER1:
    // Configura el Timer1 para manejar el Reloj base (1 interrupción cada 500ms exactos)
    LDI R16, (1<<CS12)|(1<<CS10)        // Prescaler a 1024
    STS TCCR1B, R16
    LDI R16, HIGH(TMR1_VAL)
    STS TCNT1H, R16
    LDI R16, LOW(TMR1_VAL)          
    STS TCNT1L, R16                     // Carga los 16 bits del temporizador
    LDI R16, (1<<TOIE1)                 // Habilita interrupción de Timer1 por Overflow
    STS TIMSK1, R16
    RET