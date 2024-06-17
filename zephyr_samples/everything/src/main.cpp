#include <zephyr/kernel.h>
#include "analog.h"
#include "digital.h"
#include "rtt.h"
#include "serial.h"


////////////////////////////////////////
#define SLEEP_TIME_MS		(1000)

////////////////////////////////////////////////////////////////////////////////
// To strictly comply with UART timing, enable external XTAL oscillator
void enable_xtal(void)
{
	struct onoff_manager* clk_mgr = z_nrf_clock_control_get_onoff(CLOCK_CONTROL_NRF_SUBSYS_HF);

	static struct onoff_client cli = {};
	sys_notify_init_spinwait(&cli.notify);
	(void)onoff_request(clk_mgr, &cli);
}

////////////////////////////////////////////////////////////////////////////////
void setup_modem (void)
{
	int result = nrf_modem_lib_init();
	if (result != 0) 
	{
		printk("Modem library initialization failed, error: %d\n", result);
		k_oops();
	}
	printk("The AT host started\n");

	// From this point on, any command received on the VCOM0 will be transferred 
	// to VCOM1 which is connected to the modem. Too test, type any of the 
	// supported AT commands. E.g. AT, AT%XOPERID, AT%XMONITOR, AT%XTEMP?, etc.
}

////////////////////////////////////////////////////////////////////////////////
void setup (void)
{
	enable_xtal();
	setup_rtt();
	analog_setup();
	setup_digital();
	setup_serial();
	setup_modem();

	serial_out("Setup complete. Type AT command to send to the modem...");
}

////////////////////////////////////////////////////////////////////////////////
void loop (void)
{
	k_msleep(SLEEP_TIME_MS);

	analog_read();
	blink();
	rtt_print("Another sunny day\n");
	serial_read();			// This will not result in any action unless zephyr_setup_serial() had been executed. 
}

////////////////////////////////////////////////////////////////////////////////
#ifndef CONFIG_ARDUINO_API
int main (void)
{
	setup();

	while( true)
	{
		loop();
	}
	return 0;
}
#endif

