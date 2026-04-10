/*
 * prelab4.c 
 *
 * Created: 10/04/2026 
 * Author: Jaqueline Michelle González Cotto 
 * Description: Diseñe e implemente un contador binario de 8 bits. Utilice 2 pushbuttons para
 aumentar y decrementar el contador. Implemente antirebotes.
 *
 */
/****************************************/
// Encabezado (Libraries)

#define F_CPU 16000000UL //define frecuencia de 16 MHz
#include <avr/io.h> //acceso a los puertos
#include <util/delay.h> //permite usar delays
#include <avr/interrupt.h> //permite manejar interrupciones

/****************************************/
// Variables globales
//para detectar cambios en los botones (1 es sin presionar)
unsigned char lastBtnUp = 1;
unsigned char stateBtnUp = 1;
unsigned char lastBtnDown = 1;
unsigned char stateBtnDown = 1;

int countValue = 0; //guarda el valor del contador

/****************************************/
// Function prototypes

void setup(void);

/****************************************/
// Main Function

int main(void)
{
    setup(); //configura todo
    sei(); //habilita interrupciones globales

    while (1) //controla el overflow
    {
        if (countValue > 255) countValue = 0;
        if (countValue < 0)   countValue = 255;

        PORTD = countValue; //envia el valor al puerto D (donde están las leds)
    }
}

/****************************************/
// NON-Interrupt subroutines

void setup(){
    cli(); //desactivas las interrupciones mientras se configura
    
    DDRD = 0xFF; //puerto D (donde están las leds)
    PORTD = 0; //inicia en 0
    UCSR0B = 0; //para desactivar conexión serial en D0 y D1

    DDRC &= ~((1<<PC3) | (1<<PC4)); //configura los botones como señal de entrada (PC3 y PC4)
    PORTC |= (1<<PC3) | (1<<PC4); //activa los pull-up internos
// boton suelo es 1 y boton presionado es 0

    PCICR |= (1<<PCIE1); //activa interrupciones
    PCMSK1 |= (1<<PCINT11) | (1<<PCINT12); //habilita interrupcione de botones
}

/****************************************/
// Interrupt routines
//cuando cambia el estado de alguno de los botones
ISR(PCINT1_vect){
    _delay_ms(20); //antirrebote
    
	//lee el estado actual de los botones
    stateBtnUp = PINC & (1<<PINC3);
    stateBtnDown = PINC & (1<<PINC4);
    
	//para cuando quiero incrementar (solo si está presionado y si antes no lo estuvo)
    if ((stateBtnUp == 0) && (lastBtnUp != 0)){
        countValue++;
    }
    lastBtnUp = stateBtnUp; //guarda el estado actual
    
	//para cuando quiero decrementar (solo si esta presionado y no lo estuvo antes)
    if ((stateBtnDown == 0) && (lastBtnDown != 0)){
        countValue--;
    }
    lastBtnDown = stateBtnDown;
    
    PCIFR |= (1<<PCIF1); //limpia la bandera para permitir nuevas interrupciones
}
//fin