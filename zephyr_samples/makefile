RED='\x1b[31;01m'
GREEN='\x1b[32;01m'
BOLD='\x1b[1m'
NORMAL='\x1b[0m'
HIGHLIGHT='\e[30;48;5;41m'

ifndef ZEPHYR_BASE
  $(info [ERROR] ZEPHYR_BASE is not set. Did you run env.sh? )
  $(error  )
endif

.SILENT:

all: e


e:
	cd everything && $(MAKE)

clean_e:
	cd everything && $(MAKE) clean

clean: clean_e
