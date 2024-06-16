RED=\x1b[31;01m
GREEN=\x1b[32;01m
BOLD=\x1b[1m
NORMAL=\x1b[0m
HIGHLIGHT=\e[30;48;5;41m

#-------------------------------------------------------------------------------
#
# We use arduino-cli.exe for building these samples. Let's check
# if it is present on our system
#
ifeq (1, $(shell if [ -e $(CURDIR)/../arduino-cli.exe ]; then echo 1; fi))
  ARDUINO_CLI_PATH := ../arduino-cli.exe
else
  ifeq (, $(shell which arduino-cli.exe 2> /dev/null))
    $(info [ERROR] arduino-cli.exe is missing)
    $(info . . . . It must be either in system path or the directory above this)
    $(error  )
  else
    ARDUINO_CLI_PATH := arduino-cli.exe
  endif
endif




ifndef ZEPHYR_BASE
  $(info [ERROR] ZEPHYR_BASE is not set. Did you run env.sh? )
  $(error  )
endif

.SILENT:
.PHONY: build

all: build

build:
	cd ${CURDIR}/../.. && ./setup.sh
	echo -e "$(GREEN)Building Everything for nrf9160dk_nrf9160_ns$(NORMAL)"
	west build -b nrf9160dk_nrf9160_ns

k:
	west build -t guiconfig

prog:
	nrfjprog --program build/zephyr/merged.hex --chiperase --verify --pinreset

clean:
	rm -rf build

#####################################3
# Arduino build and flash
a:
	echo -e "$(GREEN)Building Everything by arduino_cli$(NORMAL)"
	$(ARDUINO_CLI_PATH) compile \
		--output-dir arduino_build \
		--fqbn bosl:nrf9160:nrf9160dk \
		src
prog_a:
	nrfjprog \
		--program arduino_build/src.ino.hex \
		--chiperase \
		--verify \
		--pinreset

