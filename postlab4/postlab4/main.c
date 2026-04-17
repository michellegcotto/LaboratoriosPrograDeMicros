/*
 * postlab4.c
 *
 * Created: 15/04/2026
 * Author: Jaqueline Michelle González Cotto 
 * Description: Implemente una rutina en donde se compare la parte 1 del laboratorio y se
 compare con el valor del ADC, si el valor de ADC es mayor que el valor del
 contador binario deberá encender un led como símbolo de alarma.
 */

/**************/
// Encabezado (Libraries)

#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

/**************/
// Variables globales

unsigned char ButtonLastState_1 = 1;
unsigned char ButtonState_1 = 1;
unsigned char ButtonLastState_2 = 1;
unsigned char ButtonState_2 = 1;

/**************/
// Function prototypes

void initADC(void);
void dispsegG(int);
void dec_hex(uint8_t);
void setup(void);
void comparacion(void);

// Tabla de 7 segmentos (A-F en PORTB) 
const uint8_t hexaDisplay[16]= { ~0x3F, ~0x06, ~0x5B, ~0x4F,       
                                 ~0x66, ~0x6D, ~0x7D, ~0x07,       
                                 ~0x7F, ~0x6F, ~0x77, ~0x7C,       
                                 ~0x39, ~0x5E, ~0x79, ~0x71};      
                                
const unsigned int tMulx = 5;           //Tiempo delay para multiplex (5  ms)

int contador = 0;
volatile int contadorADC = 0;

//Nibbles Display
int LowNibble = 0;
int HighNibble = 0;

//***************************************************************************
int main(void)
{
    setup();
    sei();

    while (1)
    {
		
		
		ADCSRA |= (1<<ADSC);
		dec_hex(contadorADC);
		
		comparacion();
		
		
        // Límites del contador binario (PORTD)
        if (contador > 255) contador = 0;
        if (contador < 0)   contador = 255;
        PORTD = contador;
        
        // Iniciar conversión ADC
        ADCSRA |= (1<<ADSC);
        
        dec_hex(contadorADC);

        // Mostrar Digito 1 (enciende PC1)
        PORTB = hexaDisplay[HighNibble]; // Envía segmentos A-F
        dispsegG(HighNibble);            // Envía segmento G a PC0
        
        PORTC &= ~(1<<PC1);              // Enciende D1
        PORTC |= (1<<PC2);             // Apaga D2
        
        _delay_ms(tMulx);
        
        // Mostrar Digito 2 (enciende PC2)
        PORTB = hexaDisplay[LowNibble];
        dispsegG(LowNibble);
        
        PORTC &= ~(1<<PC2);              // Enciende D2
        PORTC |= (1<<PC1);             // Apaga D1
        
        _delay_ms(tMulx);
    }
}

/**************/
// NON-Interrupt subroutines

//Configuracion
void setup(){
    cli();
    
    // PORTD: Salida para el contador binario
    DDRD = 0xFF;
    PORTD = 0;
    UCSR0B = 0; // Deshabilitar RX/TX para usar pines de PORTD

    // PORTB: Salida para segmentos A-F
    DDRB = 0xFF;
    
    // PORTC: 
    
    //-Salidas
    DDRC |= (1<<PC0) | (1<<PC1) | (1<<PC2) | (1<<PC5); //PC1 segmento G - PC1 y PC2 MULTIPLEX / PC5 LED alarma
    
    //-Entradas
    DDRC &= ~((1<<PC3) | (1<<PC4)); // Botones en PC3 y PC4
    PORTC |= (1<<PC3) | (1<<PC4);  // Pull-ups
    

    // Interrupciones de cambio de pin para PC3 y PC4 (Puerto C -> PCIE1)
    PCICR |= (1<<PCIE1);
    PCMSK1 |= (1<<PCINT11) | (1<<PCINT12);
    
    // PC7: Entrada ADC 
        
    initADC();
}

void initADC(void){
    // Seleccionar ADC7 (PC7) - bits 0111 (0x07)
    ADMUX = (ADMUX & 0xF0) | 0x07;
    
    // Vref = AVCC, Justificado a la izquierda (8 bits en ADCH)
    ADMUX |= (1<<REFS0) | (1<<ADLAR);
    
    // Prescaler 128 y habilitar interrupciònes
    ADCSRA |= (1<<ADEN) | (1<<ADIE) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0);
}

void dec_hex(uint8_t val){
    HighNibble = val / 16;		//Divide el val en 16 
    LowNibble = val % 16;		//Obtiene el residuo de la divisiòn de 16 
}

void dispsegG(int valor){
    // Controla el segmento G conectado a PC0
    
    // Usando const uint8_t para la tabla del segmento G
    const uint8_t tablaG[16] = {0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1};
    
    if(tablaG[valor]) 
        PORTC &= ~(1<<PC0);  //0 encendido
    else              
        PORTC |= (1<<PC0); //1 apagado
}

//POST - LAB
void comparacion(void) {
	if (contador < contadorADC) {
		PORTC |= (1 << PC5);  // Enciende PC5 si son iguales
		} else {
		PORTC &= ~(1 << PC5); // Apaga PC5 si son distintos
	}
}

/**************/
// Interrupt routines

ISR(ADC_vect){
    contadorADC = ADCH; // Lee los 8 bits superiores (Justificado a la izquierda) 
}

ISR(PCINT1_vect){
    _delay_ms(20); // Anti-rebote
    
    ButtonState_1 = PINC & (1<<PINC3);
    ButtonState_2 = PINC & (1<<PINC4);
    
    // Botón 1: Incremento
    if ((ButtonState_1 == 0) && (ButtonLastState_1 != 0)){
        contador++;
    }
    ButtonLastState_1 = ButtonState_1;
    
    // Botón 2: Decremento
    if ((ButtonState_2 == 0) && (ButtonLastState_2 != 0)){
        contador--;
    }
    ButtonLastState_2 = ButtonState_2;
    
    PCIFR |= (1<<PCIF1); // Limpiar bandera
}
