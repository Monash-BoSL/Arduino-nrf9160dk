.SILENT:


.PHONY: pack dist

all: pack copy build_arduino

release: clean pack dist

test: qclean qpack qcopy build_arduino



setup:
	cd ${CURDIR} && ./setup.sh
pack: z
	cd ${CURDIR} && ./mk_package.sh
qpack: z
	cd ${CURDIR} && ./mk_package.sh -q

copy:
	cd ${CURDIR} &&./local_copy.sh
qcopy:
	cd ${CURDIR} &&./local_copy.sh -q
qclean: clean_samples clean_hardware

z: setup
	cd zephyr_samples/everything && $(MAKE) build
z_all: setup
	cd zephyr_samples && $(MAKE)

dist:
	cd ${CURDIR} && ./mk_dist.sh

clean_samples:
	cd zephyr_samples  && $(MAKE) clean
clean_package:
	rm -rf bosl
clean_hardware:
	rm -rf bosl/hardware
clean_local_install:
	rm -rf ${ARDUINO_PATH}/packages/bosl
clean: clean_samples clean_package clean_local_install

build_arduino: qpack qcopy 
	cd zephyr_samples/everything && $(MAKE) a
