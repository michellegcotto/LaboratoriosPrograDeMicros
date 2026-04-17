/*
 * adc.c
 *
 * Created: 17/04/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: ADC
 */
/****************************************/
// Encabezado (Libraries)

#include "adc.h"

/****************************************/
// Function prototypes

/****************************************/
// Main Function

/****************************************/
// NON-Interrupt subroutines

void ADC_init(void)
{
    ADMUX = (1 << REFS0); // Referencia AVcc
    ADCSRA = (1 << ADEN)  // Habilitar ADC
           | (1 << ADPS2) | (1 << ADPS1); // Prescaler 64
}

uint16_t ADC_read(uint8_t ch)
{
    ADMUX = (ADMUX & 0xF0) | (ch & 0x0F);

    ADCSRA |= (1 << ADSC); // Iniciar conversión
    while (ADCSRA & (1 << ADSC)); // Esperar

    return ADC;
}

/****************************************/
// Interrupt routines