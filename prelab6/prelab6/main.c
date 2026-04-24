/*
 * prelab6.c
 *
 * Created: 24/04/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: Parte 1. Envíe un caracter desde el microcontrolador hacia la computadora y mírela en la hiperterminal.
 *              Parte 2. Reciba un carácter desde la hiperterminal y muéstrelo en 8 LEDs.
 *
 */
/****************************************/
// Encabezado (Libraries)
#define F_CPU 16000000UL
#include <avr/io.h>

/****************************************/
// Function prototypes
void UART_init(void);
void UART_send(char data);

/****************************************/
// Main Function
int main(void)
{
    UART_init();

    DDRB = 0xFF;           
    DDRD |= (1 << PD2) | (1 << PD3);

    while (1)
    {
        UART_send('A');
        UART_send('\r');
        UART_send('\n');

        if (UCSR0A & (1 << RXC0))
        {
            char dato = UDR0;

            PORTB = dato & 0x3F;

            if (dato & (1 << 6))
                PORTD |= (1 << PD2);
            else
                PORTD &= ~(1 << PD2);

            if (dato & (1 << 7))
                PORTD |= (1 << PD3);
            else
                PORTD &= ~(1 << PD3);
        }

        for (volatile long i = 0; i < 200000; i++);
    }
}

/****************************************/
// NON-Interrupt subroutines

void UART_init(void)
{
    unsigned int ubrr = 103;

    UBRR0H = (unsigned char)(ubrr >> 8);
    UBRR0L = (unsigned char)ubrr;

    UCSR0B = (1 << RXEN0) | (1 << TXEN0);
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

void UART_send(char data)
{
    while (!(UCSR0A & (1 << UDRE0)));
    UDR0 = data;
}

/****************************************/
// Interrupt routines
