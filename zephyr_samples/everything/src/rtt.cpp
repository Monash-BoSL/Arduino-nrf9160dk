#include <SEGGER_RTT.h>

////////////////////////////////////////////////////////////////////////////////
void setup_rtt (void)
{
	SEGGER_RTT_Init();
	SEGGER_RTT_printf(0, "Hello World\n");			// Example SEGGER_RTT_write() usage
}

////////////////////////////////////////////////////////////////////////////////
void rtt_print (const char* const msg)
{
	SEGGER_RTT_printf(0, msg);
}

