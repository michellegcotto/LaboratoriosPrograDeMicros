/*
 * adc.h
 *
 * Author: Jaqueline Michelle González Cotto
 * Description:
 */
//evita que se suba doble el archivo
#ifndef ADC_H
#define ADC_H

#include <avr/io.h> //definicion de registros

void ADC_init(void); //funcion para iniciar ADC
uint16_t ADC_read(uint8_t ch); //lectura de adc y convierte en valor de 10 bits 0-1023

#endif