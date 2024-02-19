#include <adc.h>
#include <hal/nrf_saadc.h>
#include <Arduino.h>


////////////////////////////////////////
#define ADC_DEVICE_NAME			"adc@e000"			//DT_ADC_0_NAME
#define ADC_1ST_CHANNEL_ID		1
#define ADC_2ND_CHANNEL_ID		2

////////////////////////////////////////
static int16_t sample;

////////////////////////////////////////
const device* adc_dev;

////////////////////////////////////////
static const struct adc_channel_cfg channel_1_cfg = {
	.gain				= ADC_GAIN_1_3,
	.reference			= ADC_REF_INTERNAL,
	.acquisition_time	= ADC_ACQ_TIME(ADC_ACQ_TIME_MICROSECONDS, 10),
	.channel_id			= ADC_1ST_CHANNEL_ID,
#if defined(CONFIG_ADC_CONFIGURABLE_INPUTS)
	.input_positive		= ADC_2ND_CHANNEL_ID,
#endif
};

////////////////////////////////////////
const struct adc_sequence sequence = 
{
	.channels		= BIT(ADC_1ST_CHANNEL_ID),
	.buffer			= &sample,
	.buffer_size	= sizeof(sample),
	.resolution		= 12,
};

////////////////////////////////////////////////////////////////////////////////
static int adc_sample(void)
{
	int ret = -1;
	if (adc_dev != nullptr) 
	{
		ret = adc_read(adc_dev, &sequence);

		if (ret == 0)
		{
			float adc_voltage = (3.3 * sample) / ((1<<sequence.resolution) - 1);
			printf("Measured voltage: %.02fV (0x%04X %d)\r\n", adc_voltage, sample, sample);
		}
	}
	return ret;
}

////////////////////////////////////////////////////////////////////////////////
int main(void)
{
	adc_dev = device_get_binding(ADC_DEVICE_NAME);
	if (adc_dev == nullptr) 
	{
		printk("device_get_binding ADC_0 failed\r\n");
	}
	printk("device_get_binding success %s\r\n", ADC_DEVICE_NAME);

	int err = adc_channel_setup(adc_dev, &channel_1_cfg);
	if (err != 0) 
	{
		printk("Error in adc setup: %d\r\n", err);
	}
	printk("adc_channel_setup success\r\n");

	/* Trigger offset calibration
	 * As this generates a _DONE and _RESULT event
	 * the first result will be incorrect.
	 */
//	NRF_SAADC_NS->TASKS_CALIBRATEOFFSET = 1;
	while (true) 
	{
		err = adc_sample();
		if (err != 0) 
		{
			printk("Error in adc sampling: %d\n", err);
		}
		delay(500);
		k_sleep(K_MSEC(500));
	}
}
