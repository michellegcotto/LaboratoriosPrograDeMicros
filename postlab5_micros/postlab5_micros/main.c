/*
 * postlab5.c
 * Created: 17/4/2026
 * Author: Jaqueline Michelle González Cotto
 * Description: Lectura de ADC con PWM
 */

// Librerías necesarias para registros y manejo de interrupciones
#include <avr/io.h>
#include <avr/interrupt.h>

// Variables globales (volatile porque se usan en interrupciones)
volatile uint16_t lectura0 = 0;   // Guarda valor ADC canal 0 (A0)
volatile uint16_t lectura1 = 0;   // Guarda valor ADC canal 1 (A1)
volatile uint16_t lectura2 = 0;   // Guarda valor ADC canal 2 (A2)
volatile uint8_t canal_actual = 0; // Indica qué canal se está leyendo (0,1,2)
volatile uint8_t dato_adc = 0;     // Variable no utilizada (se puede eliminar)
volatile uint8_t contador_pwm = 0; // Contador para generar PWM por software
volatile uint8_t ciclo_trabajo = 0; // Duty cycle (0–255) del PWM software

// Prototipos de funciones
void config_general(void);
void adc_canal0(void);
void adc_canal1(void);
void adc_canal2(void);
void pwm_timer2(void);
void pwm_timer1(void);
void timer0_config(void);

// Función principal
int main(void)
{
	cli(); // Desactiva interrupciones globales

	config_general();   // Configura reloj y pines
	timer0_config();    // Configura Timer0 (PWM por software)
	pwm_timer1();       // Configura PWM en Timer1 (pin D9)
	pwm_timer2();       // Configura PWM en Timer2 (pin D11)
	adc_canal0();       // Inicializa ADC en canal 0 (A0)

	sei(); // Activa interrupciones globales

	ADCSRA |= (1 << ADSC); // Inicia primera conversión ADC
	
	while (1)
	{
		// Loop vacío: todo se maneja con interrupciones
	}
}

// Configuración general del sistema
void config_general(void)
{
	// Configura el reloj a 2 MHz (divisor de 8)
	CLKPR = (1 << CLKPCE); // Permite cambiar prescaler
	CLKPR = (1 << CLKPS1) | (1 << CLKPS0); // Divide clock entre 8

	// Configura pines como salida (PWM)
	DDRD  |= (1 << PD6); // D6 salida (PWM software)
	DDRB |= (1 << PB1);  // D9 salida (Timer1)
	DDRB |= (1 << PB3);  // D11 salida (Timer2)
	
	PORTD = 0x00; // Inicializa en bajo
	PORTB = 0x00; // Inicializa en bajo
}

// Configuración del Timer0 para generar PWM por software
void timer0_config(void)
{
	TCCR0A = (1 << WGM01); // Modo CTC (comparación)
	TCCR0B = (1 << CS00);  // Prescaler = 1 (máxima velocidad)
	OCR0A = 50;            // Valor de comparación

	TIMSK0 = (1 << OCIE0A); // Habilita interrupción por comparación
}

// Configuración de PWM con Timer1 (pin D9)
void pwm_timer1(void)
{
	TCCR1A |= (1 << COM1A1) | (1 << WGM11); // PWM no invertido, modo Fast PWM
	TCCR1B |= (1 << WGM12) | (1 << WGM13);  // Completa modo Fast PWM con ICR1

	TCCR1B |= (1 << CS11); // Prescaler = 8

	ICR1 = 5000;  // Define periodo (?20ms, útil para servos)
	OCR1A = 250;  // Duty cycle inicial
}

// Configuración de PWM con Timer2 (pin D11)
void pwm_timer2(void)
{
	TCCR2A = 0; // Limpia registros
	TCCR2B = 0;
	
	TCCR2A |= (1 << WGM20) | (1 << WGM21); // Modo Fast PWM
	TCCR2A |= (1 << COM2A1);               // Salida no invertida
	
	TCCR2B |= (1 << CS01) | (1 << CS00);   // Prescaler = 64
	
	OCR2A = 250; // Duty cycle inicial
}

// Configuración ADC canal 2 (A2)
void adc_canal2(void)
{
	ADMUX = 0; // Limpia configuración

	ADMUX |= (1 << REFS0) | (1 << MUX1); // Referencia AVcc, canal ADC2

	ADCSRA = 0; // Limpia configuración

	ADCSRA |= (1 << ADEN) | (1 << ADPS1) | (1 << ADPS0); // Activa ADC, prescaler 8

	ADCSRA |= (1 << ADIE); // Habilita interrupción ADC
}

// Configuración ADC canal 1 (A1)
void adc_canal1(void)
{
	ADMUX = 0;

	ADMUX |= (1 << REFS0) | (1 << MUX0); // Canal ADC1

	ADCSRA = 0;

	ADCSRA |= (1 << ADEN) | (1 << ADPS1) | (1 << ADPS0);

	ADCSRA |= (1 << ADIE);
}

// Configuración ADC canal 0 (A0)
void adc_canal0(void)
{
	ADMUX = 0;

	ADMUX |= (1 << REFS0); // Canal ADC0

	ADCSRA = 0;

	ADCSRA |= (1 << ADEN) | (1 << ADPS1) | (1 << ADPS0);

	ADCSRA |= (1 << ADIE);
}

// Interrupción del ADC (se ejecuta al terminar cada conversión)
ISR(ADC_vect)
{
	uint16_t lectura = ADC; // Lee valor convertido

	if (canal_actual == 0)
	{
		lectura0 = lectura; // Guarda valor A0

		// Ajusta PWM de Timer1 (servo)
		OCR1A = 125 + ((uint32_t)lectura0 * 500) / 1023;

		ADMUX = (ADMUX & 0xF0) | 1; // Cambia a canal ADC1 (A1)
		canal_actual = 1;
	}
	else if (canal_actual == 1)
	{
		lectura1 = lectura; // Guarda valor A1

		// Ajusta PWM de Timer2 (LED en D11)
		OCR2A = ((uint32_t)lectura1 * 255) / 1023;

		ADMUX = (ADMUX & 0xF0) | 2; // Cambia a canal ADC2 (A2)
		canal_actual = 2;
	}
	else if (canal_actual == 2)
	{
		lectura2 = lectura; // Guarda valor A2

		// Ajusta duty cycle del PWM por software (D6)
		ciclo_trabajo = ((uint32_t)lectura2 * 255) / 1023;

		ADMUX = (ADMUX & 0xF0) | 0; // Regresa a ADC0
		canal_actual = 0;
	}

	ADCSRA |= (1 << ADSC); // Inicia siguiente conversión automáticamente
}

// Interrupción del Timer0 (genera PWM por software)
ISR(TIMER0_COMPA_vect)
{
	contador_pwm++; // Incrementa contador

	if (contador_pwm < ciclo_trabajo)
		PORTD |= (1 << PD6);   // Enciende pin D6
	else
		PORTD &= ~(1 << PD6);  // Apaga pin D6
}