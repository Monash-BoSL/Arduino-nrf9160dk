# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

cmake_path(SET ZephyrBase $ENV{ZEPHYR_BASE})


set(DTC_OVERLAY_FILE ${ZephyrBase}/../modules/lib/Arduino-Zephyr-API/variants/${BOARD}/${BOARD}.overlay)
set(ZEPHYR_EXTRA_MODULES ${ZephyrBase}/../modules/lib/Arduino-Zephyr-API)

find_package(Zephyr REQUIRED HINTS ${ZephyrBase})

project(Everything)

target_sources(app PRIVATE src/main.cpp)
target_sources(app PRIVATE src/digital.cpp)
target_sources(app PRIVATE src/analog.cpp)
target_sources(app PRIVATE src/rtt.cpp)
target_sources(app PRIVATE src/serial.cpp)

# SEGGER_RTT_printf.c is a copy of /c/ncs/v2.5.0/modules/debug/segger/SEGGER/SEGGER_RTT_printf.c
# Copying it into the project allows us to ignore CONFIG_RTT_CONSOLE Kconfig directive which
# directs all output to RTT. This way SEGGER_RTT_printf() output goes to RTT while printf() 
# goes to serial console. Serial.print() output incidentally goes to both RTT and the serial 
# console.
target_sources(app PRIVATE src/SEGGER_RTT_printf.c)
