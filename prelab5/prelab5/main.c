/*
 * prelab5.c
 *
 * Created: 17/04/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: ADC + PWM para control de servo
 */

/****************************************/
// Encabezado (Libraries)

#define F_CPU 16000000UL
#include <avr/io.h>
#include "adc.h"
#include "pwm.h"

/****************************************/
// Function prototypes

/****************************************/
// Main Function

int main(void)
{
    ADC_init();
    PWM1_init();

    while (1)
    {
        uint16_t adc_value = ADC_read(0);

        // Mapear ADC ? servo (1ms a 2ms)
        uint16_t duty = 2000 + (adc_value * 2);

        PWM1_setDuty(duty);
    }
}

/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines