.PHONY: all
.PHONY: run
.PHONY: clean
.PHONY: setup
.PHONY: debug

LD  = x86_64-elf-ld
AS  = x86_64-elf-as
CC  = x86_64-elf-gcc
CXX = x86_64-elf-g++
LIM = limine

CXX_SOURCES := $(shell find Kernel -type f -name "*.cpp")
ASM_SOURCES := $(shell find Kernel -type f -name "*.S")
HPP_SOURCES := $(shell find Kernel -type f -name "*.hpp")
LIMINE_DATA ?= $(shell $(LIM) --print-datadir)
CXX_OBJECTS := $(CXX_SOURCES:.cpp=.o)
ASM_OBJECTS := $(ASM_SOURCES:.S=.o)
TARGET      := build/calantha
IMAGE       := build/calantha.iso
ARCH        := x86_64

all: setup $(TARGET) $(IMAGE)

$(TARGET): $(CXX_OBJECTS) $(ASM_OBJECTS)
	$(CXX) \
		-T linker.ld \
		-o $(TARGET) \
		-ffreestanding \
		-O2 \
		-nostdlib \
		$(addprefix build/, $(notdir $(CXX_OBJECTS))) \
		$(addprefix build/, $(notdir $(ASM_OBJECTS))) \
		-lgcc

%.o: %.cpp
	$(CXX) \
		-std=c++20 \
		-I. -include Kernel/Misc/Global.hpp \
		-ffreestanding -O2 -Wall -Wextra -Werror \
		-fno-pie \
		-fno-strict-aliasing \
		-fno-exceptions \
		-fno-rtti \
		-fno-stack-protector \
		-fno-stack-check \
		-fno-PIC \
		-ffunction-sections \
		-fdata-sections \
		-m64 \
		-march=x86-64 \
		-mno-80387 \
		-mno-mmx \
		-mno-sse \
		-mno-sse2 \
		-mno-red-zone \
		-mcmodel=kernel \
		-c $< \
		-o build/$(notdir $@)

%.o: %.S
	$(AS) $< -o build/$(notdir $@)

clean:
	rm -rf ./build

run: $(IMAGE)
	qemu-system-x86_64 \
		-m 2G \
		-M q35 \
		-boot d \
		-cdrom $(IMAGE)	\

$(IMAGE): $(TARGET)
	cp -v $(TARGET) build/iso_root/boot/
	cp -v limine.conf \
		$(LIMINE_DATA)/limine-bios.sys \
		$(LIMINE_DATA)/limine-bios-cd.bin \
		$(LIMINE_DATA)/limine-uefi-cd.bin \
		build/iso_root/boot/limine/

	cp -v $(LIMINE_DATA)/BOOTX64.EFI build/iso_root/EFI/BOOT/
	cp -v $(LIMINE_DATA)/BOOTIA32.EFI build/iso_root/EFI/BOOT/

	xorriso -as mkisofs -R -r -J \
		-b boot/limine/limine-bios-cd.bin \
		-no-emul-boot \
 		-boot-load-size 4 \
 		-boot-info-table \
 		-hfsplus \
		-apm-block-size 2048 \
		--efi-boot \
		boot/limine/limine-uefi-cd.bin \
		-efi-boot-part \
		--efi-boot-image \
		--protective-msdos-label \
		build/iso_root -o $(IMAGE)

	$(LIM) bios-install $(IMAGE)

setup:
	mkdir -p build/iso_root/boot/limine
	mkdir -p build/iso_root/EFI/BOOT

	# Generate a dummy CMakeLists build script.
	# This is just so that code completion/clangd can function correctly for
	# editors like Clion. we don't actually use Cmake for the build process.
	echo 'cmake_minimum_required(VERSION 3.28)' > CMakeLists.txt
	echo 'project(calantha)' >> CMakeLists.txt
	echo 'set(CMAKE_CXX_STANDARD 20)' >> CMakeLists.txt
	echo 'set(CMAKE_CXX_STANDARD_REQUIRED ON)' >> CMakeLists.txt

	echo 'add_executable(DUMMY ' >> CMakeLists.txt
	echo $(CXX_SOURCES) >> CMakeLists.txt
	echo $(HPP_SOURCES) >> CMakeLists.txt
	echo $(ASM_SOURCES) >> CMakeLists.txt
	echo ')' >> CMakeLists.txt

	echo 'target_include_directories(DUMMY PRIVATE $${CMAKE_CURRENT_SOURCE_DIR})' >> CMakeLists.txt
	echo 'target_compile_options(DUMMY PRIVATE -include Kernel/Misc/Global.hpp)' >> CMakeLists.txt

