# Whether to merge SDK into Xtensa toolchain, producing standalone
# ESP8266 toolchain. Use 'n' if you want generic Xtensa toolchain
# which can be used with multiple SDK versions.
STANDALONE = n

# Directory to install toolchain to, by default inside current dir.
TOOLCHAIN = $(TOP)/xtensa-lx106-elf

VENDOR_SDK = 3.0.1

.PHONY: crosstool-NG toolchain libhal libcirom sdk

TOP = $(PWD)
SHELL = /bin/bash
PATCH = patch -b -N
UNZIP = unzip -q -o

VENDOR_SDK_ZIP = $(VENDOR_SDK_ZIP_$(VENDOR_SDK))
VENDOR_SDK_DIR = $(VENDOR_SDK_DIR_$(VENDOR_SDK))

VENDOR_SDK_ZIP_3.0.1 = ESP8266_NONOS_SDK-3.0.1.zip
VENDOR_SDK_DIR_3.0.1 = ESP8266_NONOS_SDK-3.0.1

all: esptool libcirom standalone sdk sdk_patch $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/libhal.a $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc lwip
	@echo
	@echo "Xtensa toolchain is built, to use it:"
	@echo
	@echo 'export PATH=$(TOOLCHAIN)/bin:$$PATH'
	@echo
ifneq ($(STANDALONE),y)
	@echo "Espressif ESP8266 SDK is installed. Toolchain contains only Open Source components"
	@echo "To link external proprietary libraries add:"
	@echo
	@echo "xtensa-lx106-elf-gcc -I$(TOP)/sdk/include -L$(TOP)/sdk/lib"
	@echo
else
	@echo "Espressif ESP8266 SDK is installed, its libraries and headers are merged with the toolchain"
	@echo
endif

standalone: sdk sdk_patch toolchain
ifeq ($(STANDALONE),y)
	@echo "Installing vendor SDK headers into toolchain sysroot"
	@cp -Rf sdk/include/* $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/include/
	@echo "Installing vendor SDK libs into toolchain sysroot"
	@cp -Rf sdk/lib/* $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/
	@echo "Installing vendor SDK linker scripts into toolchain sysroot"
	@sed -e 's/\r//' sdk/ld/eagle.app.v6.ld | sed -e s@../ld/@@ >$(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/eagle.app.v6.ld
	@sed -e 's/\r//' sdk/ld/eagle.rom.addr.v6.ld >$(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/eagle.rom.addr.v6.ld
endif

clean: clean-sdk
	$(MAKE) -C crosstool-NG clean MAKELEVEL=0
	-rm -f crosstool-NG/.built
	-rm -rf crosstool-NG/.build/src
	-rm -f crosstool-NG/local-patches/gcc/4.8.5/1000-*
	-rm -rf $(TOOLCHAIN)

clean-sdk:
	rm -rf $(VENDOR_SDK_DIR)
	rm -f sdk
	rm -f .sdk_patch_$(VENDOR_SDK)
	rm -f user_rf_cal_sector_set.o empty_user_rf_pre_init.o
	$(MAKE) -C esp-open-lwip -f Makefile.open clean

clean-sysroot:
	rm -rf $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/lib/*
	rm -rf $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/include/*


esptool: toolchain
	cp esptool/esptool.py $(TOOLCHAIN)/bin/

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



sdk: $(VENDOR_SDK_DIR)/.dir
	ln -snf $(VENDOR_SDK_DIR) sdk

$(VENDOR_SDK_DIR)/.dir: $(VENDOR_SDK_ZIP)
	$(UNZIP) $^
	-mv License $(VENDOR_SDK_DIR)
	touch $@

$(VENDOR_SDK_DIR_2.1.0-18-g61248df)/.dir:
	echo $(VENDOR_SDK_DIR_2.1.0-18-g61248df)
	git clone https://github.com/espressif/ESP8266_NONOS_SDK $(VENDOR_SDK_DIR_2.1.0-18-g61248df)
	(cd $(VENDOR_SDK_DIR_2.1.0-18-g61248df); git checkout 61248df5f6)
	touch $@

$(VENDOR_SDK_DIR_2.1.0)/.dir: $(VENDOR_SDK_ZIP_2.1.0)
	$(UNZIP) $^
	touch $@

sdk_patch: $(VENDOR_SDK_DIR)/.dir .sdk_patch_$(VENDOR_SDK)

.sdk_patch_2.1.0-18-g61248df .sdk_patch_2.1.0: user_rf_cal_sector_set.o
	echo -e "#undef ESP_SDK_VERSION\n#define ESP_SDK_VERSION 020100" >>$(VENDOR_SDK_DIR)/include/esp_sdk_ver.h
	$(PATCH) -d $(VENDOR_SDK_DIR) -p1 < c_types-c99_sdk_2.patch
	cd $(VENDOR_SDK_DIR)/lib; mkdir -p tmp; cd tmp; $(TOOLCHAIN)/bin/xtensa-lx106-elf-ar x ../libcrypto.a; cd ..; $(TOOLCHAIN)/bin/xtensa-lx106-elf-ar rs libwpa.a tmp/*.o
	$(TOOLCHAIN)/bin/xtensa-lx106-elf-ar r $(VENDOR_SDK_DIR)/lib/libmain.a user_rf_cal_sector_set.o
	@touch $@

empty_user_rf_pre_init.o: empty_user_rf_pre_init.c $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc $(VENDOR_SDK_DIR)/.dir
	$(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc -O2 -I$(VENDOR_SDK_DIR)/include -c $<

user_rf_cal_sector_set.o: user_rf_cal_sector_set.c $(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc $(VENDOR_SDK_DIR)/.dir
	$(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc -O2 -I$(VENDOR_SDK_DIR)/include -c $<

lwip: toolchain sdk_patch
ifeq ($(STANDALONE),y)
	$(MAKE) -C esp-open-lwip -f Makefile.open install \
	    CC=$(TOOLCHAIN)/bin/xtensa-lx106-elf-gcc \
	    AR=$(TOOLCHAIN)/bin/xtensa-lx106-elf-ar \
	    PREFIX=$(TOOLCHAIN)
	cp -a esp-open-lwip/include/arch esp-open-lwip/include/lwip esp-open-lwip/include/netif \
	    esp-open-lwip/include/lwipopts.h \
	    $(TOOLCHAIN)/xtensa-lx106-elf/sysroot/usr/include/
endif

ESP8266_NONOS_SDK-3.0.1.zip:
	wget --content-disposition "https://github.com/espressif/ESP8266_NONOS_SDK/archive/v3.0.1.zip"

FRM_ERR_PATCH.rar:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=10"
esp_iot_sdk_v0.9.3_14_11_21_patch1.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=73"
sdk095_patch1.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=190"
libssl.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=316"
libnet80211.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=361"
lib_patch_on_sdk_v1.1.0.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=432"
scan_issue_test.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=525"
libssl_patch_1.2.0-1.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=583" -O $@
libssl_patch_1.2.0-2.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=586" -O $@
libsmartconfig_2.4.2.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=585"
lib_mem_optimize_150714.zip:
	wget --content-disposition "http://bbs.espressif.com/download/file.php?id=594"
