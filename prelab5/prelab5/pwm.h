/*
 * pwm.h
 *
 * Created: 17/04/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: pwm
 */

#ifndef PWM_H
#define PWM_H

#include <avr/io.h>

void PWM1_init(void);
void PWM1_setDuty(uint16_t duty);

#endif