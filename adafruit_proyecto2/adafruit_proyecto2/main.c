/*
 * adafruit_proyecto2.c
 *
 * Created: 20/05/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: adafruit para proyecto 2, garra
 */

/****************************************/
// Encabezado (Libraries)

#define F_CPU 16000000UL

#include <avr/io.h>
#include <util/delay.h>
#include <stdlib.h>
#include <stdio.h>

/****************************************/
// Function prototypes

void UART_init(void);
uint8_t UART_available(void);
char UART_read(void);

void Servo_pins_init(void);
void servoPulse(
	uint8_t pinMask,
	volatile uint8_t* port,
	uint16_t us);

void moveServos(
	uint8_t s1,
	uint8_t s2,
	uint8_t s3,
	uint8_t s4);

/****************************************/
// Definiciones UART

#define BAUD 9600
#define UBRR_VALUE ((F_CPU/16/BAUD)-1)

/****************************************/
// Main Function

int main(void)
{
	char cmd[32];

	uint8_t idx = 0;

	int a1 = 90;
	int a2 = 90;
	int a3 = 90;
	int a4 = 90;

	UART_init();

	Servo_pins_init();

	while(1)
	{

		for(uint8_t i = 0; i < 5; i++)
		{
			moveServos(a1, a2, a3, a4);
		}

		while(UART_available())
		{
			char c = UART_read();

			// FIN DE LINEA

			if(c == '\n' || c == '\r')
			{
				cmd[idx] = '\0';

				idx = 0;

				if(sscanf(
					cmd,
					"%d,%d,%d,%d",
					&a1,
					&a2,
					&a3,
					&a4) == 4)
				{

					if(a1 < 0) a1 = 0;
					if(a1 > 180) a1 = 180;

					if(a2 < 0) a2 = 0;
					if(a2 > 180) a2 = 180;

					if(a3 < 0) a3 = 0;
					if(a3 > 180) a3 = 180;

					if(a4 < 0) a4 = 0;
					if(a4 > 180) a4 = 180;
				}
			}
			else
			{
				if(idx < 31)
				{
					cmd[idx++] = c;
				}
			}
		}
	}
}

/****************************************/
// NON-Interrupt subroutines

void UART_init(void)
{
	UBRR0H = (UBRR_VALUE >> 8);
	UBRR0L = UBRR_VALUE;

	UCSR0B =
		(1 << RXEN0) |
		(1 << TXEN0);

	UCSR0C =
		(1 << UCSZ01) |
		(1 << UCSZ00);
}

uint8_t UART_available(void)
{
	return (UCSR0A & (1 << RXC0));
}

char UART_read(void)
{
	return UDR0;
}

void Servo_pins_init(void)
{
	DDRD |= (1 << PD3);
	DDRD |= (1 << PD5);
	DDRD |= (1 << PD6);

	DDRB |= (1 << PB1);
}

void servoPulse(
	uint8_t pinMask,
	volatile uint8_t* port,
	uint16_t us)
{
	*port |= pinMask;

	while(us--)
	{
		_delay_us(1);
	}

	*port &= ~pinMask;
}

void moveServos(
	uint8_t s1,
	uint8_t s2,
	uint8_t s3,
	uint8_t s4)
{
	uint16_t p1;
	uint16_t p2;
	uint16_t p3;
	uint16_t p4;

	p1 = 1000 + ((uint32_t)s1 * 1000UL) / 180UL;
	p2 = 1000 + ((uint32_t)s2 * 1000UL) / 180UL;
	p3 = 1000 + ((uint32_t)s3 * 1000UL) / 180UL;
	p4 = 1000 + ((uint32_t)s4 * 1000UL) / 180UL;

	servoPulse((1 << PD3), &PORTD, p1);
	_delay_ms(2);

	servoPulse((1 << PD5), &PORTD, p2);
	_delay_ms(2);

	servoPulse((1 << PD6), &PORTD, p3);
	_delay_ms(2);

	servoPulse((1 << PB1), &PORTB, p4);
	_delay_ms(2);
}

/****************************************/
// Interrupt routines