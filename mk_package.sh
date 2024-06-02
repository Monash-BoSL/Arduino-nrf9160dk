#!/bin/bash

RED='\x1b[31;01m'
GREEN='\x1b[32;01m'
YELLOW='\x1b[33;01m'
BOLD='\x1b[1m'
NORMAL='\x1b[0m'
HIGHLIGHT='\e[30;48;5;41m'


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#
# This script prepares necessary files for the BoSL Arduino Package using 
# nFR9160dk board and Nordic 'nRF Connect SDK' which includes Zephyr. The 
# package relies on a pre-built sample project (zephyr_samples/at_client) 
# We collect necessary include files and built libraries, we package them, 
# so that Arduino can link them together into a working executable.
#
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
#
# Command line parameters
#
REBUILD=0
SKIP_SDK=0
while [[ $# -gt 0 ]]; do
	case $1 in
		-r|--rebuild)
			REBUILD=1
			shift # past argument
		;;
		-q|--quick)
			SKIP_SDK=1
			shift # past argument
		;;
		-h|--help)
			echo Usage: $(basename $0) [options]
			echo -e '       '-r, --rebuild\\t\\t rebuild the package
			echo -e '       '-q, --quick\\t\\t skip copying SDK
			exit
		;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
		;;
	esac
done
if [ ${REBUILD} -ne 0 ]; then
	SKIP_SDK=0
fi


echo -e ${GREEN}
echo Building BoSL Arduino Package
echo -e ${NORMAL}


#-------------------------------------------------------------------------------
#
# Setup paths
#
MY_DIR=$(realpath $(dirname $0))

DEBUG_SKIP_TOOLS_INSTALL=1				# Debug only. Comment out for deployment

SAMPLE_DIR=${MY_DIR}/zephyr_samples/at_client/build
NRFJPROG_SRC_DIR="/c/Program Files/Nordic Semiconductor/nrf-command-line-tools"
ZEPHYR_BASE="${ZEPHYR_BASE//\\//}"

HARDWARE_DST_DIR=${MY_DIR}/bosl/hardware/nrf9160/${BOSL_VERSION}
ZEPHYR_TOOLKIT_DST_DIR=${MY_DIR}/bosl/tools/arm-zephyr-eabi/12.2.0
NRFJPROG_DST_DIR=${MY_DIR}/bosl/tools/nrfjprog/10.22.1
GEN_ISR_TABLES_DST_DIR=${MY_DIR}/bosl/tools/gen_isr_tables/0.0.0
MERGEHEX_DST_DIR=${MY_DIR}/bosl/tools/mergehex/0.0.0
GDB_DST_DIR=${MY_DIR}/bosl/tools/arm-none-eabi-gdb/13.2.90


# NOTE: NRFJPROG_SRC_DIR points to a directory residing outside of this project. 
#		Nordic Semiconductor command-line-tools must be installed and their 
#		locations adjusted above accordingly. Please do not commit changes to 
#		repository.

if [ ! -d "${NRFJPROG_SRC_DIR}" ]; then
	echo -e ${RED}
	echo  ERROR: Nordic Programming Tool directory cannot be found.
	echo '       'Please edit this script and point NRFJPROG_SRC_DIR
	echo '       'to the correct location.
	echo -e ${NORMAL}
	exit 1
fi
if [ ! -d "${SAMPLE_DIR}/zephyr/include/generated" ]; then
	echo -e ${RED}
	echo  ERROR: Sample project \(zephyr_samples/at_client\) appears not to have been built. 
	echo '       'Please build at_sample project and try again.
	echo -e ${NORMAL}
	exit 1
fi
if [ ! -d "${ZEPHYR_BASE}" ]; then
	echo -e ${RED}
	echo ERROR: Zephyr project directory cannot be found.
	if [ -z ${ZEPHYR_BASE+x} ]; then 
		echo '       'Variable ZEPHYR_BASE is not defined.
		echo '       'Please run \'source ./env.sh\'.
	else
		echo '       'Variable ZEPHYR_BASE points to a non existent directory.
		echo '       'Check your Nordic SDK installation.
	fi
	echo -e ${NORMAL}
	exit 1
fi
if [ ! -d "${ZEPHYR_SDK_INSTALL_DIR}" ]; then
	echo -e ${RED}
	echo ERROR: Zephyr SDK toolkit directory cannot be found.
	if [ -z ${ZEPHYR_SDK_INSTALL_DIR+x} ]; then 
		echo '       'Variable ZEPHYR_SDK_INSTALL_DIR is not defined.
		echo '       'Please run this script from a "nRF Connect SDK" bash terminal.
	else
		echo '       'Variable ZEPHYR_SDK_INSTALL_DIR points to a non existent directory.
		echo '       'This is serious. Complain to Dejan.
	fi
	echo -e ${NORMAL}
	exit 1
else
	ZEPHYR_TOOLKIT_SRC_DIR=${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi
fi
if [ ! -d "${ZEPHYR_TOOLKIT_SRC_DIR}" ]; then
	echo -e ${RED}
	echo   ERROR: Zephyr toolkit directory \(${ZEPHYR_TOOLKIT_SRC_DIR}\) cannot be found.
	echo '       'Please run setup.sh and ensure it completes successfully.
	echo -e ${NORMAL}
	exit 1
fi
python -c "import PyInstaller" 2> /dev/null
if [ $? != 0 ]; then
	echo -e ${RED}
	echo   ERROR: Python module PyInstaller not found.
	echo '       'Please run \'pip install PyInstaller\'.
	echo -e ${NORMAL}
	exit 1
fi

if [ ${REBUILD} -ne 0 ]; then
	echo -e ${GREEN}Rebuilding...${NORMAL}
	rm -rf ${HARDWARE_DIR}/inc
	rm -rf ${HARDWARE_DIR}/lib
fi




#-------------------------------------------------------------------------------
#
# Statics
#
mkdir -p ${HARDWARE_DST_DIR}
cp --update 			templates/*.txt ${HARDWARE_DST_DIR}
cp --update --recursive templates/cores ${HARDWARE_DST_DIR}

#-------------------------------------------------------------------------------
#
# Copy tools
#
function copy_tool ()
{
	SRC_DIR=$1
	DST_DIR=$2

	echo Preparing $(basename "${SRC_DIR}")...
	if [ ! -d "${DST_DIR}" ]; then
		mkdir -p "${DST_DIR}"
	fi
	cp --recursive --update "${SRC_DIR}"/* ${DST_DIR}
} 

if [ ${SKIP_SDK} -eq 0 ]; then
	copy_tool "${ZEPHYR_TOOLKIT_SRC_DIR}"	"${ZEPHYR_TOOLKIT_DST_DIR}"
	copy_tool "${NRFJPROG_SRC_DIR}"			"${NRFJPROG_DST_DIR}"
else
	echo
	echo -e ${YELLOW}IMPORTANT: Skipping toolchains. Assuming they have already been prepared.${NORMAL}
	echo
fi

# We don't need the whole arm-zephyr-eabi
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/include
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/arm-zephyr-eabi/lib/thumb/nofp
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/arm-zephyr-eabi/lib/thumb/v6*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/arm-zephyr-eabi/lib/thumb/v7*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/arm-zephyr-eabi/lib/thumb/v8*.base
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-addr*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-as*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-c++*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-ct*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-elfedit*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-gcc-*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-gcov*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-gdb*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-gprof*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-ld.bfd*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-lto*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-nm*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-objdump*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-r*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/bin/arm-zephyr-eabi-st*
rm -rf "${ZEPHYR_TOOLKIT_DST_DIR}"/share
# We don't need the whole nrfjprog either
rm -rf "${NRFJPROG_DST_DIR}"/*_release_notes.txt
rm -rf "${NRFJPROG_DST_DIR}"/lib
rm -rf "${NRFJPROG_DST_DIR}"/include


#-------------------------------------------------------------------------------
#
# Build gen_isr_tables
#
if [ ! -d "${GEN_ISR_TABLES_DST_DIR}" ]; then
	mkdir -p "${GEN_ISR_TABLES_DST_DIR}"

	#---------------------------------------------------------------------------
	#
	# build gen_isr_tables.exe
	#
	# Zephyr applications link in an unusual way. First they compile and 
	# pre-link the application with a dummy isr_table.c. Then they use a 
	# python script to generate the final isr_tables.c from the pre-linked 
	# image. This new isr_tables.c has to be compiled, before the second 
	# link pass can be completed. Instead of distributing the whole python 
	# install, here we just build an exe that is needed for generating 
	# isr_tables.c
	#
	echo Freezing gen_isr_tables...
	python -m PyInstaller	\
		--log-level WARN	\
		--distpath py_dist	\
		--noconfirm			\
		--onefile ${ZEPHYR_BASE}/scripts/build/gen_isr_tables.py 
fi

if [ ! -d "${MERGEHEX_DST_DIR}" ]; then
	mkdir -p "${MERGEHEX_DST_DIR}"

	echo Freezing mergehex...
	python -m PyInstaller	\
		--log-level WARN	\
		--distpath py_dist	\
		--noconfirm			\
		--onefile ${ZEPHYR_BASE}/scripts/build/mergehex.py 

	cp py_dist/gen_isr_tables.exe ${GEN_ISR_TABLES_DST_DIR}/
	cp py_dist/mergehex.exe		  ${MERGEHEX_DST_DIR}/
	rm -rf build py_dist *.spec
fi


#-------------------------------------------------------------------------------
#
# Collect includes
#
echo Collecting headers...
python proc_compiler_cmd.py


#-------------------------------------------------------------------------------
#
# Archive all libraries to be used for linking
#
echo Collecting libraries...
cd ${SAMPLE_DIR}
ARCHIVE_PATH=zephyr/libbosl.a
if [ ! -f ${ARCHIVE_PATH} ]; then
	${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi/bin/arm-zephyr-eabi-ar.exe \
		qc ${ARCHIVE_PATH} \
			zephyr/CMakeFiles/zephyr_final.dir/misc/empty_file.c.obj \
			zephyr/CMakeFiles/offsets.dir/./arch/arm/core/offsets/offsets.c.obj \
			tfm/secure_fw/s_veneers.o \
			zephyr/libzephyr.a \
			zephyr/arch/common/libarch__common.a \
			zephyr/arch/arch/arm/core/aarch32/libarch__arm__core__aarch32.a \
			zephyr/arch/arch/arm/core/aarch32/cortex_m/libarch__arm__core__aarch32__cortex_m.a \
			zephyr/arch/arch/arm/core/aarch32/cortex_m/cmse/libarch__arm__core__aarch32__cortex_m__cmse.a \
			zephyr/arch/arch/arm/core/aarch32/mpu/libarch__arm__core__aarch32__mpu.a \
			zephyr/lib/libc/picolibc/liblib__libc__picolibc.a \
			zephyr/lib/libc/common/liblib__libc__common.a \
			zephyr/soc/soc/arm/common/cortex_m/libsoc__arm__common__cortex_m.a \
			zephyr/boards/arm/nrf9160dk_nrf9160/libboards__arm__nrf9160dk_nrf9160.a \
			zephyr/subsys/random/libsubsys__random.a \
			zephyr/subsys/net/libsubsys__net.a \
			zephyr/subsys/net/l2/offloaded_netdev/libsubsys__net__l2__offloaded_netdev.a \
			zephyr/subsys/net/ip/libsubsys__net__ip.a \
			zephyr/drivers/adc/libdrivers__adc.a \
			zephyr/drivers/clock_control/libdrivers__clock_control.a \
			zephyr/drivers/console/libdrivers__console.a \
			zephyr/drivers/entropy/libdrivers__entropy.a \
			zephyr/drivers/gpio/libdrivers__gpio.a \
			zephyr/drivers/i2c/libdrivers__i2c.a \
			zephyr/drivers/pinctrl/libdrivers__pinctrl.a \
			zephyr/drivers/serial/libdrivers__serial.a \
			zephyr/drivers/timer/libdrivers__timer.a \
			modules/nrf/lib/nrf_modem_lib/lib..__nrf__lib__nrf_modem_lib.a \
			modules/nrf/lib/at_monitor/lib..__nrf__lib__at_monitor.a \
			modules/nrf/lib/at_host/lib..__nrf__lib__at_host.a \
			modules/nrf/lib/fatal_error/lib..__nrf__lib__fatal_error.a \
			modules/nrf/lib/modem_antenna/lib..__nrf__lib__modem_antenna.a \
			modules/nrf/modules/tfm/zephyr/libtfm_api_nrf.a \
			modules/trusted-firmware-m/libtfm_api.a \
			modules/hal_nordic/nrfx/libmodules__hal_nordic__nrfx.a \
			C:/ncs/v2.5.0/nrfxlib/nrf_modem/lib/nRF9160/soft-float/libmodem.a \
			zephyr/kernel/libkernel.a \
			zephyr/arch/common/libisr_tables.a 
	cd - > /dev/null
fi


#-------------------------------------------------------------------------------
#
# Collect libraries
#
DST_DIR=${HARDWARE_DST_DIR}/lib
if [ ! -d ${DST_DIR} ]; then
	mkdir -p ${DST_DIR}
fi

cp --update ${SAMPLE_DIR}/zephyr/linker.cmd				${DST_DIR}
cp --update ${SAMPLE_DIR}/zephyr/linker_zephyr_pre0.cmd	${DST_DIR}/linker_pre0.cmd
cp --update ${SAMPLE_DIR}/tfm/bin/tfm_s.hex				${DST_DIR}
cp --update ${SAMPLE_DIR}/zephyr/tfm_secure.hex			${DST_DIR}

cp --update ${SAMPLE_DIR}/${ARCHIVE_PATH}				${DST_DIR}

if [ ! -f ${DST_DIR}/libkernel.a ]; then
	cd ${DST_DIR}
	${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi/bin/arm-zephyr-eabi-ar.exe \
		x libbosl.a
	rm libbosl.a
	cd - > /dev/null
fi


#-------------------------------------------------------------------------------
#
# Debugger
#
GDB_NAME=arm-none-eabi-gdb.exe

cp --update ${MY_DIR}/templates/debug_custom.json ${HARDWARE_DST_DIR}/
cp --update ${MY_DIR}/templates/nrf9160.svd		  ${HARDWARE_DST_DIR}/

if [ ! -f ${MY_DIR}/${GDB_NAME} ]; then
	echo -e ${YELLOW}
	echo   WARNING: Debugger \(${GDB_NAME}\) cannot be found 
	echo '        ' in ${MY_DIR}.
	echo 
	echo '        ' Without it, debugging in Arduino IDE will not be possible.
	echo -e ${NORMAL}

	read -p "Do you want to download it now (69M)? [Y/n] " response

	DOWNLOAD=1
	case $response in 
		[yY] ) DOWNLOAD=1;;
		[nN] ) DOWNLOAD=0;
			echo -e ${YELLOW}
			echo '        ' Skipping download.
			echo '        ' The debugger can be downloaded from:
			echo '            ' \"https://developer.arm.com/Tools and Software/GNU Toolchain\"
			echo -e ${NORMAL};;
	esac
	if [ ${DOWNLOAD} != 0 ]; then
		wget --quiet --show-progress https://github.com/ddeletic/arduino_bosl_nrf9160dk_downloads/raw/main/arm-none-eabi-gdb_v13.2.90.tar.gz
		tar xzf arm-none-eabi-gdb_v13.2.90.tar.gz --strip-components 1
	fi
fi
if [ -f ${MY_DIR}/${GDB_NAME} ]; then
	# Add debugger 
	mkdir -p ${GDB_DST_DIR}
	cp --update ${MY_DIR}/${GDB_NAME} ${GDB_DST_DIR}/${GDB_NAME} 
fi
