.PHONY: crosstool-NG toolchain libhal libcirom

TOOLCHAIN = $(TOP)/xtensa-lx106-elf
TOP = $(PWD)
SHELL = /bin/bash
PATCH = patch -b -N
UNZIP = unzip -q -o

all: libcirom $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/libhal.a $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc lwip
	@echo
	@echo "Xtensa toolchain is built, to use it:"
	@echo 'export PATH=$(TOOLCHAIN)/bin:$$PATH'
	@echo

clean:
	$(MAKE) -C crosstool-NG clean MAKELEVEL=0
	-rm -f crosstool-NG/.built
	-rm -rf crosstool-NG/.build/src
	-rm -f crosstool-NG/local-patches/gcc/4.8.5/1000-*
	-rm -rf $(TOOLCHAIN)
	$(MAKE) -C esp-open-lwip -f Makefile.open clean

toolchain $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/lib/libc.a: crosstool-NG/.built

crosstool-NG/.built: crosstool-NG/ct-ng
	cp -f 1000-mforce-l32.patch crosstool-NG/local-patches/gcc/4.8.5/
	$(MAKE) -C crosstool-NG -f ../Makefile _toolchain
	touch $@

_toolchain:
	./ct-ng xtensa-lx106-elf
	sed -r -i.org s%CT_PREFIX_DIR=.*%CT_PREFIX_DIR="$(TOOLCHAIN)"% .config
	sed -r -i s%CT_INSTALL_DIR_RO=y%"#"CT_INSTALL_DIR_RO=y% .config
	cat ../crosstool-config-overrides >> .config
	./ct-ng build

crosstool-NG: crosstool-NG/ct-ng
	@echo "ok"

crosstool-NG/ct-ng: crosstool-NG/bootstrap
	$(MAKE) -C crosstool-NG -f ../Makefile _ct-ng

_ct-ng:
	./bootstrap
	./configure --prefix=`pwd`
	$(MAKE) MAKELEVEL=0
	$(MAKE) install MAKELEVEL=0

crosstool-NG/bootstrap:
	@echo "You cloned without --recursive, fetching submodules for you."
	git submodule update --init --recursive

libcirom: $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/lib/libcirom.a

$(TOOLCHAIN)/xtensa-lx106-elf/sysroot/lib/libcirom.a: $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/lib/libc.a $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc
	@echo "Creating irom version of libc..."
	$(TOOLCHAIN)/bin/xtensa-lx106-elf-objcopy --rename-section .text=.irom0.text \
		--rename-section .literal=.irom0.literal $(<) $(@);

libhal: $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/libhal.a

$(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/libhal.a: $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc
	$(MAKE) -C lx106-hal -f ../Makefile _libhal

_libhal:
	autoreconf -i
	PATH="$(TOOLCHAIN)/bin:$(PATH)" ./configure --host=xtensa-lx106-elf --prefix=$(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr
	PATH="$(TOOLCHAIN)/bin:$(PATH)" $(MAKE)
	PATH="$(TOOLCHAIN)/bin:$(PATH)" $(MAKE) install

lwip: toolchain

