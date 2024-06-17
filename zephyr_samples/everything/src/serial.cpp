#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/uart.h>
#include <string.h>
#include "serial.h"


////////////////////////////////////////
static void uart_irq_callback(const struct device* dev, void* user_data);
static void zephyr_serial_out(const char* const buf);
static void zephyr_setup_serial(void);


////////////////////////////////////////////////////////////////////////////////
static void arduino_setup_serial (uint32_t baud_rate)
{
#ifdef CONFIG_ARDUINO_API
	Serial.begin(baud_rate);
#endif
}

////////////////////////////////////////////////////////////////////////////////
static void arduino_serial_out (const char* const msg)
{
#ifdef CONFIG_ARDUINO_API
	Serial.println(msg);
#endif
}

////////////////////////////////////////////////////////////////////////////////
void setup_serial (void)
{
	arduino_setup_serial(115200);

#ifdef ENABLE_ZEPHYR_SERIAL
	// zephyr_setup_serial() initialises uart1 which is shared with the modem 
	// control. If we re-initialise uart1 here, then we take over comms with the
	// modem and user cannot issue AT commands any more. Therefore this feature
	// will be disabled unless needed for testing.
	zephyr_setup_serial();
#else
	(void)zephyr_setup_serial;
#endif
}

////////////////////////////////////////////////////////////////////////////////
void serial_out (const char* const msg)
{
	arduino_serial_out(msg);
}

////////////////////////////////////////
// change this to any other UART peripheral if desired 
#define UART_DEVICE_NODE DT_ALIAS(uart0)

static const struct device* const uart_dev = DEVICE_DT_GET(UART_DEVICE_NODE);


#define MSG_SIZE 32

// queue to store up to 10 messages (aligned to 4-byte boundary)
K_MSGQ_DEFINE(uart_msgq, MSG_SIZE, 10, 4);

// receive buffer used in UART ISR callback
static char rx_buf[MSG_SIZE];
static unsigned int rx_buf_pos;

////////////////////////////////////////////////////////////////////////////////
static void zephyr_setup_serial (void)
{
	if (device_is_ready(uart_dev) == false) 
	{
		printk("UART device not found!\n");
		k_oops();
	}

	// configure interrupt and callback to receive data 
	int result = uart_irq_callback_user_data_set(uart_dev, uart_irq_callback, NULL);
	if (result < 0) 
	{
		if (result == -ENOTSUP) 
		{
			printk("Interrupt-driven UART API support not enabled\n");
		} 
		else if (result == -ENOSYS) 
		{
			printk("UART device does not support interrupt-driven API\n");
		} 
		else 
		{
			printk("Error setting UART callback: %d\n", result);
		}
		k_oops();
	}

	uart_config uart_cfg = {
		.baudrate   = 115200,
		.parity     = UART_CFG_PARITY_NONE,
		.stop_bits  = UART_CFG_STOP_BITS_1,
		.data_bits  = UART_CFG_DATA_BITS_8,
		.flow_ctrl  = UART_CFG_FLOW_CTRL_NONE,
	};
	result = uart_configure(uart_dev, &uart_cfg);
	if (result < 0) 
	{
		printk("uart_configure failed (err=%d)\n", result);
		k_oops();
	}

	uart_irq_rx_enable(uart_dev);

	zephyr_serial_out("Hello! I'm your echo bot.\r\n");
	zephyr_serial_out("Tell me something and press enter:\r\n");
}

////////////////////////////////////////////////////////////////////////////////
// Print a null-terminated string character by character to the UART interface
void zephyr_serial_out (const char* const buf)
{
	int msg_len = strlen(buf);

	for (int i = 0; i < msg_len; i++) 
	{
		uart_poll_out(uart_dev, buf[i]);
	}
}

////////////////////////////////////////////////////////////////////////////////
void serial_read (void)
{
	char tx_buf[MSG_SIZE];

	if (k_msgq_get(&uart_msgq, &tx_buf, K_MSEC(0)) == 0)
	{
		zephyr_serial_out("Echo: ");
		zephyr_serial_out(tx_buf);
		zephyr_serial_out("\r\n");
	}
}

////////////////////////////////////////////////////////////////////////////////
//
// Read characters from UART until line end is detected. Afterwards push the
// data to the message queue.
//
void uart_irq_callback(const struct device* dev, void* user_data)
{
	if (uart_irq_update  (uart_dev) == false)		return;
	if (uart_irq_rx_ready(uart_dev) == false)	    return;

	// read until FIFO empty
	uint8_t c;
	while (uart_fifo_read(uart_dev, &c, 1) == 1) 
	{
		if ((c == '\n' || c == '\r') && rx_buf_pos > 0) 
		{
			rx_buf[rx_buf_pos] = '\0';			// terminate string

			// if queue is full, message is silently dropped
			k_msgq_put(&uart_msgq, &rx_buf, K_NO_WAIT);

			// reset the buffer (it was copied to the msgq)
			rx_buf_pos = 0;
		}
		else if (rx_buf_pos < (sizeof(rx_buf) - 1)) 
		{
			rx_buf[rx_buf_pos++] = c;
		}
		// else: characters beyond buffer size are dropped
	}
}

