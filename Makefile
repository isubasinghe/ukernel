#####
## BUILD
#####
SPIKE=spike
CC=riscv64-unknown-linux-gnu-gcc
CFLAGS=-Wall -Wextra -pedantic -Wextra -O0 -g -std=c11
CFLAGS+=-static -ffreestanding -nostdlib -fno-exceptions
CFLAGS+=-march=rv64gc -mabi=lp64
INCLUDES=
LINKER_SCRIPT=-Tsrc/lds/virt.ld
TYPE=debug
RUST_TARGET=./target/riscv64_soft_float/$(TYPE)
LIBS=-L$(RUST_TARGET)
SOURCES_ASM=$(wildcard src/asm/*.S)
SOURCES_C=$(wildcard src/**/*.c)
LIB=-lukernel -lgcc
OUT=os.elf

#####
## QEMU
#####
QEMU=qemu-system-riscv64
MACH=virt
CPU=rv64
CPUS=4
MEM=128M
DRIVE=hdd.dsk

all:
	cargo build
	$(CC) $(CFLAGS) $(LINKER_SCRIPT) $(INCLUDES) -o $(OUT) $(SOURCES_ASM) $(SOURCES_C) $(LIBS) $(LIB)
	
run: all
	$(QEMU) -machine $(MACH) -cpu $(CPU) -smp $(CPUS) -m $(MEM)  -nographic -serial mon:stdio -bios none -kernel $(OUT) -drive if=none,format=raw,file=$(DRIVE),id=foo -device virtio-blk-device,scsi=off,drive=foo

dumpdbt: 
	$(QEMU) -machine $(MACH) -machine dumpdtb=riscv64-$(MACH).dtb

spike: all dumpdbt
	$(SPIKE) --dtb riscv64-$(MACH).dtb -d $(OUT)

.PHONY: clean
clean:
	cargo clean
	rm -f $(OUT)
