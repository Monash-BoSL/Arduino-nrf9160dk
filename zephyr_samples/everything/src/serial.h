#ifdef CONFIG_ARDUINO_API
	#include <Arduino.h>
#endif

#ifndef INCLUDE_SERIAL_H

////////////////////////////////////////
void setup_serial	(void);
void serial_out		(const char* const msg);
void serial_read	(void);

#endif      // INCLUDE_SERIAL_H
