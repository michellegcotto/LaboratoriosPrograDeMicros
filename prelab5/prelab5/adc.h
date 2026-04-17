/*
 * adc.h
 *
 * Created: 17/04/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: ADC
 */
#ifndef ADC_H
#define ADC_H

#include <avr/io.h>

void ADC_init(void);
uint16_t ADC_read(uint8_t ch);

#endif