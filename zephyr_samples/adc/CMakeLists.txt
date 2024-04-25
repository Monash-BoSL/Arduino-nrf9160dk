cmake_minimum_required(VERSION 3.8.2)


cmake_path(SET ZephyrBase $ENV{ZEPHYR_BASE})
set(DTC_OVERLAY_FILE ${ZephyrBase}/../modules/lib/Arduino-Zephyr-API/variants/${BOARD}/${BOARD}.overlay)
set(ZEPHYR_EXTRA_MODULES ${ZephyrBase}/../modules/lib/Arduino-Zephyr-API)
include_directories(${ZephyrBase}/include/zephyr/drivers)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})





project(adc_demo)

target_sources(app PRIVATE zephyr_adc_sample.cpp)




#zephyr_compile_options(-Wno-unused-variable -Wno-comment -IC:/ncs/v2.5.0/zephyr/include/zephyr/drivers)
zephyr_compile_options(-Wno-unused-variable -Wno-comment)

