#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#ifdef CONFIG_ARDUINO_API
	#include <Arduino.h>
#endif

////////////////////////////////////////
#define DIM(x)				(sizeof(x)/sizeof(x[0]))

#define LED0_NODE DT_ALIAS(led0)
#define LED1_NODE DT_ALIAS(led1)
#define LED2_NODE DT_ALIAS(led2)
#define LED3_NODE DT_ALIAS(led3)

////////////////////////////////////////
//static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);
static const struct gpio_dt_spec zephyr_leds[] = 
{
	GPIO_DT_SPEC_GET(LED0_NODE, gpios),
	GPIO_DT_SPEC_GET(LED1_NODE, gpios),
	GPIO_DT_SPEC_GET(LED2_NODE, gpios),
	GPIO_DT_SPEC_GET(LED3_NODE, gpios)
};
#ifdef CONFIG_ARDUINO_API
	static const pin_size_t arduino_leds[] = { D2, D3, D4, D5 };
#endif

////////////////////////////////////////////////////////////////////////////////
static void setup_digital_arduino (void)
{
#ifdef CONFIG_ARDUINO_API
	for (uint8_t i=0; i<DIM(arduino_leds); ++i)
	{
		pinMode(arduino_leds[i], OUTPUT);
	}
#endif
}

////////////////////////////////////////////////////////////////////////////////
static void setup_digital_zephyr (void)
{
	for (uint8_t i=0; i<DIM(zephyr_leds); ++i)
	{
		if (gpio_is_ready_dt(&zephyr_leds[i]) == false)
		{
			k_oops();
		}
		int result = gpio_pin_configure_dt(&zephyr_leds[i], GPIO_OUTPUT_INACTIVE);
		if ( result  < 0)
		{
			k_oops();
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
static void blink_zephyr (void)
{
	static bool		  led_state = false;
	static uint8_t	  index = 0;

	int result = gpio_pin_toggle_dt(&zephyr_leds[index]);
	if ( result  < 0)
	{
		k_oops();
	}

	if (led_state == false)
	{
		index++;
		if (index >= DIM(zephyr_leds))
		{
			index = 0;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
void setup_digital (void)
{
	setup_digital_arduino();
	setup_digital_zephyr();
}

////////////////////////////////////////////////////////////////////////////////
static void blink_arduino (void)
{
#ifdef CONFIG_ARDUINO_API
	static bool		  led_state = false;
	static uint8_t	  index = 0;

	led_state = !led_state;

	digitalWrite(arduino_leds[index], led_state ? HIGH : LOW);

	if (led_state == false)
	{
		index++;
		if (index >= DIM(arduino_leds))
		{
			index = 0;
		}
	}
#endif
}

////////////////////////////////////////////////////////////////////////////////
void blink (void)
{
	static uint8_t count = 0;
	if (count < 8)
	{
#ifdef CONFIG_ARDUINO_API
		blink_arduino();
#else
		count = 7;
#endif
	}
	else
	{
		blink_zephyr();
	}
	count++;
	if (count >= 16)
	{
		count = 0;
	}	
}

