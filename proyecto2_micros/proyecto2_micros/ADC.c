/*
 * adc.c
 * Author: Jaqueline Michelle González Cotto
 * Description:
 */

/****************************************/
// Encabezado (Libraries)

#include "adc.h" //incluye archivo con funciones declaradas

/****************************************/
// Function prototypes

/****************************************/
// Main Function

/****************************************/
// NON-Interrupt subroutines

void ADC_init(void) //funcion para iniciar ADC
{
	ADMUX = (1 << REFS0); // Referencia AVcc como voltaje
	ADCSRA = (1 << ADEN)  //divide frecuencia del cpu
	| (1 << ADPS2) | (1 << ADPS1); // Prescaler 64
}

uint16_t ADC_read(uint8_t ch) //funcion para leer un canal en específico
{	//limpia los bits bajos y selecciona el canal
	ADMUX = (ADMUX & 0xF0) | (ch & 0x0F); //mantiene los bits altos

	ADCSRA |= (1 << ADSC); // Iniciar conversión poniendo en 1 el bit
	while (ADCSRA & (1 << ADSC)); // Espera a que termine la conversion

	return ADC; //regresa el valor convertido
}

/****************************************/
// Interrupt routines