#
# Copyright (c) 2018 Nordic Semiconductor
#
# SPDX-License-Identifier: LicenseRef-BSD-5-Clause-Nordic
#

cmake_minimum_required(VERSION 3.8.2)


cmake_path(SET ZephyrBase $ENV{ZEPHYR_BASE})
set(DTC_OVERLAY_FILE ${ZephyrBase}/../modules/lib/Arduino-Zephyr-API/variants/${BOARD}/${BOARD}.overlay)
set(ZEPHYR_EXTRA_MODULES ${ZephyrBase}/../modules/lib/Arduino-Zephyr-API)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})





#include($ENV{ZEPHYR_BASE}/cmake/app/boilerplate.cmake NO_POLICY_SCOPE)
project(adc_demo)

target_sources(app PRIVATE main.cpp)




zephyr_compile_options(-Wno-unused-variable -Wno-comment -IC:/ncs/v2.5.0/zephyr/include/zephyr/drivers)

