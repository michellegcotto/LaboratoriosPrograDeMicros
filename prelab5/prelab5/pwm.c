/*
 * pwm.c
 *
 * Created: 17/04/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: pwm
 */

/****************************************/
// Encabezado (Libraries)

#include "pwm.h"

/****************************************/
// Function prototypes

/****************************************/
// Main Function

/****************************************/
// NON-Interrupt subroutines

void PWM1_init(void)
{
    // Pin D9 (PB1 / OC1A)
    DDRB |= (1 << PB1);

    // Fast PWM, TOP = ICR1
    TCCR1A = (1 << COM1A1) | (1 << WGM11);
    TCCR1B = (1 << WGM13) | (1 << WGM12) | (1 << CS11); // Prescaler 8

    // 50 Hz (Servo)
    ICR1 = 39999;
}

void PWM1_setDuty(uint16_t duty)
{
    OCR1A = duty;
}

/****************************************/
// Interrupt routines