/*
 * proyecto2_micros.c
 *
 * Created: 20/05/2026
 * Author:  Jaqueline Michelle González Cotto
 * Description: Garra electronica con servos
 */

/****************************************/
// Encabezado (Libraries)
/****************************************/
#define F_CPU 16000000UL

#include <avr/io.h>
#include <avr/eeprom.h>
#include <util/delay.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define BAUD        9600
#define UBRR_VALUE  ((F_CPU/16/BAUD)-1)

#define S0_MAX 180
#define S1_MAX 180
#define S2_MAX 180
#define S3_MAX  90

#define EE_POSE_COUNT_ADDR 64

/****************************************/
// Function prototypes
/****************************************/
void    UART_init(void);
void    UART_tx(char data);
void    UART_print(char* str);
uint8_t UART_available(void);
char    UART_read(void);

void     ADC_init(void);
uint16_t ADC_read(uint8_t channel);

void Servo_pins_init(void);
void servoPulse(uint8_t pinMask, volatile uint8_t* port, uint16_t us);
void moveServos(uint8_t s1, uint8_t s2, uint8_t s3, uint8_t s4);

void    LED_init(void);
void    LED_ON(void);
void    LED_OFF(void);
void    LED_TOGGLE(void);

void    BUTTON_init(void);
uint8_t BUTTON_pressed(void);

void showMenu(void);

/****************************************/
// Main Function
/****************************************/

uint8_t EEMEM eepromData[65];

int main(void)
{
    uint16_t adc[4];
    uint8_t  angle[4] = {0, 0, 0, 0};
    char     option;
    char     buffer[64];

    UART_init();
    ADC_init();
    Servo_pins_init();
    LED_init();
    BUTTON_init();

    uint8_t poseCount = eeprom_read_byte(&eepromData[EE_POSE_COUNT_ADDR]);
    if(poseCount == 0xFF) poseCount = 0;

    while (1)
    {
        showMenu();

        while(!UART_available());
        option = UART_read();

        // MODO MANUAL
        if(option == '1')
        {
            UART_print("\r\n===== MANUAL MODE =====\r\n");
            UART_print("Boton -> guardar pose\r\n");
            UART_print("q    -> salir\r\n");

            while(1)
            {
                LED_TOGGLE();

                adc[0] = ADC_read(0); angle[0] = (uint8_t)((adc[0] * S0_MAX) / 1023UL);
                adc[1] = ADC_read(1); angle[1] = (uint8_t)((adc[1] * S1_MAX) / 1023UL);
                adc[2] = ADC_read(2); angle[2] = (uint8_t)((adc[2] * S2_MAX) / 1023UL);
                adc[3] = ADC_read(3); angle[3] = (uint8_t)((adc[3] * S3_MAX) / 1023UL);

                for(uint8_t r = 0; r < 10; r++)
                    moveServos(angle[0], angle[1], angle[2], angle[3]);

                sprintf(buffer, "S1:%3d S2:%3d S3:%3d S4:%3d\r\n",
                        angle[0], angle[1], angle[2], angle[3]);
                UART_print(buffer);

                if(BUTTON_pressed())
                {
                    if(poseCount < 16)
                    {
                        uint8_t base = poseCount * 4;
                        eeprom_write_byte(&eepromData[base + 0], angle[0]);
                        eeprom_write_byte(&eepromData[base + 1], angle[1]);
                        eeprom_write_byte(&eepromData[base + 2], angle[2]);
                        eeprom_write_byte(&eepromData[base + 3], angle[3]);
                        poseCount++;

                        eeprom_write_byte(&eepromData[EE_POSE_COUNT_ADDR], poseCount);
                        sprintf(buffer, "POSE %d GUARDADA\r\n", poseCount - 1);
                        UART_print(buffer);
                    }
                    else UART_print("EEPROM LLENA (max 16)\r\n");

                    _delay_ms(500);
                }

                if(UART_available())
                {
                    char c = UART_read();
                    if(c == 'q') { UART_print("SALIENDO...\r\n"); break; }
                }

                _delay_ms(50);
            }
        }

        // MODO EEPROM
        if(option == '2')
        {
            UART_print("\r\n===== EEPROM MODE =====\r\n");

            if(poseCount == 0)
            {
                UART_print("No hay poses guardadas.\r\n");
                _delay_ms(1500);
                continue;
            }

            sprintf(buffer, "%d poses guardadas.\r\n", poseCount);
            UART_print(buffer);
            UART_print("q -> salir\r\n");

            while(1)
            {
                for(uint8_t p = 0; p < poseCount; p++)
                {
                    uint8_t base = p * 4;
                    angle[0] = eeprom_read_byte(&eepromData[base + 0]);
                    angle[1] = eeprom_read_byte(&eepromData[base + 1]);
                    angle[2] = eeprom_read_byte(&eepromData[base + 2]);
                    angle[3] = eeprom_read_byte(&eepromData[base + 3]);

                    sprintf(buffer, "POSE %d: S1:%3d S2:%3d S3:%3d S4:%3d\r\n",
                            p, angle[0], angle[1], angle[2], angle[3]);
                    UART_print(buffer);

                    uint16_t hold = 0;
                    while(hold < 1000)
                    {
                        moveServos(angle[0], angle[1], angle[2], angle[3]);
                        hold += 20;

                        if(UART_available())
                        {
                            char c = UART_read();
                            if(c == 'q')
                            {
                                LED_OFF();
                                UART_print("SALIENDO...\r\n");
                                goto salir_eeprom;
                            }
                        }
                    }

                    LED_TOGGLE();
                }
            }
            salir_eeprom:;
        }

        // MODO UART
        if(option == '3')
        {
            UART_print("\r\n===== UART MODE =====\r\n");
            UART_print("Formato: s1,s2,s3,s4\r\n");
            UART_print("Ejemplo: 90,45,120,45\r\n");
            UART_print("q -> salir\r\n");

            char    cmd[32];
            uint8_t idx = 0;

            while(1)
            {
                if(UART_available())
                {
                    char c = UART_read();
                    UART_tx(c); 

                    if(c == '\r' || c == '\n')
                    {
                        cmd[idx] = '\0';
                        idx = 0;
                        UART_print("\r\n");

                        if(cmd[0] == '\0') continue; 

                        if(strcmp(cmd, "q") == 0)
                        {
                            UART_print("SALIENDO UART\r\n");
                            break;
                        }

                        int a1, a2, a3, a4;
                        if(sscanf(cmd, "%d,%d,%d,%d", &a1, &a2, &a3, &a4) == 4)
                        {
                            angle[0] = (a1 > S0_MAX) ? S0_MAX : (uint8_t)a1;
                            angle[1] = (a2 > S1_MAX) ? S1_MAX : (uint8_t)a2;
                            angle[2] = (a3 > S2_MAX) ? S2_MAX : (uint8_t)a3;
                            angle[3] = (a4 > S3_MAX) ? S3_MAX : (uint8_t)a4;

                            moveServos(angle[0], angle[1], angle[2], angle[3]);

                            sprintf(buffer, "OK: S1:%d S2:%d S3:%d S4:%d\r\n",
                                    angle[0], angle[1], angle[2], angle[3]);
                            UART_print(buffer);
                        }
                        else UART_print("ERROR: usar formato 90,45,120,45\r\n");
                    }
                    else if(idx < 31) cmd[idx++] = c;
                }
            }
        }
    }
}

/****************************************/
// NON-Interrupt subroutines
/****************************************/
void UART_init(void)
{
    UBRR0H = (UBRR_VALUE >> 8);
    UBRR0L = UBRR_VALUE;
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

void UART_tx(char data)
{
    while(!(UCSR0A & (1 << UDRE0)));
    UDR0 = data;
}

void UART_print(char* str)
{
    while(*str) UART_tx(*str++);
}

uint8_t UART_available(void)
{
    return (UCSR0A & (1 << RXC0));
}

char UART_read(void)
{
    return UDR0;
}

void ADC_init(void)
{
    ADMUX  = (1 << REFS0);
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

uint16_t ADC_read(uint8_t channel)
{
    ADMUX  = (ADMUX & 0xF0) | channel;
    ADCSRA |= (1 << ADSC);
    while(ADCSRA & (1 << ADSC));
    return ADC;
}

void Servo_pins_init(void)
{
    DDRD |= (1 << PD3) | (1 << PD5) | (1 << PD6);
    DDRB |= (1 << PB1);
}

void servoPulse(uint8_t pinMask, volatile uint8_t* port, uint16_t us)
{
    *port |= pinMask;
    while(us--) _delay_us(1);
    *port &= ~pinMask;
}

void moveServos(uint8_t s1, uint8_t s2, uint8_t s3, uint8_t s4)
{
    uint16_t p1 = 1000 + ((uint32_t)s1 * 1000UL) / 180UL;
    uint16_t p2 = 1000 + ((uint32_t)s2 * 1000UL) / 180UL;
    uint16_t p3 = 1000 + ((uint32_t)s3 * 1000UL) / 180UL;
    uint16_t p4 = 1000 + ((uint32_t)s4 * 1000UL) / 180UL;

    servoPulse((1 << PD3), &PORTD, p1); _delay_ms(5);
    servoPulse((1 << PD5), &PORTD, p2); _delay_ms(5);
    servoPulse((1 << PD6), &PORTD, p3); _delay_ms(5);
    servoPulse((1 << PB1), &PORTB, p4); _delay_ms(5);
}

void LED_init(void)   { DDRC  |=  (1 << PC5); }
void LED_ON(void)     { PORTC |=  (1 << PC5); }
void LED_OFF(void)    { PORTC &= ~(1 << PC5); }
void LED_TOGGLE(void) { PORTC ^=  (1 << PC5); }

void BUTTON_init(void)
{
    DDRC  &= ~(1 << PC4);
    PORTC |=  (1 << PC4);
}

uint8_t BUTTON_pressed(void)
{
    if(!(PINC & (1 << PC4))) {
        _delay_ms(30);
        if(!(PINC & (1 << PC4))) return 1;
    }
    return 0;
}

void showMenu(void)
{
    UART_print("\r\n");
    UART_print("========================\r\n");
    UART_print("  GARRA ROBOTICA UVG\r\n");
    UART_print("========================\r\n");
    UART_print("1 -> MANUAL\r\n");
    UART_print("2 -> EEPROM\r\n");
    UART_print("3 -> UART\r\n");
    UART_print("========================\r\n");
    UART_print("Seleccione opcion: ");
}

/****************************************/
// Interrupt routines
/****************************************/