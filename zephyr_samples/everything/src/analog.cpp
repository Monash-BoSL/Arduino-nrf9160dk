#include <zephyr/drivers/adc.h>
#include <zephyr/kernel.h>
#include <SEGGER_RTT.h>
#ifdef CONFIG_ARDUINO_API
	#include <Arduino.h>
#else
	#define pin_size_t	uint8_t
#endif

#define ANALOG_RESOLUTION_BITS  12
#define MAX_ADC_MV              (5000.0)
#define MAX_ADC_COUNT           ((1<<ANALOG_RESOLUTION_BITS) - 1)
#define ADC_MV_PER_COUNT        (MAX_ADC_MV / MAX_ADC_COUNT)
#define MV_IN_V					(1000)
#define ADC_COUNT_TO_MV(c)      (c * ADC_MV_PER_COUNT)
#define ADC_COUNT_TO_V(c)       (1.0 * c * ADC_MV_PER_COUNT / MV_IN_V)

// ADC node from the devicetree
#define ADC_NODE DT_ALIAS(adc0)

// Data of ADC device specified in devicetree
static const struct device* adc = DEVICE_DT_GET(ADC_NODE);

// Data array of ADC channels for the specified ADC.
static const struct adc_channel_cfg channel_cfgs[] = {
	DT_FOREACH_CHILD_SEP(ADC_NODE, ADC_CHANNEL_CFG_DT, (,))
};
//#define CHANNEL_COUNT			ARRAY_SIZE(channel_cfgs)
#define CHANNEL_COUNT			3

////////////////////////////////////////
uint16_t readings[CHANNEL_COUNT];
static struct adc_sequence sequence = {
	.options = NULL,
	.channels = 0,									// no sampling for now
	.buffer = readings,
	.buffer_size = sizeof(readings),				// buffer size in bytes, not number of samples
	.resolution = ANALOG_RESOLUTION_BITS,
	.calibrate = false
};

////////////////////////////////////////////////////////////////////////////////
void analog_setup (void)
{
	if (device_is_ready(adc) == false) {
		printf("ADC controller device %s not ready\n", adc->name);
		k_oops();
	}
}

////////////////////////////////////////////////////////////////////////////////
void adc_setup_sequence (void)
{
	// Configure channels individually prior to sampling
	for (size_t ch = 0U; ch < CHANNEL_COUNT; ch++) 
	{
		sequence.channels |= BIT(channel_cfgs[ch].channel_id);
		int err = adc_channel_setup(adc, &channel_cfgs[ch]);
		if (err < 0) {
			printf("Could not setup ADC channel #%d (%d)\n", ch, err);
			k_oops();
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
void adc_read_sequence (void)
{
	int err = adc_read(adc, &sequence);
	if (err < 0) 
	{
		printf("Could not read ADC (err=%d)\n", err);
	}
	else
	{
		SEGGER_RTT_printf(0, "%s\n", adc->name);
		for (size_t ch = 0U; ch < CHANNEL_COUNT; ch++) 
		{
			uint32_t val = readings[ch];
			uint32_t val_mv = ADC_COUNT_TO_MV(val);

			SEGGER_RTT_printf(0, "  ch%d: 0x%04x (%4d) = %dmV\n", ch, val, val, val_mv);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////
void adc_read_single (uint8_t ch)
{
	// Setup sequence to only sample the channel requested
	sequence.channels = BIT(channel_cfgs[ch].channel_id);

	// Setiup adc channel
	int err = adc_channel_setup(adc, &channel_cfgs[ch]);
	if (err < 0) {
		printf("Could not setup ADC channel #%d (%d)\n", ch, err);
		k_oops();
	}

	// Read
	err = adc_read(adc, &sequence);
	if (err < 0) 
	{
		printf("Could not read ADC (err=%d)\n", err);
	}
	else
	{
		uint32_t val = readings[0];
		uint32_t val_mv = ADC_COUNT_TO_MV(val);

		SEGGER_RTT_printf(0, "  ch%d: 0x%04x (%4d) = %dmV\n", ch, val, val, val_mv);
	}
}

////////////////////////////////////////////////////////////////////////////////
void adc_read_arduino (pin_size_t adc_pin)
{
#ifdef CONFIG_ARDUINO_API
	analogReadResolution(ANALOG_RESOLUTION_BITS);

	int val = analogRead(adc_pin);
	int val_mv = ADC_COUNT_TO_MV(val);
	SEGGER_RTT_printf(0, "  ch%d: 0x%04x (%4d) = %dmV\n", adc_pin, val, val, val_mv);
#else
	(void)adc_pin;
#endif
}

////////////////////////////////////////////////////////////////////////////////
void analog_read (void)
{
	SEGGER_RTT_printf(0, "adc_read_sequence\n");
	adc_setup_sequence();
	adc_read_sequence();

	SEGGER_RTT_printf(0, "adc_read_single\n");
	adc_read_single(0);
	adc_read_single(1);
	adc_read_single(2);

#ifdef CONFIG_ARDUINO_API
	SEGGER_RTT_printf(0, "adc_read_arduino\n");
	adc_read_arduino(A0);
	adc_read_arduino(A1);
	adc_read_arduino(A2);
#endif
}
